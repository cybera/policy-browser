class ObservationExample(TransformBase):
  DESCRIPTION = "Example of associating some results with a question"

  def preconditions(self):
    self.qref = "Q9-1"
    self.solr_query = """
      content:"basic telecommunications service"~5
    """.strip()

  def match(self):
    results = []

    with neo4j() as tx:
      results = tx.run("""
        MATCH (q:Query { str: $solr_query })<--(s:Segment)
        MATCH (question:Question { ref: $ref })
        WHERE NOT (s)-[:IN_OBSERVATION]->(:Observation)-[:CONCERNING]->(question)
        RETURN ID(s) AS id
      """, solr_query=self.solr_query, ref=self.qref)

    return [ r['id'] for r in results ]

    
  def transform(self, data):
    tx_results = []

    with neo4j() as tx:
      for segment_id in data:
        tx_results.append(tx.run("""
          MATCH (question:Question { ref: $ref })
          MATCH (segment:Segment)
          WHERE ID(segment) = $sid
          MERGE (segment)-[:IN_OBSERVATION]->(observation:Observation { group:'segment' })
          MERGE (observation)-[:CONCERNING { confidence: 0.9 }]->(question)
        """, ref=self.qref, sid=segment_id))

    return neo4j_summary(tx_results)