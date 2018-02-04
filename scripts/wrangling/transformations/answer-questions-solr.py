import hashlib
import os


class AnswerQuestionsSolr(TransformBase):

    

     DESCRIPTION = "Add solr search results to neo4j"

     def preconditions(self):
        
        self.Q_aff = ['content:"internet, expensive"~10 OR content:"broadband, expensive"~10 OR content:"services, expensive"~10 OR content:"service, expensive"~10',
                'content:"internet, cheap"~10 OR content:"broadband, cheap"~10 OR content:"services, cheap"~10 OR content:"service, cheap"~10',
                'content:"internet, affordable"~10 OR content:"broadband, affordable"~10 OR content:"services, affordable"~10 OR content:"service, affordable"~10' ,
                'content:"internet, affordability"~10 OR content:"broadband, affordability"~10 OR content:"services, affordability"~10 OR content:"service, affordability"~10' ,
                'content:"internet, cost"~10 OR content:"broadband, cost"~10 OR content:"services, cost"~10 OR content:"service, cost"~10',
                'content:"internet, price"~10 OR content:"broadband, price"~10 OR content:"services, price"~10 OR content:"service, price"~10']
    

     def match(self):
        q_aff = self.Q_aff
        existing_query = neo4j_count("MATCH (q:Query) WHERE q.str IN $ref", ref=q_aff)
        existing_doc = neo4j_count("MATCH (d:Document)")
        ##existing_question = neo4j_count("MATCH (q:Question) WHERE q.ref IN $ref", ref=['Affordability']) need to check if question exists as well

        return (existing_query==0) is (existing_doc > 0)
             

       
     def transform(self, data):
        os.system("python /mnt/hey-cira/scripts/wrangling/segment.py 'content:\"internet, expensive\"~10 OR content:\"broadband, expensive\"~10 OR content:\"services, expensive\"~10 OR content:\"service, expensive\"~10' --add --rows=117")
        os.system("python /mnt/hey-cira/scripts/wrangling/segment.py 'content:\"internet, cheap\"~10 OR content:\"broadband, cheap\"~10 OR content:\"services, cheap\"~10 OR content:\"service, cheap\"~10' --add --rows=6")  
        os.system("python /mnt/hey-cira/scripts/wrangling/segment.py 'content:\"internet, affordable\"~10 OR content:\"broadband, affordable\"~10 OR content:\"services, affordable\"~10 OR content:\"service, affordable\"~10'  --rows=372 --add")  
        os.system("python /mnt/hey-cira/scripts/wrangling/segment.py 'content:\"internet, affordability\"~10 OR content:\"broadband, affordability\"~10 OR content:\"services, affordability\"~10 OR content:\"service, affordability\"~10' --add --rows=242")  
        os.system("python /mnt/hey-cira/scripts/wrangling/segment.py 'content:\"internet, cost\"~10 OR content:\"broadband, cost\"~10 OR content:\"services, cost\"~10 OR content:\"service, cost\"~10' --add --rows=501")  
        os.system("python /mnt/hey-cira/scripts/wrangling/segment.py 'content:\"internet, price\"~10 OR content:\"broadband, price\"~10 OR content:\"services, price\"~10 OR content:\"service, price\"~10' --rows=410 --add")  
        
        # add relationships between queries and question
        #tx_results = []
        #q_aff = self.Q_aff
        #with neo4j() as tx:
        #      results = tx.run("""
        #      MATCH 
        #      (qr:Query)  where qr.str in IN $query
        #      MATCH (qs:Question {ref: $question}) 
        #      CREATE UNIQUE (qr)-[:RELATED]->(qs)
        #      """, query=q_aff, question='Affordability')
        #      tx_results.append(results)
        #      return neo4j_summary(tx_results)
        return ["Added solr results for affordabilitu question to neo4j"]

