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

####Summary stats

source("scripts/exploration/neo4j.R")
#Summary
#without organizations
query_sum1 ="MATCH (d:Document)
WHERE NOT (d)<-[:SUBMITTED]->() AND d.type<>'subdoc'
RETURN d.name as doc_name"
data_sum1 = cypher(graph, query_sum1)
dim(data_sum1) #1363
data_sum1$organization_name <- "None"
data_sum1$organization_category <- "None"

#Summary with organization
query_sum2 ="MATCH (d:Document)
MATCH (o:Organization)<-[:ALIAS_OF*0..1]-()-[:SUBMITTED]->(d)
WHERE NOT (o)-[:ALIAS_OF]->()
RETURN d.name as doc_name, o.name as organization_name, o.category as organization_category;"
data_sum2 = cypher(graph, query_sum2)
dim(data_sum2) 
data_sum <- rbind(data_sum1, data_sum2)
data_org <- data_sum[c("doc_name","organization_name","organization_category")]
data_org <- data_org[!duplicated(data_org$doc_name),]
dim(data_org) 
data.frame(table(data_org$organization_category))

#solr without organizations
query_s1 ="MATCH (qe:Question{ref:\"Q9-1\"})
MATCH (q:Query)-[:ABOUT{method:\"solr\"}]->(qe)
MATCH (q)<-[:MATCHES]-(s:Segment)
MATCH (s)-[:SEGMENT_OF]->(d:Document)
WHERE NOT (d)<-[:SUBMITTED]->() AND d.type<>'subdoc'
RETURN  s.content as content, d.name as doc_name"
data_s1 = cypher(graph, query_s1)
dim(data_s1)# 256
data_s1 <- data_s1[!duplicated(data_s1[c(1,2)]),]
dim(data_s1)# 256
data_s1$organization_name <- "None"
data_s1$organization_category <- "None"

#solr with organization
query_s2 ="MATCH (qe:Question{ref:\"Q9-1\"})
MATCH (q:Query)-[:ABOUT{method:\"solr\"}]->(qe)
MATCH (q)<-[:MATCHES]-(s:Segment)
MATCH (s)-[:SEGMENT_OF]->(d:Document)
MATCH (o:Organization)<-[:ALIAS_OF*0..1]-()-[:SUBMITTED]->(d)
WHERE NOT (o)-[:ALIAS_OF]->()
RETURN  s.content as content, d.name as doc_name, o.name as organization_name, o.category as organization_category;"
data_s2 = cypher(graph, query_s2)
dim(data_s2) #641
data_s2 <- data_s2[!duplicated(data_s2[c(1,2)]),]
dim(data_s2) #498
data_s <- rbind(data_s1, data_s2)
data_org <- data_s[c("doc_name","organization_name","organization_category")]
data_org <- data_org[!duplicated(data_org$doc_name),]
dim(data_org) #276 all together
data.frame(table(data_org$organization_category))