#!/usr/bin/env python

import os, re
import os.path
from neo4j.v1 import GraphDatabase
from contextlib import contextmanager
import json
import pysolr

uri = "bolt://neo4j:7687"
driver = GraphDatabase.driver(uri, auth=("neo4j", "password"))
solr = pysolr.Solr('http://solr:8983/solr/cira', timeout=10)

@contextmanager
def transaction():
  with driver.session() as session:
    with session.begin_transaction() as tx:
      yield tx

with transaction() as tx:
  results = tx.run("""
    MATCH (doc:Document)
    RETURN doc.content as content, 
           doc.sha256 as sha256, 
           doc.name as name, 
           doc.type as type, 
           doc.case as case, 
           doc.ppn as ppn, 
           doc.dmid as dmid, 
           doc.submission_name as submission_name, 
           doc.container_filename as container_filename
  """)

  for r in results:
    print(f"Adding: {r['sha256']}")
    solr.add([r.data()])

