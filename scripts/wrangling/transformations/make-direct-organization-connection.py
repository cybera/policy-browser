class MakeDirectOrganizationConnection(TransformBase):
  DESCRIPTION = "Relate org->doc directly when html form submission exists"

  def match(self):
    return neo4j_count("""
      MATCH (o:Organization)-->(:Participant { role: 'Client'})-->(:Submission)-->(d:Document)
      WHERE NOT (o)-[:SUBMITTED {method: $method }]->(d)
    """, method='html-submission-forms')
    
  def transform(self, data):
    with neo4j() as tx:
      results = tx.run("""
        MATCH (o:Organization)-->(:Participant { role: 'Client'})-->(:Submission)-->(d:Document)
        WHERE NOT (o)-[:SUBMITTED { method: $method }]->(d)
        MERGE (o)-[r:SUBMITTED {method: $method }]->(d)
      """, method='html-submission-forms')

    return neo4j_summary(results)
