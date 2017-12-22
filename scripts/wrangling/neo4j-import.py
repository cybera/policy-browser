#!/usr/bin/env python

import os, re
from neo4j.v1 import GraphDatabase
from html_submission import HTMLSubmission
from contextlib import contextmanager

uri = "bolt://neo4j:7687"
driver = GraphDatabase.driver(uri, auth=("neo4j", "password"))

@contextmanager
def transaction():
  with driver.session() as session:
    with session.begin_transaction() as tx:
      yield tx

scrapedir = os.path.join("data", "raw")
txtdir = os.path.join("data", "processed", "raw_text")

def merge_core():
  print("Using filenames to merge PublicProcess, Intervention, and Document nodes")
  with transaction() as tx:
    for fname in os.listdir(scrapedir):
      if fname != ".gitignore" and fname != ".DS_Store":
        dtype=fname.rsplit('.', 1)[1]
        the_rest=fname.rsplit('.', 1)[0]
        [public_process_number,case,dmid,submission_and_orig_filename] = the_rest.split('.', 3)
        submission_name = re.sub(r'\(.*\)','', submission_and_orig_filename)

        tx.run("""
          MERGE (p:PublicProcess { ppn: $ppn })
          MERGE (i:Intervention { case: $case })
          MERGE (d:Document { dmid: $dmid, type: $dtype, name: $fname })
          MERGE (i)-[:INVOLVING]->(s:Submission { name: $submission_name })
          MERGE (s)-[:CONTAINING]->(d)
          MERGE (i)-[:SUBMITTED_TO]->(p)
        """, ppn=public_process_number, case=int(case), dmid=int(dmid), dtype=dtype, fname=fname, submission_name=submission_name)

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

def merge_content():
  with transaction() as tx:
    results = tx.run("""
      MATCH (d:Document)
      WHERE NOT EXISTS(d.content)
      RETURN d.type AS type, d.raw_text AS raw_text, ID(d) AS id
    """)
    for r in results:
      content = None
      if r["type"] == "html":
        doc = HTMLSubmission(r["raw_text"])
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
      RETURN ID(s) AS id, d.raw_text AS raw_text
    """, role=role)

    for r in results:
      doc = HTMLSubmission(r["raw_text"])
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
  
merge_core()
merge_expert_knowledge()
merge_raw_text()
merge_content()
merge_submitter("Client")
merge_submitter("Designated Representative")