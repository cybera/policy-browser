
library(RNeo4j)
library(dplyr)
library(tidytext)
library(widyr)
library(tidyverse)
library(ggplot2)
library(igraph)
library(ggraph)
library(tidyr)
library(text2vec)
library(data.table)
library(tm)
library(SnowballC)

# of your image file to root, so you may have to chown the file after

relevance.affordability <- read.csv("all_orgs_filter.csv")

# uncomment/comment max_relevance stuff to filter according to cosine similiarity 
bigram_counts<-relevance.affordability %>%
  mutate(max_relevance = pmax(relevance1, relevance2)) %>%
  filter(max_relevance > 0.6) %>%
  mutate(word1=word1, word2=word2)

  


# create a corpus to re-stem the words after the bigrams are counted using
# the stemmed form. 
corp1 = array(bigram_counts$word1)
corp2 = array(bigram_counts$word2)
corpus = Corpus(VectorSource(cbind(corp1, corp2)))

bigram_counts <- bigram_counts %>%
  mutate(word1 = tolower(wordStem(word1)), word2 = tolower(wordStem(word2))) %>%
  count(word1, word2, sort=TRUE) #%>%
bigram_counts

# this is slow so we filter before to do less work
bigram_counts <- bigram_counts %>% 
  filter(n >= 25) %>%
  mutate(word1=stemCompletion(word1, dictionary=corpus), 
        word2=stemCompletion(word2, dictionary=corpus))
bigram_counts


bigram_graph<-bigram_counts %>%
    graph_from_data_frame()


#set.seed(13423524)
ggraph(bigram_graph, layout = 'fr')+
	geom_edge_link(
    aes(edge_alpha=n), 
		show.legend=FALSE,
    end_cap = circle(0.03, 'inches')) +
	geom_node_point(color="lightblue", size=4) +
	geom_node_text(aes(label=name), repel=TRUE, size=2.1) +
  theme_void() + 
  ggtitle("Discussion of Affordability by All Groups")

ggsave("../hey-cira/notebooks/images/all_doc2vec_afford_filter.png", height=5, width= 5)
