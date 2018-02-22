# setwd to the project root
library(widyr)
library(ggplot2)
library(tidytext)
library(magrittr)
library(dplyr)
library(RNeo4j)
library(stringr)
library(reshape2)
library(tidyr)
#library(SnowballC)

source("scripts/exploration/neo4j.R")

#solr without organizations
query_s1 ="MATCH (qe:Question{ref:\"Q1\"})
MATCH (q:Query)-[:ABOUT{method:\"solr\"}]->(qe)
MATCH (q)<-[:MATCHES]-(s:Segment)
MATCH (s)-[:SEGMENT_OF]->(d:Document)
WHERE NOT (d)<-[:SUBMITTED]->() AND d.type<>'subdoc'
RETURN  s.content as content, d.name as doc_name"
data_s1 = cypher(graph, query_s1)
dim(data_s1)# 1350
data_s1 <- data_s1[!duplicated(data_s1[c(1,2)]),]
dim(data_s1)# 1290
data_s1$organization_name <- "None"
data_s1$organization_category <- "None"

#solr with organization
query_s2 ="MATCH (qe:Question{ref:\"Q1\"})
MATCH (q:Query)-[:ABOUT{method:\"solr\"}]->(qe)
MATCH (q)<-[:MATCHES]-(s:Segment)
MATCH (s)-[:SEGMENT_OF]->(d:Document)
MATCH (o:Organization)<-[:ALIAS_OF*0..1]-()-[:SUBMITTED]->(d)
WHERE NOT (o)-[:ALIAS_OF]->()
RETURN  s.content as content, d.name as doc_name, o.name as organization_name, o.category as organization_category;"
data_s2 = cypher(graph, query_s2)
dim(data_s2) #3150
data_s2 <- data_s2[!duplicated(data_s2[c(1,2)]),]
dim(data_s2) #2337
data_s <- rbind(data_s1, data_s2)
data_org <- data_s[c("doc_name","organization_name","organization_category")]
data_org <- data_org[!duplicated(data_org$doc_name),]
dim(data_org) #797 all together
data.frame(table(data_org$organization_category))

###doc2vec without Organization
query_d1 = "MATCH (qe:Question{ref:\"Q1\"})
MATCH (q:Query)-[r:ABOUT]->(qe) WHERE r.method = 'doc2vec-MonteCarlo'
MATCH (q)<-[r1:MATCHES]-(s:Segment)
MATCH (s)-[r2:SEGMENT_OF]->(d:Document)
WHERE NOT (d)<-[:SUBMITTED]->() AND d.type<>'subdoc'
RETURN  s.content as content, d.name as doc_name"
data_d1 = cypher(graph, query_d1)
dim(data_d1)# 2787
data_d1 <- data_d1[!duplicated(data_d1[c(1,2)]),]
dim(data_d1)# 2775 
data_d1$organization_name <- "None"
data_d1$organization_category <- "None"

#doc2vec with organization
query_d2 ="MATCH (qe:Question{ref:\"Q1\"})
MATCH (q:Query)-[r:ABOUT]->(qe) WHERE r.method = 'doc2vec-MonteCarlo'
MATCH (q)<-[:MATCHES]-(s:Segment)
MATCH (s)-[:SEGMENT_OF]->(d:Document)
MATCH (o:Organization)<-[:ALIAS_OF*0..1]-()-[:SUBMITTED]->(d)
WHERE NOT (o)-[:ALIAS_OF]->()
RETURN  s.content as content, d.name as doc_name, o.name as organization_name, o.category as organization_category;"
data_d2 = cypher(graph, query_d2)
dim(data_d2) #9839
data_d2 <- data_d2[!duplicated(data_d2[c(1,2)]),]
dim(data_d2) #7578
data_d <- rbind(data_d1, data_d2)
data_org <- data_d[c("doc_name","organization_name","organization_category")]
data_org <- data_org[!duplicated(data_org$doc_name),]
dim(data_org) #987 alltogether
data.frame(table(data_org$organization_category))


##preprocessing
data_aff <- rbind(data_s, data_d)
dim(data_aff) #13980 
data_aff$organization_category <- as.factor(data_aff$organization_category)
#my_stopwords <- data_frame(word = c(as.character(1:10), 
#                                    "1", "2", "100","25", "0", "document", "2015","134","14", "2011", "2013", "2014"))
data_aff$content <- lapply(data_aff$content, function(x) gsub("\\n+ |\\t |\\s+", " ", x))
data_aff$content <- unlist(data_aff$content)

data_test <- data_aff %>% 
  unnest_tokens(word, content) %>% 
  anti_join(stop_words)  
  #anti_join(my_stopwords)
#  %>% mutate(word = wordStem(word))

# word counts
words_by_category <- data_test %>%
  group_by(organization_category) %>%
  count( word, sort = TRUE) %>%
  mutate(freq = round(n*100 / sum(n), digits=1)) %>%
  top_n(10,freq) %>%
  ungroup()
#Form result table
X <- split(words_by_category, words_by_category$organization_category)
result_word <- as.data.frame(paste(X[[1]]$word," ",X[[1]]$freq))
colnames(result_word) <-X[[1]]$organization_category[1]
result_word <- head(result_word,10)
for(i in c(2:length(X)))
{
  test <- as.data.frame(paste(X[[i]]$word," ",X[[i]]$freq))
  colnames(test) <-X[[i]]$organization_category[1]
  test <- head(test,10)
  result_word <-cbind(result_word,test)
}
result_word

# trigrams
trigram_by_category <- data_aff %>%
  group_by(organization_category) %>%
  unnest_tokens(trigram, content, token = "ngrams", n = 3) %>%
  separate(trigram, c("word1", "word2", "word3"), sep = " ") %>%
  filter(!word1 %in% stop_words$word,
         !word2 %in% stop_words$word,
         !word3 %in% stop_words$word) %>%
  count(word1, word2, word3, sort = TRUE)%>%
  mutate(freq = round(n*100 / sum(n), digits=1)) %>%
  top_n(10,freq) %>%
  ungroup()
#Form result table 
X <- split(trigram_by_category, trigram_by_category$organization_category)
result_trigram <- as.data.frame(paste(X[[1]]$word1," ",X[[1]]$word2," ",X[[1]]$word3," ",X[[1]]$freq,"%"))
colnames(result_trigram) <-X[[1]]$organization_category[1]
result_trigram <- head(result_trigram,10)
for(i in c(2:length(X)))
{
  test <-as.data.frame(paste(X[[i]]$word1," ",X[[i]]$word2," ",X[[i]]$word3," ",X[[i]]$freq,"%"))
  colnames(test) <-X[[i]]$organization_category[1]
  test <- head(test,10)
  result_trigram <-cbind(result_trigram,test)
}
result_trigram

### Most frequent sentiment words
words_by_category <- data_test %>%
  count(organization_category, word, sort = TRUE) %>%
  ungroup()

top_sentiment_words <- words_by_category %>%
  inner_join(get_sentiments("afinn"), by = "word") %>%
  mutate(contribution = score * n / sum(n))

top_sentiment_words %>%
  group_by(organization_category) %>%
  top_n(8, abs(contribution)) %>%
  mutate(word = reorder(word, contribution)) %>%
  ggplot(aes(word, contribution, fill = contribution > 0)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ organization_category, scales = "free_y") +
  coord_flip()

