#!/usr/bin/env python

from neo4j.v1 import GraphDatabase
from html_submission import HTMLSubmission

uri = "bolt://neo4j:7687"
driver = GraphDatabase.driver(uri, auth=("neo4j", "password"))

from contextlib import contextmanager

@contextmanager
def transaction():
  with driver.session() as session:
    with session.begin_transaction() as tx:
      yield tx

import os
import re

scrapedir = os.path.join("data", "raw")
txtdir = os.path.join("data", "processed", "raw_text")

def merge_core():
  print("Using filenames to merge PublicProcess, Intervention, and Document nodes")
  with transaction() as tx:
    for fname in os.listdir(scrapedir):
      if fname != ".gitignore" and fname != ".DS_Store":
        dtype=fname.rsplit('.', 1)[1]
        the_rest=fname.rsplit('.', 1)[0]
        [public_process_number,case,dmid,name] = the_rest.split('.', 3)
        tx.run("""
          MERGE (p:PublicProcess { ppn: $ppn })
          MERGE (i:Intervention { case: $case })
          MERGE (d:Document { dmid: $dmid, type: $dtype, name: $fname })
          MERGE (i)-[:CONTAINS]->(d)
          MERGE (i)-[:SUBMITTED_TO]->(p)
          MERGE (d)-[:PART_OF]->(i)
          MERGE (p)-[:RECEIVES]->(i)
        """, ppn=public_process_number, case=int(case), dmid=int(dmid), dtype=dtype, fname=fname)

def merge_raw_text():
  print("Parsing text and merging as raw_text on Documents")
  with transaction() as tx:
    for r in tx.run("""
      MATCH (d:Document) WHERE NOT EXISTS(d.raw_text) RETURN d.name AS name
      """):
      filepath = os.path.join(scrapedir, r['name'])
      txtpath = os.path.join(txtdir, "%s.txt" % r['name'])
      if os.path.exists(txtpath):
        raw_text = open(txtpath, "r", encoding="latin-1").read()
        tx.run("""
          MATCH (doc:Document { name: $fname })
          SET doc.raw_text = $raw_text
        """, fname=r['name'], raw_text=raw_text)  

def merge_people():
  print("Finding People from HTML document submissions related to an Intervention")
  with transaction() as tx:
    results = tx.run("""
      MATCH (i:Intervention)-[:CONTAINS]->(d:Document {type:'html'})
      WHERE NOT (:Person)-[:SUBMITTED]->(i:Intervention) 
      RETURN i.case AS case, d.raw_text AS raw_text
    """)
    for r in results:
      doc = HTMLSubmission(r["raw_text"])
      person_name = doc.client_info("Name")
      if person_name:
        tx.run("""
          MATCH (i:Intervention { case: $case})
          MERGE (p:Person { name: $name })
          MERGE (p)-[:SUBMITTED]->(i)
        """, name=person_name, case=r["case"] )

def merge_organizations():
  print("Finding Organizations from HTML document submissions related to an Intervention")
  with transaction() as tx:
    results = tx.run("""
      MATCH (person:Person)-[:SUBMITTED]->(i:Intervention)-[:CONTAINS]->(doc:Document {type:'html'})
      WHERE NOT (person)-[:WORKING_FOR]->(:Organization)
      RETURN i.case AS case, doc.raw_text, person.name
    """)
    for r in results:
      doc = HTMLSubmission(r["doc.raw_text"])
      person_name = doc.client_info("Name")
      org_name = doc.client_info("On behalf of company")
      person_title = doc.client_info("Title")
      if person_name == r["person.name"] and org_name:
        tx.run("""
          MATCH (p:Person { name: $name })
          MERGE (o:Organization { name: $org_name })
          MERGE (p)-[r1:WORKING_FOR]->(o)
          ON CREATE SET r1.title = $title
          MERGE (o)-[r2:EMPLOYS]->(p)
          ON CREATE SET r2.title = $title
        """, org_name=org_name, name=person_name, title=person_title)

merge_core()
merge_raw_text()
merge_people()
merge_organizations()