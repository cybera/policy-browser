#!/usr/bin/env python

import csv
from os.path import join as path_join
from neo4j.v1 import GraphDatabase
from contextlib import contextmanager

uri = "bolt://neo4j:7687"
driver = GraphDatabase.driver(uri, auth=("neo4j", "password"))

@contextmanager
def transaction():
  with driver.session() as session:
    with session.begin_transaction() as tx:
      yield tx

project_dir = "/mnt/hey-cira"
data_dir = path_join(project_dir, "data")
processed_dir = path_join(data_dir, "processed")

with transaction() as tx:
  with open(path_join(processed_dir, "sorted-document-organizations.csv")) as csvfile:
    reader = csv.DictReader(csvfile)
    for row in reader:
      tx.run("""
        MATCH (doc:Document { sha256: $sha256 })
        MERGE (o:Organization { name: $orgname })
        MERGE (o)-[:SUBMITTED]->(doc)
      """, sha256=row['sha256'], orgname=row['organization'])
