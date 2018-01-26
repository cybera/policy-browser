#!/usr/bin/env python

import os, re, sys
import os.path
from neo4j.v1 import GraphDatabase
from contextlib import contextmanager
import json
import pysolr
from optparse import OptionParser
from util import sha256str

parser = OptionParser()
parser.add_option("-a", "--add", action="store_true", dest="add")
parser.add_option("-r", "--rows", action="store", dest="maxrows", default=10)
(options, args) = parser.parse_args(sys.argv)

search_query = args[1]

uri = "bolt://neo4j:7687"
driver = GraphDatabase.driver(uri, auth=("neo4j", "password"))
solr = pysolr.Solr('http://solr:8983/solr/cira', timeout=10)

@contextmanager
def transaction():
  with driver.session() as session:
    with session.begin_transaction() as tx:
      yield tx

search_config = {
  'hl.fl': 'content', 
  'hl': 'on', 
  'wt': 'json', 
  'hl.fragsize': 1000, 
  'hl.encoder': '', 
  'hl.tag.pre': '<em>', 
  'hl.tag.post': '</em>', 
  'hl.snippets': 200, 
  #'hl.method': 'unified', 
  'fq' : '-id:8b86f13c-3a01-45de-9668-b9ffdab7dee9 -id:152ef2a2-0cb4-4cdc-947d-c32fc0d09111',
  'fl':['id','sha256','name'],
  'rows':options.maxrows
}

search_results = solr.search(search_query, **search_config)

docs = {}

TEXT_BOLD = '\033[1m'
TEXT_NORMAL = '\033[0m'

for r in search_results.docs:
  solr_id = r['id']
  sha256 = r['sha256'][0]
  if sha256 not in docs:
    docs[sha256] = []
  print(f"\n\n================{sha256}================\n\n")
  if 'content' in search_results.highlighting[solr_id]:
    for hl in search_results.highlighting[solr_id]['content']:
      docs[sha256].append(hl)
      normalized = hl.replace("\n", "").replace("<em>", TEXT_BOLD).replace("</em>", TEXT_NORMAL)
      print(f"{normalized}\n\n")


if options.add:
  with transaction() as tx:
    for sha256 in docs:
      for hlhit in docs[sha256]:
        hit = re.sub(r'<em>(.*?)</em>','\\1', hlhit)
        hit256 = sha256str(hit)
        tx.run("""
          MATCH (d:Document { sha256: $sha256 })
          MERGE (s:Segment { sha256: $hit256 } )-[:SEGMENT_OF]->(d)
          WITH s
          MERGE (q:Query { str: $qstr })
          WITH q, s
          MERGE (s)-[:MATCHES]->(q)
          SET s.content = $content, s.hlcontent = $hlcontent
        """, sha256=sha256, qstr=search_query, content=hit, 
             hlcontent=hlhit, hit256=hit256)

dochits = len(search_results.docs)
print(f"Showing {dochits} of {search_results.hits} documents")
