import hashlib


class AnswerQuestions(TransformBase):

    

    DESCRIPTION = "Adds (potentially) relevant segments in documents which (potentially) answer questions."
    METHOD_TAG = 'doc2vec-MonteCarlo'


    def sha256str(self, text):
        hash_sha256 = hashlib.sha256()
        hash_sha256.update(text.encode())
        return hash_sha256.hexdigest()


    def preconditions(self):
        # I think this is probably an all or nothing approach 
        self.qref = ["Q4","Q9","Q12","Q1"]
        self.answer_path = []
     
        self.answer_path.append(path.join(project_root.data.processed, "Market_Forces_Question_1500_LT.txt"))
        self.answer_path.append(path.join(project_root.data.processed, "Basic_Service_Question_1500_LT.txt"))
        self.answer_path.append(path.join(project_root.data.processed, "Subsity_Question_1500_LT.txt"))
        self.answer_path.append(path.join(project_root.data.processed, "Affordability_Question_1500_LT.txt"))


       
        self.Qe = ["Can market forces and government funding be relied on to ensure that all Canadians have access to basic telecommunications services?",
                    "Should broadband Internet service be defined as a basic telecommunications service (BTS)?",
                    "Should some or all services that are considered to be basic telecommunications services be subsidized?",
                    "Affordability of broadband internet access"]
       
        for file in self.answer_path:     
            self.check_file(file)
       



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
        qes = self.Qe
        existing = neo4j_count("MATCH (q:Question) WHERE q.ref IN $ref", ref=refs)
        existing2 = neo4j_count("MATCH (d:Document)")
        existing3 = neo4j_count("MATCH (q:Query) WHERE q.str IN $qe", qe=qes)
        
        return ((existing == len(refs)) and (existing2 > 0) and (existing3 == 0))
    


    def transform(self, data):
        tx_results = []
        with neo4j() as tx:
            for i, datafile in enumerate(self.answer_path):
                with open(datafile) as file:
                    print("Adding relationships of ", datafile)
                    for answer in file.readlines():
                        text = str(answer.split(" OBVIOUS_DELIMITER ")[0])
                        doc256 = str(answer.split(" OBVIOUS_DELIMITER ")[1]).strip()
                        counts = int(str(answer.split(" OBVIOUS_DELIMITER ")[2].strip()))
                        
                       
                        query = self.Qe[i]
                        seg256 = self.sha256str(text)
                        results = tx.run(
                            """ MATCH (doc:Document {sha256: $doc256})
                            MATCH (Q:Question {ref: $qref})
                            MERGE (Qe:Query {str: $query})
                            MERGE (s:Segment {sha256: $seg256}) 
                            MERGE (Q)<-[:ABOUT {method: $method}]-(Qe) 
                            MERGE (Qe) <-[:MATCHES]- (s) 
                            MERGE (s) -[:SEGMENT_OF] -> (doc)
                            SET s.frequency = $counts
                            SET s.content = $content """, 
                            doc256=doc256, 
                            qref=self.qref[i], 
                            seg256=seg256, 
                            content=text, 
                            method=self.METHOD_TAG, 
                            query=query,
                            counts=int(counts))
                        tx_results.append(results)
            print("Doin' somethin' slow...")
        #print("OOGA BOOGA")
        return neo4j_summary(tx_results)

