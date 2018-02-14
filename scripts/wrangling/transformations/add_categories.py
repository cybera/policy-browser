import csv


class AddCategories(TransformBase):

    

    DESCRIPTION = "Adds categories to organizations"


    def preconditions(self):       
        self.answer_path = []
        self.answer_path.append(path.join(project_root.data.processed, "intervenor_categories.csv"))
        for file in self.answer_path:     
            self.check_file(file)
       

    def match(self):
        existing_org = neo4j_count("MATCH (o:Organization)")
        existing_cat = neo4j_count("MATCH (o:Organization) WHERE EXISTS(o.category)")
        return ((existing_org > 128) and (existing_cat == 0))
    


    def transform(self, data):
        tx_results = []
        for i, datafile in enumerate(self.answer_path):
                with open(datafile) as csvfile:
                    readCSV = csv.reader(csvfile)
                    next(readCSV)
                    for row in readCSV:
                        with neo4j() as tx:
                            results=tx.run("""MATCH (o:Organization {name:$name})
                            SET o.category=$category
                            """, name=row[1],category=row[2])
                            tx_results.append(results)

        return neo4j_summary(tx_results)

