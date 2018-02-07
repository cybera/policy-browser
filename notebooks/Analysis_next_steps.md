Next steps for data analysis in order A->B->C: 

A. Isolate segments to analyze
1. Use doc2vec and solr to grab relevant segments to either the BSO or affordability question
2. Determine how many docs there are for each organization category (e.g. Small incubments, advocacy organizations, etc)
3. Depending on the coverage provided by each method, either use that method or combine segments identified by both methods to go on to the analysis (step B)

B. Analyze the segments
1. Using analysis framework from comment in DS-323, begin comparison of text segments for different categories

Comment from DS-323: 
* how similarly or differently do groups of intervenors talk about whether internet should be a basic service  
** e.g. Fig. 3.4 and 4.1 in [tidy textmining](https://www.tidytextmining.com/ngrams.html)
** visualization showing a range of words that organizations choose and how frequently they are used  
** are there subgroups of intervenors and the language they use when discussing whether internet should be a basic service  
** consider using individual words as well as bigrams  

* are there differences in how individual intervenors talk about whether internet should be a basic service  
** e.g. Fig. 3.4 and 4.1 in [tidy textmining](https://www.tidytextmining.com/ngrams.html)

* what is the overall sentiment of the intervenor groups  
** e.g. Fig. 2.4 in [tidy textmining](https://www.tidytextmining.com/ngrams.html) or "Which words had the most effect on sentiment scores overall(Afinn)" in [Tatiana's doc](https://github.com/cybera/hey-cira/blob/neo4j/notebooks/Affordability.md) along with an actual sentiment score for each document for each category
** e.g. Sentiment cloud in [Tatiana's doc](https://github.com/cybera/hey-cira/blob/neo4j/notebooks/Affordability.md)
** are there differences in positivity and/or negativity in how the groups talk about internet as a basic service  
** are there differences in sentiment between individual submissions and submissions from organizations - use NRC dictionary  
** are there common keywords associated with statements of negative sentiment about internet as a basic service?  
** are there common keywords associated with statements of positive sentiment about internet as a basic service?  


C. Case studies 
e.g. for affordability, consider a quantitative analysis of the OpenMedia docs: 
* How affordable do individual intervenors think internet services should be? 
**  extract quantitative information on affordability from open media submissions
**  if possible, extract quantitative information on affordability from individual submissions as well
**  use postal codes to map positions across Canada? 

