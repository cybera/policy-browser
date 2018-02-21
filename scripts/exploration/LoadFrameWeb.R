
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
library(qdap)
library(tm)

# Note you need to run this as root 
relevance.affordability <- read.csv("doc2vec_advocacy_afford_filter_300.csv")



bigram_counts<-relevance.affordability %>%
  #mutate(bigram = paste(word1, word2)) %>%
#  mutate(max_relevance = pmax(relevance1, relevance2)) %>%
#  filter(max_relevance > 0.6) %>%
  mutate(word1=word1, word2=word2)# %>%
  #count(word1, word2, sort = TRUE) %>%
  #mutate(word1=stemCompletion(as.character(word1), scan_tokenizer(word1)), word2=stemCompletion(as.character(word2), scan_tokenizer(word2)))
  #count(bigram, sort=TRUE) %>%
  #bind_tf_idf(word1, Organization, n) %>%
  # arrange(desc(tf_idf)) %>%
 # mutate(bigram = factor(bigram, levels = rev(unique(bigram))))
print("DF")
corp1 = array(bigram_counts$word1)
corp2 = array(bigram_counts$word2)
corpus = Corpus(VectorSource(cbind(corp1, corp2)))
print("DFF")
bigram_counts <- bigram_counts %>%
  mutate(word1 = tolower(stemmer(word1)), word2 = tolower(stemmer(word2))) %>%
  count(word1, word2, sort=TRUE) #%>%
 # mutate(word1=stemCompletion(word1, dictionary=corpus), 
    #     word2=stemCompletion(word2, dictionary=corpus))


# I note that this is slow. Like, annoyingly slow. It's not so slow
# you can go home, but it's slow enough that you have enough time
# to start an existential crisis. 
bigram_counts <- bigram_counts %>% 
  mutate(word1=stemCompletion(word1, dictionary=corpus), 
        word2=stemCompletion(word2, dictionary=corpus))

bigram_counts


bigram_graph<-bigram_counts %>%
   # separate(bigram, c("word1" ,"word2"), sep=" ") %>%
   # count(word1, word2, sort=TRUE) %>%
   # unite("bigrm", c(word1, word2), sep=" ") %>% 
    filter(n >= 65) %>%
    graph_from_data_frame()




#set.seed(13423524)
ggraph(bigram_graph, layout = 'fr')+
	geom_edge_link(aes(edge_alpha=n), 
					         show.legend=FALSE,
                     end_cap = circle(0.03, 'inches')) +
	geom_node_point(color="lightblue", size=4) +
	geom_node_text(aes(label=name), repel=TRUE, size=2.1) +
  theme_void() + 
  ggtitle("Discussion of Affordability by Advocacy Groups")

ggsave("../hey-cira/notebooks/images/advocacy_doc2vec_afford_no_filter.png", height=5, width= 5)
