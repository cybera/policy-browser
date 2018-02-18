import pysolr

class Neo4JToSolr(TransformBase):

  DESCRIPTION = "Import documents that haven't been imported into Solr"
  CHUNK_SIZE = 500

  def preconditions(self):
    self.solr = pysolr.Solr('http://solr:8983/solr/cira', timeout=10)

  def match(self):
    with neo4j() as tx:
      results = tx.run("""
        MATCH (doc:Document)
        WHERE NOT EXISTS(doc.in_solr) OR NOT doc.in_solr
        RETURN doc.content AS content, 
              doc.sha256 AS sha256, 
              doc.name AS name, 
              doc.type AS type, 
              doc.case AS case, 
              doc.ppn AS ppn, 
              doc.dmid AS dmid, 
              doc.submission_name AS submission_name, 
              doc.container_filename AS container_filename,
              "Document" AS label,
              doc.sha256 AS id
      """)
    return list(results)

  def transform(self, data):
    # Break into chunks of CHUNK_SIZE to more efficiently import data into Solr
    chunks = [data[i:i+self.CHUNK_SIZE] for i in range(0, len(data), self.CHUNK_SIZE)]

    records_added = 0
    tx_results = []

    with neo4j() as tx:
      for c in chunks:
        print(f"Added: {records_added}\r", end="")
        
        # Add the chunk of documents to Solr
        self.solr.add(c)

        # Update neo4j that the document is now in Solr
        sha256s = [r['sha256'] for r in c]
        results = tx.run("""
          MATCH (doc:Document)
          WHERE doc.sha256 IN $sha256s
          SET doc.in_solr = true
        """, sha256s=sha256s)
        tx_results.append(results)

        # Increment records added for status printing and result reporting
        records_added += len(c)

    return [ f"{records_added} documents added to Solr" ] + neo4j_summary(tx_results)


