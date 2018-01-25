import csv

class HandSortedDocCSVImport(TransformBase):
  DESCRIPTION = "Import hand sorted documents"
  METHOD_TAG = "hand-sorted"

  def preconditions(self):
    self.csv_path = path.join(project_root.data.processed, "sorted-document-organizations.csv")
    self.check_file(self.csv_path)

  def match(self):
    sha256s = [row['sha256'] for row in self.csv_rows()]
    return neo4j_count("""
      MATCH (doc:Document)
      WHERE 
        doc.sha256 in $sha256s AND
        NOT (:Organization)-[:SUBMITTED { method: $method }]->(doc)
    """, method=self.METHOD_TAG, sha256s=sha256s)

  def transform(self, data):
    tx_results = []
  
    with neo4j() as tx:
      with open(self.csv_path) as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
          results = tx.run("""
            MATCH (doc:Document { sha256: $sha256 })
            MERGE (o:Organization { name: $orgname })
            MERGE (o)-[:SUBMITTED { method: $method }]->(doc)
          """, sha256=row['sha256'], orgname=row['organization'], method=self.METHOD_TAG)
          tx_results.append(results)

    return neo4j_summary(tx_results)

  def csv_rows(self):
    if not hasattr(self,'__csv_rows'):
      with open(self.csv_path) as csvfile:
        reader = csv.DictReader(csvfile)
        self.__csv_rows = [row for row in reader]
    return self.__csv_rows