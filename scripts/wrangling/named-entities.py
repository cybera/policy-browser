#!/bin/env python

import nltk
import sqlite3

from nltk import word_tokenize, pos_tag, ne_chunk

conn = sqlite3.connect('data/processed/docs.db')

rows = conn.execute("SELECT * FROM docs").fetchall()

#content = [row[2] for row in rows]
docids, content = list(zip(*[(row[0],row[2]) for row in rows]))

def traverse(tree, label_name):
  nodes = []
  for branch in tree:
    if "label" in dir(branch):
      if branch.label() == label_name:
        words = [leaf[0] for leaf in branch]
        nodes.append(" ".join(words))
    elif type(branch) == tuple:
      nodes = nodes + traverse(branch,label_name)

  return nodes

def extract_entities(text, label_name="NE"):
  if label_name == "NE":
    binary_tag = True
  else:
    binary_tag = False

  named_entities = ne_chunk(pos_tag(word_tokenize(text)), binary=binary_tag)
  return list(set(traverse(named_entities,label_name)))

facilities = [extract_entities(c, "FACILITY") for c in content]
people = [extract_entities(c, "PERSON") for c in content]
organizations = [extract_entities(c, "ORGANIZATION") for c in content]
gpes = [extract_entities(c, "GPE") for c in content]
dates = [extract_entities(c, "DATE") for c in content]
locations = [extract_entities(c, "LOCATION") for c in content]
times = [extract_entities(c, "TIME") for c in content]
named_entities = [extract_entities(c, "NE") for c in content]

def insert_entities(docids, entity_list, entity_type, connection):
  for docid,entities in zip(docids,entity_list):
    if len(entities) > 0:
      inserts = [(docid,entity_type,entity) for entity in entities]
      connection.executemany("INSERT INTO docentities (docid,type,value) VALUES (?,?,?)", inserts)

insert_entities(docids, facilities, "FACILITY", conn)
insert_entities(docids, people, "PERSON", conn)
insert_entities(docids, organizations, "ORGANIZATION", conn)
insert_entities(docids, gpes, "GPE", conn)
insert_entities(docids, dates, "DATE", conn)
insert_entities(docids, locations, "LOCATION", conn)
insert_entities(docids, times, "TIME", conn)
insert_entities(docids, named_entities, "NE", conn)

conn.commit()