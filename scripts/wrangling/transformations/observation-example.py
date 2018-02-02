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
        MATCH (q:Query { str: $solr_query })
        MATCH (question:Question { ref: $ref })
        WHERE NOT (q)-[:ABOUT]->(question)
        RETURN ID(q) AS query, ID(question) AS question
      """, solr_query=self.solr_query, ref=self.qref)

    return [ { 'query': r['query'], 'question': r['question'] } for r in results ]

    
  def transform(self, data):
    tx_results = []

    with neo4j() as tx:
      for qq in data:
        tx_results.append(tx.run("""
          MATCH (question:Question), (query:Query)
          WHERE ID(question) = $question_id AND ID(query) = $query_id
          MERGE (query)-[:ABOUT]->(question)
        """, question_id=qq['question'], query_id=qq['query']))

    return neo4j_summary(tx_results)