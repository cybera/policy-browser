import hashlib
class AnswerQuestions(TransformBase):
    
    


    DESCRIPTION = "Adds (potentially) relevant segments in documents which (potentially) answer questions."
    METHOD_TAG = 'doc2vec-MonteCarlo'
    def sha256str(self, text):
        hash_sha256 = hashlib.sha256()
        hash_sha256.update(text.encode())
        return hash_sha256.hexdigest()


    def preconditions(self):
        
        self.qref = "Q9"
        self.answer_path = path.join(project_root.data.processed, "Basic_Service_Question.txt")
        self.check_file(self.answer_path)

    def insert_newlines(self,string, characters = 128):
        # break up the long sentence into a shorter one on spaces
        # so it's readable online rather than one really long line
        words = iter(string.split())
        lines, current = [], next(words)
        for word in words:
            if len(current) + 1 + len(word) > characters:
                lines.append(current)
                current = word
            else:
                current += " " + word

        lines.append(current)

        return "\n".join(lines)

    def match(self):
        refs = self.qref
        existing = neo4j_count("MATCH (q:Question) WHERE q.ref IN $ref", ref=refs)
        existing2 = neo4j_count("MATCH (d:Document)")
        # So... this is probably a bad idea but let's work with it for now
        return existing < len(refs) and existing2 > 0
    


    def transform(self, data):
        
        tx_results = []
        with neo4j() as tx:
            with open(self.answer_path) as file:
                for answer in file.readlines():
                    text = str(answer.split(" OBVIOUS_DELIMITER ")[0])
                    docs = str(answer.split(" OBVIOUS_DELIMITER ")[1]).strip()
                    query = "Should broadband Internet service be defined as a basic telecommunications service (BTS)?"
                    seg = self.sha256str(text)

                    results = tx.run("""
                        MATCH (doc:Document {sha256: $sha256})
                        MATCH (Q:Question {ref: $qref})
                        MERGE (Qe:Query {query: $query})
                        MERGE (s:Segment {seg: $seg}) 
                        MERGE (r:raw_text_segment {content: $content})
                        MERGE (Q)-[:RELATED {method: $method}] -> (Qe) 
                        MERGE (Qe) -[:MATCHES]->(s) 
                        MERGE (s) -[:SEGMENT_OF] -> (doc)
                        SET s.content =$content
                    """, sha256=docs, qref=self.qref, seg=seg, content=text, method=self.METHOD_TAG, query=query)
                    tx_results.append(results)

        return neo4j_summary(tx_results)


    # Segment.py