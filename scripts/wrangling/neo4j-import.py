#!/usr/bin/env python

from neo4j.v1 import GraphDatabase

uri = "bolt://neo4j:7687"
driver = GraphDatabase.driver(uri, auth=("neo4j", "password"))

from contextlib import contextmanager

@contextmanager
def transaction():
  with driver.session() as session:
    with session.begin_transaction() as tx:
      yield tx

def xml_top_level(doc, fieldname):
  element = doc.xpath("//div[contains(text(),'%s')]/*" % fieldname)
  text = element.xpath("text()").extract_first()
  if text:
    return text.strip()
  else:
    return None

def xml_client_info(doc, fieldname):
    element = doc.xpath("//div[contains(text(),'Client information')]/following::div[contains(text(),'%s')][1]/*" % fieldname)
    text = element.xpath("text()").extract_first()
    if text:
      return text.strip()
    else:
      return None

def xml_designated_representative(doc, fieldname):
    element = doc.xpath("//div[contains(text(),'Designated representative')]/following::div[contains(text(),'%s')][1]/*" % fieldname)
    text = element.xpath("text()").extract_first()
    if text:
      return text.strip()
    else:
      return None

import os
import re
from scrapy.selector import Selector

scrapedir = os.path.join("data", "raw")
txtdir = os.path.join("data", "processed", "raw_text")

with driver.session() as session:
  with session.begin_transaction() as tx:
    for fname in os.listdir(scrapedir):
      if fname != ".gitignore":
        print("Importing: %s" % fname)
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
    for record in tx.run("""
      MATCH (d:Document) WHERE NOT EXISTS(d.raw_text) RETURN d.name AS name
      """):
      filepath = os.path.join(scrapedir, record['name'])
      txtpath = os.path.join(txtdir, "%s.txt" % record['name'])
      if os.path.exists(txtpath):
        print("Importing raw text: " + txtpath)
        file = open(txtpath, "r", encoding="latin-1")
        raw_text = file.read()
        tx.run("MATCH (d:Document { name: $fname }) SET d.raw_text = $raw_text", fname=record['name'], raw_text=raw_text)

def merge_people():
  with transaction() as tx:
    results = tx.run("""
      MATCH (i:Intervention)-[:CONTAINS]->(d:Document {type:'html'})
      WHERE NOT (:Person)-[:SUBMITTED]->(i:Intervention) 
      RETURN i.case AS case, d.raw_text AS raw_text
      """)
    for r in results:
      doc = Selector(text=r["raw_text"])
      person_name = xml_client_info(doc, "Name")
      if person_name:
        tx.run("""
          MATCH (i:Intervention { case: {case}})
          MERGE (p:Person { name: {name} })
          MERGE (p)-[:SUBMITTED]->(i)
          """, name=person_name, case=r["case"] )

def merge_organizations():
  with transaction() as tx:
    results = tx.run("""
      MATCH (person:Person)-[:SUBMITTED]->(i:Intervention)-[:CONTAINS]->(doc:Document {type:'html'})
      WHERE NOT (person)-[:WORKING_FOR]->(:Organization)
      RETURN i.case AS case, doc.raw_text, person.name
      """)
    for r in results:
      doc = Selector(text=r["doc.raw_text"])
      person_name = xml_client_info(doc, "Name")
      org_name = xml_client_info(doc, "On behalf of company")
      person_title = xml_client_info(doc, "Title")
      if person_name == r["person.name"] and org_name:
        tx.run("""
          MATCH (p:Person { name: {name} })
          MERGE (o:Organization { name: {organization_name} })
          MERGE (p)-[r1:WORKING_FOR]->(o)
          ON CREATE SET r1.title = {title}
          MERGE (o)-[r2:EMPLOYS]->(p)
          ON CREATE SET r2.title = {title}
        """, organization_name=org_name, name=person_name, title=person_title)

merge_people()
merge_organizations()