#!/usr/bin/env python

from neo4j.v1 import GraphDatabase

uri = "bolt://neo4j:7687"
driver = GraphDatabase.driver(uri, auth=("neo4j", "password"))

def create(statement):
  with driver.session() as session:
    with session.begin_transaction() as tx:
      tx.run(statement)

import os
import re

scrapedir = os.path.join("data", "raw")

for fname in os.listdir(scrapedir):
  if fname != ".gitignore":
    print("Importing: %s" % fname)
    dtype=fname.rsplit('.', 1)[1]
    the_rest=fname.rsplit('.', 1)[0]
    [public_process_number,case,dmid,name] = the_rest.split('.', 3)
    create(
      """
      MERGE (p:PublicProcess { ppn: '%s' })
      MERGE (i:Intervention { case: %i })
      MERGE (d:Document { dmid: %i, type: '%s', name: '%s' })
      MERGE (i)-[:CONTAINS]->(d)
      MERGE (i)-[:SUBMITTED_TO]->(p)
      MERGE (d)-[:PART_OF]->(i)
      MERGE (p)-[:RECEIVES]->(i)
      """ % (public_process_number, int(case), int(dmid), dtype, fname)
    )
