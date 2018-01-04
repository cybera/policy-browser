#!/usr/bin/env python

import os, re
import os.path
from neo4j.v1 import GraphDatabase
from html_submission import HTMLSubmission
from contextlib import contextmanager
import csv
from glob import glob
import json

uri = "bolt://neo4j:7687"
driver = GraphDatabase.driver(uri, auth=("neo4j", "password"))

@contextmanager
def transaction():
  with driver.session() as session:
    with session.begin_transaction() as tx:
      yield tx

metadir = os.path.join("data", "processed", "meta")
txtdir = os.path.join("data", "processed", "raw_text")
csvdir = os.path.join("data", "processed")
hasheddir = os.path.join("data", "processed", "hashed")

def merge_core():
  print("Using filenames to merge PublicProcess, Intervention, and Document nodes")
  with transaction() as tx:
    for fpath in glob(f"{metadir}/*"):
      meta = json.load(open(fpath))
      sha256 = os.path.splitext(os.path.basename(fpath))[0]

      tx.run("""
        MERGE (p:PublicProcess { ppn: $ppn })
        MERGE (i:Intervention { case: $case })
        MERGE (d:Document { sha256: $sha256 })
        MERGE (i)-[:INVOLVING]->(s:Submission { name: $submission_name })
        MERGE (s)-[:CONTAINING]->(d)
        MERGE (i)-[:SUBMITTED_TO]->(p)
      """, ppn=meta['ppn'], case=int(meta['case']), sha256=sha256, submission_name=meta['submission_name'])

      tx.run("""
        MATCH (d:Document { sha256: $sha256 })
        SET d += $props
      """, sha256=sha256, props=meta)

# This is stuff that would be ideally found in the data but isn't really derivable at this point.
# Instead, we're explicitly setting it based on expert knowledge of the way these things work. This
# would perhaps end up being something that always has to be entered by someone.
def merge_expert_knowledge():
  with transaction() as tx:
    tx.run("""
    MATCH (p:PublicProcess { ppn: '2015-134' })
    MERGE (phase1:Phase { name: 'Phase 1' })
    MERGE (phase2:Phase { name: 'Phase 2' })
    MERGE (p)-[:CONSISTING_OF]->(phase1)
    MERGE (p)-[:CONSISTING_OF]->(phase2)
    MERGE (phase1)-[:FOLLOWED_BY]->(phase2)
    """)

def merge_raw_text():
  print("Parsing text and merging as raw_text on Documents")
  with transaction() as tx:
    for r in tx.run("""
      MATCH (d:Document) WHERE NOT EXISTS(d.raw_text) RETURN d.sha256 AS sha256, d.type as type
      """):
      sha256 = r['sha256']
      txtpath = os.path.join(txtdir, f"{sha256}.txt")
      if os.path.exists(txtpath):
        with open(txtpath, "r") as txtfile:
          tx.run("""
            MATCH (doc:Document { sha256: $sha256 })
            SET doc.raw_text = $raw_text
          """, sha256=sha256, raw_text=txtfile.read())

        if r['type'] == 'html':
          hashedpath = os.path.join(hasheddir, f"{sha256}.html")
          with open(hashedpath, "r", encoding="latin-1") as htmlfile:
            tx.run("""
              MATCH (doc:Document { sha256: $sha256 })
              SET doc.raw_html = $raw_html
            """, sha256=sha256, raw_html=htmlfile.read())

def merge_content():
  with transaction() as tx:
    results = tx.run("""
      MATCH (d:Document)
      WHERE NOT EXISTS(d.content)
      RETURN d.type AS type, d.raw_text AS raw_text, d.raw_html AS raw_html, ID(d) AS id
    """)
    for r in results:
      content = None
      if r["type"] == "html":
        doc = HTMLSubmission(r["raw_html"])
        content = doc.comment()
      else:
        content = r["raw_text"]

      tx.run("""
        MATCH (d:Document)
        WHERE ID(d) = $id
        SET d.content = $content
      """, id=r["id"], content=content)
  
def merge_participant(name, title, organization, role):
  if not (name or title or organization):
    return None

  def appendif(check_var, toarray, line):
    if check_var:
      toarray.append(line)
    return toarray

  participant_data = ["role: $role"]
  if name:
    participant_data.append("name: $name")
  if title:
    participant_data.append("title: $title")
  if organization:
    participant_data.append("organization: $organization")

  query_parts = []
  query_parts.append("MERGE (participant:Participant { %s })" % ", ".join(participant_data))
  query_parts.append("WITH participant")
  query_parts = appendif(name, query_parts, "MERGE (person:Person { name: $name })")
  query_parts = appendif(organization, query_parts, "MERGE (org:Organization { name: $organization })")
  query_parts = appendif(title and organization, query_parts, "MERGE (title:Title { name: $title })-[:ON_BEHALF_OF]->(org)")
  query_parts = appendif(name and title and not organization, query_parts, "MERGE (person)-[:WITH_TITLE]->(title:Title { name: $title })")
  query_parts = appendif(name and title and organization, query_parts, "MERGE (person)-[:WITH_TITLE]->(title)")
  query_parts = appendif(name, query_parts, "MERGE (person)-[:ACTING_AS]->(participant)")
  query_parts = appendif(title, query_parts, "MERGE (title)-[:ACTING_AS]->(participant)")
  query_parts = appendif(organization, query_parts, "MERGE (org)-[:ACTING_AS]->(participant)")
  query_parts.append("RETURN ID(participant) AS id")
  query = "\n".join(query_parts)

  with transaction() as tx:
    results = tx.run(query, name=name, title=title, organization=organization, role=role)
  
  return next(results.records())['id']

def merge_submitter(role):
  print("Finding %(role)ss from HTML document submissions related to an Intervention" % locals())
  with transaction() as tx:
    results = tx.run("""
      MATCH (s:Submission)-[:CONTAINING]->(d:Document {type:'html'})
      WHERE NOT (:Participant { role: $role })-[:PARTICIPATES_IN]->(s:Submission) 
      RETURN ID(s) AS id, d.raw_html AS raw_html
    """, role=role)

    for r in results:
      doc = HTMLSubmission(r["raw_html"])
      role_function = None
      if role == "Client":
        role_function = doc.client_info
      elif role == "Designated Representative":
        role_function = doc.designated_representative

      person_name = role_function("Name")
      person_title = role_function("Title")
      org_name = role_function("On behalf of company")
      submission_id = r["id"]

      participant_id = merge_participant(person_name, person_title, org_name, role)
      if participant_id:
        tx.run("""
          MATCH (s:Submission)
          WHERE ID(s) = $submission_id
          WITH s
          MATCH (r)
          WHERE ID(r) = $participant_id
          MERGE (r)-[:PARTICIPATES_IN]->(s)
        """, submission_id=submission_id, participant_id=participant_id)

def ymd_to_int(year, month, day):
  return year * 10000 + month * 100 + day

def int_to_ymd(num):
  day = int(num % 100)
  month = int(((num - day) / 100) % 100)
  year = int((num - (month * 100 + day)) / 10000)
  return (year, month, day)

def merge_dates():
  print("Attaching date_arrived to Submissions where it can be found")
  with transaction() as tx:
    results = tx.run("""
      MATCH (s:Submission)-[:CONTAINING]->(d:Document {type:'html'})
      WHERE NOT EXISTS(s.date_arrived)
      RETURN ID(s) as id, d.raw_html as raw_html
    """)

    for r in results:
      doc = HTMLSubmission(r["raw_html"])
      date_arrived = doc.top_level("Date Arrived")
      if date_arrived:
        ymd = re.match(r"(\d{4})-(\d{2})-(\d{2})", date_arrived).groups()
        date_arrived_val = ymd_to_int(*[int(n) for n in ymd])
        tx.run("""
          MATCH (s:Submission)
          WHERE ID(s) = $id
          SET s.date_arrived = $date_arrived
        """, id=r['id'], date_arrived=date_arrived_val) 
        
        
def topics():
  print("Creating topics")
  topics = os.path.join(csvdir, 'topics.csv')
  with open(topics) as csvfile:
    readCSV = csv.reader(csvfile)
    next(readCSV)
    i=1
    for row in readCSV:
        print(row[6], row[1],row[2],row[3],row[4],row[5])
        with transaction() as tx:
                tx.run("""
                       MERGE (to:topic { label:$label,id: $id})
                       MERGE (te1:term { word: $word1 })
                       MERGE (te2:term { word: $word2 })
                       MERGE (te3:term { word: $word3 })
                       MERGE (te4:term { word: $word4 })
                       MERGE (te5:term { word: $word5 })
                       MERGE (to)-[r1:RankIn {rank:1}]->(te1)
                       MERGE (to)-[r2:RankIn {rank:2}]->(te2)
                       MERGE (to)-[r3:RankIn {rank:3}]->(te3)
                       MERGE (to)-[r4:RankIn {rank:4}]->(te4)
                       MERGE (to)-[r5:RankIn {rank:5}]->(te5)
                       """, id=i,label=row[6], word1=row[1], word2=row[2], word3=row[3], word4=row[4], word5=row[5])
        i=i+1

def categories():
  print("Creating categories")
  categories = os.path.join(csvdir, 'Categories.csv')
  with open(categories) as csvfile:
    readCSV = csv.reader(csvfile)
    next(readCSV)
    i=1
    for row in readCSV:
        print(row[0], row[1],i)
        with transaction() as tx:
                tx.run("""
                       MERGE (c:category { name:$name,id: $id})
                       """, id=i,name=row[0])
                tx.run("""
                       MATCH (c:category {id:$id}), (t:topic {id:$topic_id})
                       CREATE (c)-[:MOST_DIAGNOSED]->(t)
                       """, id=i,topic_id=int(row[1]))
        i=i+1

def doc_category_topic():
  print("Creating relationship between topics/categories and documents")
  doc_topics = os.path.join(csvdir, 'doc_topics.csv')
  with open(doc_topics) as csvfile:
    readCSV = csv.reader(csvfile)
    next(readCSV)
    for row in readCSV:
        print(row[2], row[3],row[4])
        with transaction() as tx:
                tx.run("""
                       MATCH (d:Document {name:$name}), (t:topic {id:$topic_id})
                       CREATE (d)-[:HAS_TOPIC]->(t)
                       """, name=row[2],topic_id=int(row[3]))
               # tx.run("""
               #        MATCH (d:Document {name:$name}), (c:category {name:$c_name})
                #       CREATE (d)-[:HAS_CATEGORY]->(c)
                #       """, name=row[2],c_name=row[4])
  

merge_core()
merge_expert_knowledge()
merge_raw_text()
merge_content()
merge_submitter("Client")
merge_submitter("Designated Representative")
merge_dates()
topics()
doc_category_topic()