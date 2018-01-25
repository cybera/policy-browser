class CreateQuestions(TransformBase):
  DESCRIPTION = "Create initial Question nodes"

  def match(self):
    refs=["Q9", "Q4", "Q12"]
    existing = neo4j_count("MATCH (q:Question) WHERE q.ref IN $ref", ref=refs)
    return existing == 0
    
  def transform(self, data):
    tx_results = []
    with neo4j() as tx:
      tx_results.append(self.create_question(tx, "Q9", "Should broadband Internet service be defined as a basic telecommunications service? What other services, if any, should be defined as basic telecommunications services?"))
      tx_results.append(self.create_question(tx, "Q4", "Can market forces and government funding be relied on to ensure that all Canadians have access to basic telecommunications services? What are the roles of the private sector and the various levels of government (federal, provincial, territorial, and municipal) in ensuring that investment in telecommunications infrastructure results in the availability of modern telecommunications services to all Canadians?"))
      tx_results.append(self.create_question(tx, "Q12", "Should some or all services that are considered to be basic telecommunications services be subsidized? Explain, with supporting details, which services should be subsidized and under what circumstances.")) 

    return neo4j_summary(tx_results)

  def create_question(self, tx, ref, content):
    query = """
      MERGE (q:Question { ref: $ref })
      ON CREATE SET q += $props
      ON MATCH SET q += $props
    """
    return tx.run(query, ref=ref, props={ 'content': content })