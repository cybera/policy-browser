from difflib import SequenceMatcher as FuzzyMatcher
import numpy as np

class ImportZipOranizationRelationships(TransformBase):
  DESCRIPTION = "Infer organization relationships from filenames in zipfiles"
  METHOD_TAG = "zipfile-name-fuzzy-match"

  def match(self):
    with neo4j() as tx:
      results = tx.run("""
        MATCH (d:Document) 
        WHERE 
          d.name STARTS WITH 'DM#' AND
          NOT (:Organization)-[:SUBMITTED { method: $method }]->(d)
        RETURN ID(d) AS id, d.name AS name
      """, method=self.METHOD_TAG)
    return results

  def transform(self, data):
    tx_results = []

    with neo4j() as tx:
      for row in data:
        nodeid = row['id']
        name = row['name']
        name_parts = [part.strip() for part in path.splitext(name)[0].split(" - ")]
        fm = self.fuzzy_match_organization(name_parts, threshold=0.6)
        if fm:
          results = tx.run("""
            MATCH (doc:Document)
            MATCH (org:Organization)
            WHERE
              ID(doc) = $docid AND
              ID(org) = $orgid
            MERGE (org)-[r:SUBMITTED { method: $method }]->(doc)
            ON CREATE SET r.confidence = $score
          """, docid=nodeid, orgid=fm['id'], method=self.METHOD_TAG, score=fm['score'])
          tx_results.append(results)
    return neo4j_summary(tx_results)

  def fuzzy_match_organization(self, candidates, threshold=0.7):
    scores = [0] * len(candidates)
    closest = [None] * len(candidates)

    for index, candidate in enumerate(candidates):
      for name in self.organizations():
        score = FuzzyMatcher(None, name, candidate).ratio()
        if score > scores[index]:
          scores[index] = score
          closest[index] = name

    max_index = np.argmax(scores)
    max_score = scores[max_index]
    if max_score >= threshold:
      orgname = closest[max_index]
      orgid = self.organizations()[orgname]
      return { 'name': orgname, 'id': orgid, 'score': max_score }
    else:
      return None

  def organizations(self):
    if not hasattr(self, '__organizations'):
      with neo4j() as tx:
        self.__organizations = {}
        for row in tx.run("MATCH (o:Organization) RETURN ID(o) as id, o.name as name"):
          self.__organizations[row['name']] = row['id']
    return self.__organizations