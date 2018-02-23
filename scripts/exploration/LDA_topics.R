library(dplyr)
library(ggplot2)
library(topicmodels)
library(tidytext)
library(stringi)
library(magrittr)
library(tsne)
library(stringr)

#setwd("~/DS/policy-browser/data/processed")

docs <- read.csv("data_english.csv",fileEncoding="UTF-8", stringsAsFactors =F)
docs_fr <- read.csv("data_french.csv",fileEncoding="UTF-8", stringsAsFactors =F)
docs_fr <- docs_fr[,c(1,2,4)]
colnames(docs_fr) <- colnames(docs)
docs1 <- rbind(docs, docs_fr) 

my_stopwords <- data_frame(word = c(as.character(1:10),"nextgeneration", "nono","highw","hig","highh","highwayay", "http", "st", "https"))

data_test <- docs1[,c("sha256","content")]
data_test <- data_test %>% 
  unnest_tokens(word, content) %>% 
  anti_join(stop_words)  %>%
  anti_join(my_stopwords)

data_test <- data_test %>%
  filter(!str_detect(word, "\\b[[:alpha:]]{15,}\\b"),!str_detect(word, "[[:digit:]]+"))

#Select only words that appear more than 50 times
words50 <- data_test %>%
  group_by(word) %>%
  mutate(word_total = n()) %>%
  ungroup() %>%
  filter(word_total > 50)

dtm50 <- words50 %>%
  count(sha256, word) %>%
  cast_dtm(sha256, word, n)

modelsize=10
#modelsize=30
#modelsize=100

model <- LDA(dtm50, k = modelsize, control = list(seed = 1234))

doc_topics <- tidy(model, matrix = "beta")

top_terms <- doc_topics %>%
  group_by(topic) %>%
  top_n(10, beta) %>%
  ungroup() %>%
  arrange(topic, -beta)

top_terms %>%
  mutate(term = reorder(term, beta)) %>%
  ggplot(aes(term, beta, fill = factor(topic))) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free") +
  coord_flip()

#Visialization - maximum gamma
gamma_dtm <- tidy(model, matrix = "gamma")
max_per_doc = aggregate(gamma_dtm$gamma,by=list(gamma_dtm$document),max)

ggplot(data=max_per_doc,aes(x, fill=factor(modelsize))) +
  geom_histogram(bins = 20) +
  scale_fill_discrete(name = "Number of Topics") + 
  xlab("maximum gamma per document") +
  geom_vline(aes(xintercept = 1/modelsize),color="darkred") +
  labs(title = paste(modelsize," topics"))

####Topiclabels
dtm_terms <- as.data.frame(topicmodels::terms(model, 10), stringsAsFactors = FALSE)
topicTerms <- tidyr::gather(dtm_terms, Topic)
topicTerms <- cbind(topicTerms, Rank = rep(1:10))
topTerms <- dplyr::filter(topicTerms, Rank < 4)
topTerms <- dplyr::mutate(topTerms, Topic = stringr::word(Topic, 2))
topTerms$Topic <- as.numeric(topTerms$Topic)
topicLabel <- data.frame()
for (i in 1:modelsize){
  z <- dplyr::filter(topTerms, Topic == i)
  l <- as.data.frame(paste(z[1,2], z[2,2], z[3,2], sep = " " ), stringsAsFactors = FALSE)
  topicLabel <- rbind(topicLabel, l)
  
}
colnames(topicLabel) <- c("Label")

dtm_topics <- topicmodels::topics(model, 1)
doctopics.df <- as.data.frame(dtm_topics)
doctopics.df <- dplyr::transmute(doctopics.df, sha256 = as.character(rownames(doctopics.df)), Topic = dtm_topics)
docs1 <- rbind(docs, docs_fr)
docs1 <- dplyr::inner_join(docs1, doctopics.df, by = "sha256")

#Visualization - topics distribution
counts <- table(doctopics.df$Topic)
counts <- counts *100 / sum(counts)
head(sort(counts,decreasing = TRUE))
barplot(counts, main=paste(modelsize, " topics"), 
        col="darkblue")

#Create datasets
doc_topics <-docs1[,c("sha256","Topic")]
write.csv(doc_topics, file = "doc_topics.csv")

topics=as.data.frame(t(dtm_terms[1:5,]))
rownames(topics) <- NULL
topics$label=topicLabel$Label
write.csv(topics,file = "topics.csv")