
#### Question9:

Should broadband Internet service be defined as a basic telecommunications service? What other services, if any, should be defined as basic telecommunications services?


`Solr searches`

- bin/segment 'content:" basic telecommunications service"' --rows=180 --add
- bin/segment 'content:" basic telecommunications services"' --rows=625 --add
- bin/segment 'content:"internet, basic telecommunications service"~10 OR "broadband, basic telecommunications service"~10' --add --rows=82
- bin/segment 'content: "What other services, if any, should be defined as basic telecommunications services?"' --add --rows=28

`Doc2VecSearch` 
Should broadband Internet services be considered basic telecommunications services BTS?


`Results`

Category| In database | Solr # of documents | Doc2Vec # of documents |   
--- | --- | --- | --- |  
Advocacy organizations |  289 | 119 | 49 |  
Chamber of commerce/economic dev agency |  4 | 0 | 0 |  
Consumer advocacy organizations | 3 | 2  |  1 |
Government  | 134 | 44 | 12  |  
Network operator - Cable companies | 118 | 66 | 19  |  
Network operator: other | 271 | 92 | 34  |   
Network operator: Telecom Incumbents | 339 |  90 | 27 |   
Other | 107 | 35 | 9 |  
Small incumbents  | 66  | 25 | 15 |  

- 665 documents
- 474 - have organization
- 473 - have category
- 95 organizations out of 175 covered
