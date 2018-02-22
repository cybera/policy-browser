#!/usr/bin/env python

import os, re, sys
import os.path
from neo4j.v1 import GraphDatabase
from contextlib import contextmanager
import json
import pysolr
from optparse import OptionParser

sys.path.append("scripts")

from wrangling.util import neo4jtx as neo4j
from wrangling.util import sha256str

parser = OptionParser()
parser.add_option("-a", "--add", action="store_true", dest="add")
parser.add_option("-r", "--rows", action="store", dest="maxrows", default=10)
(options, args) = parser.parse_args(sys.argv)

search_query = args[1]

solr = pysolr.Solr('http://solr:8983/solr/cira', timeout=10)

search_config = {
  'hl.fl': 'content', 
  'hl': 'on', 
  'wt': 'json', 
  'hl.fragsize': 500, 
  'hl.encoder': '', 
  'hl.tag.pre': '<em>', 
  'hl.tag.post': '</em>', 
  'hl.snippets': 200, 
  'hl.method': 'unified', 
  'fq' : 
  '-name:"2015-134.224035.2409354.Intervention(1fn2$01!).pdf" ' +
  '-name:"2015-134.224035.2409353.Intervention(1fn2h01!).pdf" ' +
  '-name:"2015-134.224035.2409355.Intervention(1fn2j01!).pdf" ' +
  '-name:"2015-134.224035.2398004.Intervention(1f#b801!).html" ' +
  '-name:"2015-134.223963.2394421.Intervention Submission 6401 to 9600(1fbjp01!).pdf" ' + 
  '-name:"2015-134.223963.2394419.Intervention Submission 1 to 3200 (1fbjn01!).pdf" ' +
  '-name:"2015-134.223963.2394424.Intervention Submission 16001 to 19200 (1fbjs01!).pdf" ' +
  '-name:"2015-134.223963.2394423.Intervention Submission 12801 to 16000(1fbjr01!).pdf" ' +
  '-name:"2015-134.223963.2394422.Intervention Submission 9601 to 12800(1fbjq01!).pdf" ' +
  '-name:"2015-134.223963.2394420.Intervention Submission 3201 to 6400(1fbj_01!).pdf" ' +
  '-name:"2015-134.223963.2394425.Intervention Submission 19201 to 22386(1fbjt01!).pdf"',
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
  with neo4j() as tx:
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
