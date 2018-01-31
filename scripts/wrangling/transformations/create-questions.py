class CreateQuestions(TransformBase):
  DESCRIPTION = "Create initial Question nodes"

  QUESTIONS = [
    {
      "ref": "Q4",
      "content": "Can market forces and government funding be relied on to ensure that all Canadians have access to basic telecommunications services? What are the roles of the private sector and the various levels of government (federal, provincial, territorial, and municipal) in ensuring that investment in telecommunications infrastructure results in the availability of modern telecommunications services to all Canadians?"
    },
    {
      "ref": "Q9",
      "content": "Should broadband Internet service be defined as a basic telecommunications service? What other services, if any, should be defined as basic telecommunications services?",
      "sub_questions": [
        {
          "ref": "Q9-1",
          "content": "What are organizations saying about whether the internet should be a basic service?"
        }
      ]
    },
    {
      "ref": "Q12",
      "content": "Should some or all services that are considered to be basic telecommunications services be subsidized? Explain, with supporting details, which services should be subsidized and under what circumstances."
    }
  ]

  def match(self):
    refs = self.refs()
    existing = neo4j_count("MATCH (q:Question) WHERE q.ref IN $ref", ref=refs)
    return existing < len(refs)
    
  def transform(self, data):
    tx_results = []
    with neo4j() as self.tx:
      for question in self.QUESTIONS:
        ref = question['ref']
        content = question['content']
        tx_results.append(self.create_question(ref, content))
        if 'sub_questions' in question:
          for sub_question in question['sub_questions']:
            sq_ref = sub_question['ref']
            content = sub_question['content']
            tx_results.append(self.create_question(sq_ref, content, parent_ref=ref))
    return neo4j_summary(tx_results)

  def refs(self):
    if not hasattr(self, "__refs"):
      self.__refs = []
      for question in self.QUESTIONS:
        self.__refs.append(question['ref'])
        if 'sub_questions' in question:
          for sq in question['sub_questions']:
            self.__refs.append(sq['ref'])
    return self.__refs

  def create_question(self, ref, content, parent_ref=None):
    query = """
      MERGE (q:Question { ref: $ref })
      ON CREATE SET q += $props
      ON MATCH SET q += $props
    """

    if parent_ref:
      query = query + """
        WITH q
        MATCH (parent:Question { ref: $parent_ref })
        MERGE (parent)-[:HAS_SUB_QUESTION]->(q)
      """

    return self.tx.run(query, ref=ref, parent_ref=parent_ref, props={ 'content': content })