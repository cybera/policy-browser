import csv


class AddQA(TransformBase):

    

    DESCRIPTION = "Add Q&A data to the graph"


    def preconditions(self):       
        self.answer_path = []
        self.answer_path.append(path.join(project_root.data.processed, "intervenors_Q_A.csv"))
        for file in self.answer_path:     
            self.check_file(file)
       

    def match(self):
        existing_org = neo4j_count("MATCH (o:Organization)")
        return ((existing_org > 180))
    


    def transform(self, data):
        tx_results = []
        for i, datafile in enumerate(self.answer_path):
                with open(datafile) as csvfile:
                    readCSV = csv.reader(csvfile)
                    next(readCSV)
                    for row in readCSV:
                        with neo4j() as tx:
                            results=tx.run(""" 
                            MERGE (or:Organization {name:$Responder_reformat})
                            MERGE (oa:Organization {name:$Questioner_reformat})
                            """, Questioner_reformat=row[0],Responder_reformat=row[2])
                            tx_results.append(results)
                        if row[4] in ["Q.Phase1", "Q.Phase2", "Q.Phase3", "Q.Phase4"]:
                            with neo4j() as tx:
                                results=tx.run(""" 
                                MATCH (oa:Organization {name:$Questioner_reformat})
                                MATCH (or:Organization {name:$Responder_reformat})
                                MERGE (oa)-[r:ASKED {round:$Type}]->(or)
                                on create set r.date_arrived = $Date
                                """, Questioner_reformat=row[0],Responder_reformat=row[2],Type=row[4],Date=row[5])
                                tx_results.append(results)
                        elif row[4] in ["A.Phase1", "A.Phase2", "A.Phase3", "A.Phase4"]:
                            with neo4j() as tx:
                                results=tx.run(""" 
                                MATCH (oa:Organization {name:$Questioner_reformat})
                                MATCH (or:Organization {name:$Responder_reformat})
                                MERGE (or)-[r:REPLIED {round:$Type}]->(oa)
                                on create set r.date_arrived = $Date
                                """, Questioner_reformat=row[0],Responder_reformat=row[2],Type=row[4],Date=row[5])
                                tx_results.append(results)

        return neo4j_summary(tx_results)

