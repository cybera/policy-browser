### Question9:

Should broadband Internet service be defined as a basic telecommunications service? What other services, if any, should be defined as basic telecommunications services?


### Solr queries:

- bin/segment 'content:"basic telecommunications service"' --rows=202 --add
- bin/segment 'content:"basic telecommunications services"' --rows=657 --add
- bin/segment 'content:"internet, basic telecommunications service"~10 OR "broadband, basic telecommunications service"~10' --add --rows=87
- bin/segment 'content: "What other services, if any, should be defined as basic telecommunications services?"' --add --rows=30

### Doc2vec queries:
Should broadband Internet services be considered basic telecommunications services BTS?

### Summary stats:
Note: Numbers may be variable depending on what version of the application you're currently using.

Category| Number of docs in database | Number of docs covered by solr search results | Number of docs covered by  doc2vec results|
--- | --- | --- | --- |
Advocacy organizations |  264 | 109 | 106   
Chamber of commerce/economic dev agency |  4 | 0 | 0   
Government  | 111 | 41 | 43   
Network operator - Cable companies | 125 | 69 | 53   
Network operator: other | 208 | 81 | 80    
Network operator: Telecom Incumbents | 342 |  90 | 105    
None  | 1320  | 197  |  308  
Other | 90 | 28 | 32
Small incumbents  | 11  | 5 | 3   
