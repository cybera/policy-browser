import os
import pysolr

class AnswerQuestionsSolr(TransformBase):

    

     DESCRIPTION = "Add solr search results to neo4j"
     METHOD_TAG = 'solr'

     def preconditions(self):
        
        self.qref = ["Q1","Q4","Q9","Q9-1","Q12"]
        
        self.Qe = [['content:"internet, expensive"~10 OR content:"broadband, expensive"~10 OR content:"services, expensive"~10 OR content:"service, expensive"~10',
                'content:"internet, cheap"~10 OR content:"broadband, cheap"~10 OR content:"services, cheap"~10 OR content:"service, cheap"~10',
                'content:"internet, affordable"~10 OR content:"broadband, affordable"~10 OR content:"services, affordable"~10 OR content:"service, affordable"~10' ,
                'content:"internet, affordability"~10 OR content:"broadband, affordability"~10 OR content:"services, affordability"~10 OR content:"service, affordability"~10' ,
                'content:"internet, cost"~10 OR content:"broadband, cost"~10 OR content:"services, cost"~10 OR content:"service, cost"~10',
                'content:"internet, price"~10 OR content:"broadband, price"~10 OR content:"services, price"~10 OR content:"service, price"~10'],
                ['content:"What are the roles of the private sector and the various levels of government (federal, provincial, territorial, and municipal) in ensuring that investment in telecommunications infrastructure results in the availability of modern telecommunications services to all Canadians?"'],
                ['content:"basic telecommunications service"',
                   'content:"basic telecommunications services"',
                   'content:"internet, basic telecommunications service"~10 OR "broadband, basic telecommunications service"~10',
                   'content: "What other services, if any, should be defined as basic telecommunications services?"'],
                ['content:"internet, basic service"~10 OR "broadband, basic service"~10'],
                ['content:"services, subsidies"~10 OR "service, subsidies"',
                    'content:"services, subsidy"~10 OR "service, subsidy"',
                    'content:"services, subsidized"~10 OR "service, subsidized"~10']
                ]
        
        

     def match(self):
        # Check to see if we actually have documents imported into solr before
        # trying to import actual search results. If the field doesn't exist at
        # all, any search will throw a SolrError exception.
        try:
            solr = pysolr.Solr('http://solr:8983/solr/crtc-docs', timeout=10)
            solr.search("content:000000")
        except pysolr.SolrError:
            return False

        queries = self.Qe
        questions=self.qref
        existing_query = neo4j_count("MATCH (q:Query) WHERE q.str IN $quer", quer=queries)
        existing_doc = neo4j_count("MATCH (d:Document)")
        existing_questions = neo4j_count("MATCH (q:Question) WHERE q.ref IN $ques", ques=questions)

        return ((existing_questions==len(questions)) and (existing_query==0) and (existing_doc > 0))
             

       
     def transform(self, data):
        #Q1
        os.system("python /mnt/policy-browser/scripts/wrangling/segment.py 'content:\"internet, expensive\"~10 OR content:\"broadband, expensive\"~10 OR content:\"services, expensive\"~10 OR content:\"service, expensive\"~10' --add --rows=156 --OMexclude")
        os.system("python /mnt/policy-browser/scripts/wrangling/segment.py 'content:\"internet, cheap\"~10 OR content:\"broadband, cheap\"~10 OR content:\"services, cheap\"~10 OR content:\"service, cheap\"~10' --add --rows=8 --OMexclude")  
        os.system("python /mnt/policy-browser/scripts/wrangling/segment.py 'content:\"internet, affordable\"~10 OR content:\"broadband, affordable\"~10 OR content:\"services, affordable\"~10 OR content:\"service, affordable\"~10'  --rows=428 --add --OMexclude")  
        os.system("python /mnt/policy-browser/scripts/wrangling/segment.py 'content:\"internet, affordability\"~10 OR content:\"broadband, affordability\"~10 OR content:\"services, affordability\"~10 OR content:\"service, affordability\"~10' --add --rows=246 --OMexclude")  
        os.system("python /mnt/policy-browser/scripts/wrangling/segment.py 'content:\"internet, cost\"~10 OR content:\"broadband, cost\"~10 OR content:\"services, cost\"~10 OR content:\"service, cost\"~10' --add --rows=566 --OMexclude")  
        os.system("python /mnt/policy-browser/scripts/wrangling/segment.py 'content:\"internet, price\"~10 OR content:\"broadband, price\"~10 OR content:\"services, price\"~10 OR content:\"service, price\"~10' --rows=458 --add --OMexclude")  
        #Q4
        os.system("python /mnt/policy-browser/scripts/wrangling/segment.py 'content:\"What are the roles of the private sector and the various levels of government (federal, provincial, territorial, and municipal) in ensuring that investment in telecommunications infrastructure results in the availability of modern telecommunications services to all Canadians?\"' --add --rows=28 --OMexclude")
        #Q9
        os.system("python /mnt/policy-browser/scripts/wrangling/segment.py 'content:\"basic telecommunications service\"' --rows=202 --add --OMexclude")
        os.system("python /mnt/policy-browser/scripts/wrangling/segment.py 'content:\"basic telecommunications services\"' --rows=657 --add --OMexclude")
        os.system("python /mnt/policy-browser/scripts/wrangling/segment.py 'content:\"internet, basic telecommunications service\"~10 OR \"broadband, basic telecommunications service\"~10' --add --rows=87 --OMexclude")
        os.system("python /mnt/policy-browser/scripts/wrangling/segment.py 'content: \"What other services, if any, should be defined as basic telecommunications services?\"' --add --rows=30 --OMexclude")
        #Q9-1
        os.system("python /mnt/policy-browser/scripts/wrangling/segment.py 'content:\"internet, basic service\"~10 OR \"broadband, basic service\"~10' --add --rows=281 --OMexclude")
        #Q12
        os.system("python /mnt/policy-browser/scripts/wrangling/segment.py 'content:\"services, subsidies\"~10 OR \"service, subsidies\"' --add --rows=115 --OMexclude")
        os.system("python /mnt/policy-browser/scripts/wrangling/segment.py 'content:\"services, subsidy\"~10 OR \"service, subsidy\"' --rows=142 --add --OMexclude")
        os.system("python /mnt/policy-browser/scripts/wrangling/segment.py 'content:\"services, subsidized\"~10 OR \"service, subsidized\"~10' --add --rows=93 --OMexclude")
        
        # add relationships between queries and questions
        tx_results = []
        for i in range(0,len(self.qref)): 
          print(self.qref[i])
          print(self.Qe[i])
          with neo4j() as tx:
              results = tx.run("""
              MATCH 
              (qr:Query)  where qr.str IN $queries
              MATCH (qs:Question {ref:$question})
              MERGE (qs)<-[:ABOUT {method:$method}]-(qr) 
              """, queries=self.Qe[i] , question=self.qref[i], method=self.METHOD_TAG)
              tx_results.append(results)
        return neo4j_summary(tx_results)
        

