library(RNeo4j)
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

query = "MATCH (q:Query) WHERE q.str IN ['{!surround}content:3N(internet OR broadband,cost*)','{!surround}content:3N(services,cost*)',
'{!surround}content:3N(service,cost*)', '{!surround}content:5N(internet OR broadband OR service*,expensive)', '{!surround}content:5N(internet OR broadband OR service*,cheap*)', '{!surround}content:3N(internet OR broadband,price*)',
'{!surround}content:3N(service,price*)','{!surround}content:3N(services,price*)',
'{!surround}content:3N(internet OR broadband,afford*)',  '{!surround}content:3N(service,afford*)', '{!surround}content:3N(services,afford*)']
MATCH (q)<-[r1:MATCHES]-(s:Segment)
MATCH (s)-[r2:SEGMENT_OF]->(d:Document)
RETURN s.content as content, ID(s) as id, d.name as doc_name;"

data = cypher(graph, query)
#data_test
##clean data
data <- data[!duplicated(data$content),]

data$content <- lapply(data$content, function(x) gsub("\\n+", "", x))
data$content <- lapply(data$content, function(x) gsub("\\t", " ", x))
data$content <- lapply(data$content, function(x) gsub("\\s+"," ",x))
data$content <- unlist(data$content)

dim(data)
length(unique(data$doc_name))

data_test <- data %>% 
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
  filter(n() >= 300) %>%
  pairwise_cor(word, id, sort = TRUE, upper = FALSE)

data_word_pairs2

set.seed(1234)
data_word_pairs2 %>%
  filter(correlation >0.8) %>%
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
  anti_join(stop_words) %>%
  count(word) %>%
  with(wordcloud(word, n, max.words = 100))


data_test %>%
  inner_join(get_sentiments("bing")) %>%
  count(word, sentiment, sort = TRUE) %>%
  acast(word ~ sentiment, value.var = "n", fill = 0) %>%
  comparison.cloud(colors = c("#F8766D", "#00BFC4"),
                   max.words = 100)

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

data_full <- full_join(data, data_sentiments)  %>% 
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

