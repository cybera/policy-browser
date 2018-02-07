library(widyr)
library(ggplot2)
library(igraph)
library(ggraph)
library(tidytext)
library(magrittr)
library(dplyr)
library(RNeo4j)
library(stringr)
library(wordcloud)
library(reshape2)
library(tidyr)
library(SnowballC)

#Part 1 ACORN

graph = startGraph("http://localhost:7474/db/data/", username = "neo4j", password = "password")
query1 = "MATCH (n:Document{name: '2015-134.224035.2409354.Intervention(1fn2$01!).pdf' }) RETURN  n.sha256 AS sha256, n.content as content"
data1 = cypher(graph, query1)
query2 = "MATCH (n:Document{name: '2015-134.224035.2409353.Intervention(1fn2h01!).pdf' }) RETURN  n.sha256 AS sha256, n.content as content"
data2 = cypher(graph, query2)


data_doc <-paste(data1$content,data2$content)
result <- regmatches(data_doc,gregexpr("How do you feel about the current pricing of high-speed internet\\?(.*?)Which budget items have you taken money out of to pay for internet\\?",data_doc))
result <- lapply(result, function(x) gsub(".*How do you feel about the current pricing of high-speed internet\\?\\s*|Which budget items have you taken money out of to pay for internet\\?.*", "", x))
result <- lapply(result, function(x) gsub("\\n+", "", x))
result <- lapply(result, function(x) gsub("\\s+"," ",x))

result <- factor(unlist(result))
result_question <- as.data.frame(table(result))
result_question <- result_question[order(result_question$Freq, decreasing = TRUE),]

result <- regmatches(data_doc,gregexpr("Please share anything else relevant\\.(.*?)Name and City",data_doc))
result <- lapply(result, function(x) gsub(".*Please share anything else relevant\\.\\s*|Name and City.*", "", x))
result <- lapply(result, function(x) gsub("\\n+", "", x))
result <- lapply(result, function(x) gsub("\\s+"," ",x))
result <- unlist(result)

result_comment <-  as.data.frame(result[result != ""]) 
colnames(result_comment) <- "content"
result_comment <- dplyr::mutate(result_comment, id = as.integer(rownames(result_comment)))


##clean data

data_test <- result_comment %>% 
  unnest_tokens(word, content) %>% 
  anti_join(stop_words)

my_stopwords <- data_frame(word = c(as.character(1:10), 
                                    "1", "2", "100","25", "0", "document", "2015"))
data_test <- data_test %>% 
  anti_join(my_stopwords)

data_test %>% 
  count(word, sort = TRUE)

data_word_pairs <- data_test %>% pairwise_count(word, id,sort = TRUE, upper = FALSE)
data_word_pairs

set.seed(1234)
data_word_pairs %>%
  filter(n >= 9) %>%
  graph_from_data_frame() %>%
  ggraph(layout = "fr") +
  geom_edge_link(aes(edge_alpha = n, edge_width = n), edge_colour = "darkred") +
  geom_node_point(size = 5) +
  geom_node_text(aes(label = name), repel = TRUE,
                 point.padding = unit(0.2, "lines")) +
  theme_void()


sentiment <- data_test %>%
  inner_join(get_sentiments("afinn"), by = "word") %>%
  group_by(word) %>%
  summarize(occurences = n(),
            contribution = sum(score))


sentiment %>%
  top_n(25, abs(contribution)) %>%
  mutate(word = reorder(word, contribution)) %>%
  ggplot(aes(word, contribution, fill = contribution > 0)) +
  geom_col(show.legend = FALSE) +
  coord_flip()


data_test %>%
  anti_join(stop_words) %>%
  count(word) %>%
  with(wordcloud(word, n, max.words = 100))


data_test %>%
  inner_join(get_sentiments("bing")) %>%
  count(word, sentiment, sort = TRUE) %>%
  acast(word ~ sentiment, value.var = "n", fill = 0) %>%
  comparison.cloud(colors = c("#F8766D", "#00BFC4"),
                   max.words = 100)

##Part2 the rest of the documents

graph = startGraph("http://localhost:7474/db/data/", username = "neo4j", password = "password")


query = "MATCH (q:Query) WHERE q.str IN [
'content:\"internet, expensive\"~10 OR content:\"broadband, expensive\"~10 OR content:\"services, expensive\"~10 OR content:\"service, expensive\"~10',
'content:\"internet, cheap\"~10 OR content:\"broadband, cheap\"~10 OR content:\"services, cheap\"~10 OR content:\"service, cheap\"~10',
'content:\"internet, affordable\"~10 OR content:\"broadband, affordable\"~10 OR content:\"services, affordable\"~10 OR content:\"service, affordable\"~10', 
'content:\"internet, affordability\"~10 OR content:\"broadband, affordability\"~10 OR content:\"services, affordability\"~10 OR content:\"service, affordability\"~10', 
'content:\"internet, cost\"~10 OR content:\"broadband, cost\"~10 OR content:\"services, cost\"~10 OR content:\"service, cost\"~10', 
'content:\"internet, price\"~10 OR content:\"broadband, price\"~10 OR content:\"services, price\"~10 OR content:\"service, price']
MATCH (q)<-[r1:MATCHES]-(s:Segment)
MATCH (s)-[r2:SEGMENT_OF]->(d:Document)
OPTIONAL MATCH (d)<-[r3:SUBMITTED]-(o:Organization)
RETURN s.content as content, ID(s) as id, d.name as doc_name, d.sha256 as doc_sha256, o.name as organization_name, o.category as organization_category;"

data_q = cypher(graph, query)

###Stats

dim(data_q) #3208
data_q <- data_q[!duplicated(data_q[c(1,3)]),]

dim(data_q) #2627

data_org <- data_q[c("doc_name","organization_name","organization_category")]
data_org <- data_org[!duplicated(data_org$doc_name),]

dim(data_org) #699

sum(!is.na(data_org$organization_name)) #415
data_org <- data_org[!is.na(data_org$organization_name),]

dim(data_org) #415

sum(!is.na(data_org$organization_category)) #414

result_data_org <-data.frame(table(data_org$organization_name))
result_data_cat <-data.frame(table(data_org$organization_category))

query_all = "MATCH(d:Document)
OPTIONAL MATCH (d)<-[r:SUBMITTED]-(o:Organization)
RETURN  d.name as doc_name, o.name as organization_name, o.category as organization_category;"

data_all = cypher(graph, query_all)
dim(data_all) # 2575

data_all[data_all$doc_name=="2015-134.223977.2614295.Final Submission (1k17b01!).pdf",]
data_all[data_all$doc_name=="2015-134.100001.1000001.O2017-95.html",]
sum(!is.na(data_all$organization_name)) #1676

data_all <- data_all[!is.na(data_all$organization_name),] #1665
data_all <- data_all[!duplicated(data_all[c(1)]),]

sum(!is.na(data_all$organization_category)) #1331

cat_present <-data_all[!is.na(data_all$organization_category),]

cat_missing <- data_all[is.na(data_all$organization_category),]

present_org <-data.frame(table(cat_present$organization_name)) #117
missing_org <-data.frame(table(cat_missing$organization_name)) #58
all_org <- data.frame(table(data_all$organization_name)) #175

dim(data_all) #[1] 1335    3

result_data_org_all <-data.frame(table(data_all$organization_name))
result_data_cat_all <-data.frame(table(data_all$organization_category))

dim(result_data_org_all) #175 

dim(result_data_cat_all) # 9 


##preprocessing

my_stopwords <- data_frame(word = c(as.character(1:10), 
                                    "1", "2", "100","25", "0", "document", "2015","134","14", "2011", "2013", "2014"))

data_q$content <- lapply(data_q$content, function(x) gsub("\\n+", "", x))
data_q$content <- lapply(data_q$content, function(x) gsub("\\t", " ", x))
data_q$content <- lapply(data_q$content, function(x) gsub("\\s+"," ",x))
data_q$content <- unlist(data_q$content)

data_test <- data_q %>% 
  unnest_tokens(word, content) %>% 
  anti_join(stop_words)  %>%
  anti_join(my_stopwords)
#  %>% mutate(word = wordStem(word))

### Sentiment all together comparing different dictionaries

sentiment_afinn <- data_test %>% 
  inner_join(get_sentiments("afinn")) %>% 
  group_by(id) %>% 
  summarise(score_afinn = sum(score)) %>%
  ungroup()

sentiment_bing <- data_test %>% 
  inner_join(get_sentiments("bing")) %>% 
  count(id, sentiment) %>%
  spread(sentiment, n, fill=0) %>%
  mutate(score_bing = positive - negative) %>%
  select(-positive, -negative) %>%
  ungroup()

sentiment_nrc <- data_test %>% 
  inner_join(get_sentiments("nrc")) %>% 
  count(id, sentiment) %>%
  spread(sentiment, n, fill=0) %>%
  setNames(c(names(.)[1],paste0('nrc_', names(.)[-1]))) %>%
  mutate(score_nrc = nrc_positive - nrc_negative) %>%
  ungroup()

data_sentiments <- Reduce(full_join,
                          list(sentiment_nrc, sentiment_bing, sentiment_afinn)) %>% 
  mutate_each(funs(replace(., which(is.na(.)), 0)))

data_full <- full_join(data_q, data_sentiments)  %>% 
  mutate_each(funs(replace(., which(is.na(.)), 0)), starts_with("score"), starts_with("nrc"))


data_full %>%
  top_n(1, score_bing) %>%
  select(id, score_bing, content, doc_name) 

data_full %>%
  top_n(1, score_afinn) %>%
  select(id, score_afinn, content, doc_name)

data_full %>%
  top_n(1, score_nrc) %>%
  select(id, score_nrc, content, doc_name) 

data_full %>%
  top_n(-1, score_bing) %>%
  select(id, score_bing, content, doc_name) 

data_full %>%
  top_n(-1, score_afinn) %>%
  select(id, score_afinn, content, doc_name) 

data_full %>%
  top_n(-1, score_nrc) %>%
  select(id, score_nrc, content, doc_name) 

counts <- table(data_full$score_nrc)
barplot(counts, main="NRC scores", 
        col="darkblue")

counts <- table(data_full$score_afinn)
barplot(counts, main="Afinn scores", 
        col="darkred")

counts <- table(data_full$score_bing)
barplot(counts, main="Bing scores", 
        col="darkgreen")

slices <- c(sum(data_full$score_nrc>0),sum(data_full$score_nrc<0),sum(data_full$score_nrc==0))
lbls <- c("positive", "negative", "neutral")
pie(slices, labels = lbls, main="Score_nrc")

slices <- c(sum(data_full$score_bing>0),sum(data_full$score_bing<0),sum(data_full$score_bing==0))
lbls <- c("positive", "negative", "neutral")
pie(slices, labels = lbls, main="Score_bing")

slices <- c(sum(data_full$score_afinn>0),sum(data_full$score_afinn<0),sum(data_full$score_afinn==0))
lbls <- c("positive", "negative", "neutral")
pie(slices, labels = lbls, main="Score_afinn")


### Summary stats

data_test %>% 
  count(word, sort = TRUE)

data_word_pairs <- data_test %>% 
  pairwise_count(word, id,sort = TRUE, upper = FALSE)
data_word_pairs

set.seed(1234)
data_word_pairs %>%
  filter(n >= 500) %>%
  graph_from_data_frame() %>%
  ggraph(layout = "fr") +
  geom_edge_link(aes(edge_alpha = n, edge_width = n), edge_colour = "darkred") +
  geom_node_point(size = 5) +
  geom_node_text(aes(label = name), repel = TRUE,
                 point.padding = unit(0.2, "lines")) +
  theme_void()


data_word_pairs2 <- data_test %>% 
  group_by(word) %>%
  filter(n() >= 250) %>%
  pairwise_cor(word, id, sort = TRUE, upper = FALSE)

data_word_pairs2

set.seed(1234)
data_word_pairs2 %>%
  filter(correlation >0.5) %>%
  graph_from_data_frame() %>%
  ggraph(layout = "fr") +
  geom_edge_link(aes(edge_alpha = correlation, edge_width = correlation)) +
  geom_node_point(size = 5,color = "lightblue") +
  geom_node_text(aes(label = name), repel = TRUE) +
  theme_void()

## sentiment

sentiment <- data_test %>%
  inner_join(get_sentiments("afinn"), by = "word") %>%
  group_by(word) %>%
  summarize(occurences = n(),
            contribution = sum(score))

sentiment %>%
  top_n(25, abs(contribution)) %>%
  mutate(word = reorder(word, contribution)) %>%
  ggplot(aes(word, contribution, fill = contribution > 0)) +
  geom_col(show.legend = FALSE) +
  coord_flip()


data_test %>%
  count(word) %>%
  with(wordcloud(word, n, max.words = 100))


data_test %>%
  inner_join(get_sentiments("bing")) %>%
  count(word, sentiment, sort = TRUE) %>%
  acast(word ~ sentiment, value.var = "n", fill = 0) %>%
  comparison.cloud(colors = c("#F8766D", "#00BFC4"),
                   max.words = 100)

sentiment_messages <- data_test %>%
  inner_join(get_sentiments("afinn"), by = "word") %>%
  group_by(organization_category, id) %>%
  summarize(sentiment = mean(score),
            words = n()) %>%
  ungroup() %>%
  filter(words >= 5)

sentiment_messages %>%
  arrange(desc(sentiment))

sentiment_messages %>%
  arrange(sentiment)

data_bigrams <- data_org %>%
  unnest_tokens(bigram, content, token = "ngrams", n = 2)

data_bigram_counts <- data_bigrams %>%
  count(organization_category, bigram, sort = TRUE) %>%
  ungroup() %>%
  separate(bigram, c("word1", "word2"), sep = " ")

negate_words <- c("internet", "cost", "price", "affordable", "expensive", "broadband", "affordability")
data_bigram_counts %>%
  filter(word1 %in% negate_words) %>%
  # filter(word1 %in% stop_words) %>%
  count(word1, word2, wt = n, sort = TRUE) %>%
  inner_join(get_sentiments("afinn"), by = c(word2 = "word")) %>%
  mutate(contribution = score * nn) %>%
  group_by(word1) %>%
  top_n(10, abs(contribution)) %>%
  ungroup() %>%
  mutate(word2 = reorder(paste(word2, word1, sep = "__"), contribution)) %>%
  ggplot(aes(word2, contribution, fill = contribution > 0)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ word1, scales = "free", nrow = 3) +
  scale_x_discrete(labels = function(x) gsub("__.+$", "", x)) +
  ylab("Sentiment score * # of occurrences") +
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  coord_flip()


### By category
data_org <- data_q[!is.na(data_q$organization_category),]

data_test <-data_test %>% 
  unnest_tokens(word, content) %>% 
  anti_join(stop_words)  %>%
  anti_join(my_stopwords) 
  #  %>% mutate(word = wordStem(word))
  
#  data_test <- data_test %>%
#  unnest_tokens(word, text) %>%
#  filter(str_detect(word, "[a-z']$")

data_test %>%
  group_by(organization_category) %>%
  summarize(docs = n_distinct(doc_name)) %>%
  ggplot(aes(organization_category, docs)) +
  geom_col() +
  coord_flip()

words_by_category <- data_test %>%
  count(organization_category, word, sort = TRUE) %>%
  ungroup()

tf_idf <- words_by_category %>%
  bind_tf_idf(word, organization_category, n) %>%
  arrange(desc(tf_idf))

tf_idf

tf_idf %>%
  group_by( organization_category) %>%
  top_n(5, tf_idf) %>%
  ungroup() %>%
  mutate(word = reorder(word, tf_idf)) %>%
  ggplot(aes(word, tf_idf, fill =  organization_category)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~organization_category, scales = "free") +
  ylab("tf-idf") +
  coord_flip()

data_cors <- words_by_category %>%
  pairwise_cor(organization_category, word, n, sort = TRUE)

data_cors
set.seed(1234)
data_cors %>%
  filter(correlation > .8) %>%
  graph_from_data_frame() %>%
  ggraph(layout = "fr") +
  geom_edge_link(aes(alpha = correlation, width = correlation)) +
  geom_node_point(size = 6, color = "lightblue") +
  geom_node_text(aes(label = name), repel = TRUE) +
  theme_void()


# include only words that occur at least 50 times
data_categories <- data_test %>%
  group_by(word) %>%
  mutate(word_total = n()) %>%
  ungroup() %>%
  filter(word_total > 50)

# convert into a document-term matrix
test_dtm <- data_categories %>%
  unite(document, organization_category, doc_name) %>%
  count(document, word) %>%
  cast_dtm(document, word, n)

library(topicmodels)
test_lda <- LDA(test_dtm, k = 4, control = list(seed = 2016))

test_lda %>%
  tidy() %>%
  group_by(topic) %>%
  top_n(8, beta) %>%
  ungroup() %>%
  mutate(term = reorder(term, beta)) %>%
  ggplot(aes(term, beta, fill = factor(topic))) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free_y") +
  coord_flip()

test_lda %>%
  tidy(matrix = "gamma") %>%
  separate(document, c("organization_category", "doc_name"), sep = "_") %>%
  mutate(organization_category = reorder(organization_category, gamma * topic)) %>%
  ggplot(aes(factor(topic), gamma)) +
  geom_boxplot() +
  facet_wrap(~ organization_category) +
  labs(x = "Topic",
       y = "# of messages where this was the highest % topic")

category_sentiments <- words_by_category %>%
  inner_join(get_sentiments("afinn"), by = "word") %>%
  group_by(organization_category) %>%
  summarize(score = sum(score * n) / sum(n))

category_sentiments %>%
  mutate(organization_category = reorder(organization_category, score)) %>%
  ggplot(aes(organization_category, score, fill = score > 0)) +
  geom_col(show.legend = FALSE) +
  coord_flip() +
  ylab("Average sentiment score")

top_sentiment_words <- words_by_category %>%
  inner_join(get_sentiments("afinn"), by = "word") %>%
  mutate(contribution = score * n / sum(n))

top_sentiment_words

top_sentiment_words %>%
  group_by(organization_category) %>%
  top_n(8, abs(contribution)) %>%
  mutate(word = reorder(word, contribution)) %>%
  ggplot(aes(word, contribution, fill = contribution > 0)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ organization_category, scales = "free_y") +
  coord_flip()

