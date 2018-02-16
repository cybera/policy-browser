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
library(textcat)
library(proustr)
library(readtext)

graph = startGraph("http://localhost:7474/db/data/", username = "neo4j", password = "password")

##OpenMedia
##All OpenMedia Submissions
query_all_OM = "MATCH (d:Document{type:\"subdoc\"}) return d.sha256 as sha256, d.name as name, d.content as content"
data_all_OM = cypher(graph, query_all_OM )
dim(data_all_OM) #20281 

##Unique OpenMedia Submissions
query_OM = "MATCH (d:Document { sha256:'996cdc9c830fc7f76fd8dae382916fd38906e776d092363ac0f5fbcd679a9ad0'})<--(subdoc:Document)<--(p:Person)
RETURN p.name AS person, p.location AS location, p.postal AS postal_code, subdoc.content AS content, subdoc.sha256 as sha256"
data_om = cypher(graph, query_OM)
dim(data_om) #2427

data_om$content <- lapply(data_om$content, function(x) gsub("\\n+ |\\t |\\s+", " ", x))
data_om$content <- sub("I acknowledge that my comments.*", "",data_om$content)
data_om$content <- sub("\\[Insert your comment here\\]", "",data_om$content)
data_om$content <- unlist(data_om$content)
write.csv(data_om,"data_om.csv")

###ACORN
#setwd("~/DS/hey-cira/data/raw")
#filename1 = "2015-134.224035.2409354.Intervention(1fn2$01!).pdf"
#filename2 = "2015-134.224035.2409353.Intervention(1fn2h01!).pdf"
#doc1 <- readtext(filename1, encoding="UTF-8")
#doc2 <- readtext(filename2, encoding="UTF-8")
#acorn_content <- paste(doc1$text,doc2$text)
#acorn_content <- paste(acorn_content,collapse=" ") 
query_acorn = "MATCH (d:Document) where d.name IN ['2015-134.224035.2409354.Intervention(1fn2$01!).pdf','2015-134.224035.2409353.Intervention(1fn2h01!).pdf'] 
RETURN  d.sha256 AS sha256, d.content AS content"
data_acorn = cypher(graph, query_acorn)
acorn_content <- paste(data_acorn$content[1],data_acorn$content[2])

###Individual html submissions 
query_html= "MATCH path=(:Person)-[]-(p:Participant)-[]-(:Submission)-[]-(d:Document{type:\"html\"})
WHERE NOT (:Organization)-[]-(p)
RETURN d.content as content, d.sha256 as sha256, d.translated as translated"
data_html = cypher(graph, query_html) #dim 266
data_html <- data_html[!data_html$content== "Copie envoyée au demandeur et à tout autre intimé si applicable / Copy sent to applicant and to any respondent if applicable: Non/No",]
data_html_english <- data_html[is.na(data_html$translated),] #dim 239
data_html_french <- data_html[!is.na(data_html$translated),] #dim 27
data_html_french <-data_html_french[,c("sha256","translated")]
data_html_english <-data_html_english[,c("sha256","content")]
colnames(data_html_french) <- colnames(data_html_english)
data_html <- rbind(data_html_french, data_html_english) 
#Some cleaning
data_html$content <- gsub('\u009c|\u00F0',' ',data_html$content)
data_html$content <- gsub('Raisons pour comparaitre / Reasons for appearance', ' ',data_html$content)

##Question about pricing (ACORN)
acorn_pricing <- regmatches(acorn_content,gregexpr("How do you feel about the current pricing of high-speed internet\\?(.*?)Which budget items have you taken money out of to pay for internet\\?",acorn_content))
acorn_pricing <- lapply(acorn_pricing, function(x) gsub(".*How do you feel about the current pricing of high-speed internet\\?\\s*|Which budget items have you taken money out of to pay for internet\\?.*", "", x))
acorn_pricing <- lapply(acorn_pricing, function(x) gsub("\\n+ |\\s+", " ", x))
acorn_pricing <- factor(unlist(acorn_pricing))
length(acorn_pricing) #289
acorn_pricing <- as.data.frame(table(acorn_pricing))
acorn_pricing <- acorn_pricing[order(acorn_pricing$Freq, decreasing = TRUE),]

##Other comments
acorn_comment1 <- regmatches(acorn_content,gregexpr("Please share anything else relevant\\.(.*?)Name and City",acorn_content))
acorn_comment1 <- lapply(acorn_comment1, function(x) gsub(".*Please share anything else relevant\\.\\s*|Name and City.*", "", x))

acorn_comment2 <- regmatches(acorn_content,gregexpr("Why is online access important to you\\?(.*?)3. How do you feel about the current pricing of high-speed internet\\?",acorn_content))
acorn_comment2 <- lapply(acorn_comment2, function(x) gsub(".*Why is online access important to you\\?\\s*|3. How do you feel about the current pricing of high-speed internet\\?.*", "", x))

acorn_comment3 <- regmatches(acorn_content,gregexpr("Please share how your life would change if you could easily afford home high-speed Internet\\.(.*?)5. Please share anything else relevant\\.",acorn_content))
acorn_comment3 <- lapply(acorn_comment3, function(x) gsub(".*Please share how your life would change if you could easily afford home high-speed Internet\\.\\s*|5. Please share anything else relevant\\..*", "", x))

acorn_comment <- c(acorn_comment1, acorn_comment2,acorn_comment3)
acorn_comment <- unlist(acorn_comment)
acorn_comment <- gsub("\\n+ |\\s+", " ", acorn_comment)
acorn_comment <-  as.data.frame(acorn_comment[acorn_comment != ""])
dim(acorn_comment) #150
colnames(acorn_comment) <- "content"
acorn_comment <- dplyr::mutate(acorn_comment, id = as.integer(rownames(acorn_comment)))

#########################Comparing data_om, acorn_comment and html submissions

##Word count
my_stopwords <- data_frame(word = c(as.character(1:10),"canada","service","canadians", "canadian", "services"))

result_om <- data_om[,c("sha256","content")] %>% 
  unnest_tokens(word, content) %>% 
  anti_join(stop_words)  %>%
  anti_join(my_stopwords)

counts_om <- result_om %>%
  count(word, sort = TRUE)

counts_om$n <- counts_om$n*100/sum(counts_om$n)

my_stopwords_acorn <- data_frame(word = c(as.character(1:10),"ons","ng","de","communica","informa", "es","er","ac","essen","al","ma", "li", "le", "ons","er", "opprtuni", "necessi","es","inter","net","ci","zens","ge","ng","ac","vi", "par", "cipate","recrea","onal","cri","cal"))
result_acorn <- acorn_comment%>% 
  unnest_tokens(word, content) %>% 
  anti_join(stop_words)  %>%
  anti_join(my_stopwords) %>%
  anti_join(my_stopwords_acorn) %>%
  anti_join(proustr::proust_stopwords()) #for french data

counts_acorn <- result_acorn %>%
  count(word, sort = TRUE) 

counts_acorn$n <- counts_acorn$n*100/sum(counts_acorn$n)

result_html <- data_html%>% 
  unnest_tokens(word, content) %>% 
  anti_join(stop_words)  %>%
  anti_join(my_stopwords)

counts_html <- result_html %>%
  count(word, sort = TRUE)

counts_html$n <- counts_html$n*100/sum(counts_html$n)

##Bigrams
bigram_counts_om <- data_om[,c("sha256","content")] %>%
  unnest_tokens(bigram, content, token = "ngrams", n = 2)%>%
  separate(bigram, c("word1", "word2"), sep = " ")%>%
  filter(!word1 %in% stop_words$word) %>%
  filter(!word2 %in% stop_words$word) %>% 
  count(word1, word2, sort = TRUE)

bigram_counts_om2 <- bigram_counts_om
bigram_counts_om2$n <- bigram_counts_om$n*100/sum(bigram_counts_om$n)

bigram_graph_om <- bigram_counts_om %>%
  filter(n > 20) %>%
  graph_from_data_frame()

set.seed(1234)
ggraph(bigram_graph_om, layout = "fr") +
  geom_edge_link() +
  geom_node_point() +
  geom_node_text(aes(label = name), vjust = 1, hjust = 1)


bigram_counts_acorn <- acorn_comment %>%
  unnest_tokens(bigram, content, token = "ngrams", n = 2)%>%
  separate(bigram, c("word1", "word2"), sep = " ")%>%
  filter(!word1 %in% stop_words$word) %>%
  filter(!word2 %in% stop_words$word) %>% 
  filter(!word1 %in% my_stopwords_acorn$word) %>%
  filter(!word2 %in% my_stopwords_acorn$word) %>% 
  filter(!word1 %in% proustr::proust_stopwords()$word) %>%
  filter(!word2 %in% proustr::proust_stopwords()$word) %>% 
  count(word1, word2, sort = TRUE)

bigram_counts_acorn2<- bigram_counts_acorn
bigram_counts_acorn2$n <- bigram_counts_acorn$n*100/sum(bigram_counts_acorn$n)

bigram_graph_acorn <- bigram_counts_acorn%>%
  filter(n > 3) %>%
  graph_from_data_frame()

set.seed(4321)
ggraph(bigram_graph_acorn, layout = "fr") +
  geom_edge_link() +
  geom_node_point() +
  geom_node_text(aes(label = name), vjust = 1, hjust = 1)


bigram_counts_html <- data_html%>%
  unnest_tokens(bigram, content, token = "ngrams", n = 2)%>%
  separate(bigram, c("word1", "word2"), sep = " ")%>%
  filter(!word1 %in% stop_words$word) %>%
  filter(!word2 %in% stop_words$word) %>% 
  count(word1, word2, sort = TRUE)

bigram_counts_html2 <- bigram_counts_html
bigram_counts_html2$n <- bigram_counts_html$n*100/sum(bigram_counts_html$n)

bigram_graph_html <- bigram_counts_html %>%
  filter(n > 5) %>%
  graph_from_data_frame()

set.seed(1234)
ggraph(bigram_graph_html, layout = "fr") +
  geom_edge_link() +
  geom_node_point() +
  geom_node_text(aes(label = name), vjust = 1, hjust = 1)

##############

trigram_om <- data_om[,c("sha256","content")] %>%
  unnest_tokens(trigram, content, token = "ngrams", n = 3) %>%
  separate(trigram, c("word1", "word2", "word3"), sep = " ") %>%
  filter(!word1 %in% stop_words$word,
         !word2 %in% stop_words$word,
         !word3 %in% stop_words$word) %>%
  count(word1, word2, word3, sort = TRUE)

trigram_om$n <- trigram_om$n*100/sum(trigram_om$n)

trigram_acorn <- acorn_comment %>%
  unnest_tokens(trigram, content, token = "ngrams", n = 3) %>%
  separate(trigram, c("word1", "word2", "word3"), sep = " ") %>%
  filter(!word1 %in% stop_words$word,
         !word2 %in% stop_words$word,
         !word3 %in% stop_words$word) %>%
  filter(!word1 %in% my_stopwords_acorn$word,
         !word2 %in% my_stopwords_acorn$word,
         !word3 %in% my_stopwords_acorn$word) %>%
  filter(!word1 %in% proustr::proust_stopwords()$word,
         !word2 %in% proustr::proust_stopwords()$word,
         !word3 %in% proustr::proust_stopwords()$word) %>%
  count(word1, word2, word3, sort = TRUE)

trigram_acorn$n <- trigram_acorn$n*100/sum(trigram_acorn$n)

trigram_html <- data_html %>%
  unnest_tokens(trigram, content, token = "ngrams", n = 3) %>%
  separate(trigram, c("word1", "word2", "word3"), sep = " ") %>%
  filter(!word1 %in% stop_words$word,
         !word2 %in% stop_words$word,
         !word3 %in% stop_words$word) %>%
  count(word1, word2, word3, sort = TRUE)

trigram_html$n <- trigram_html$n*100/sum(trigram_html$n)

################ Topic modelling
words50_om <- result_om %>%
  group_by(word) %>%
  mutate(word_total = n()) %>%
  ungroup() %>%
  filter(word_total > 50)

dtm_om <- words50_om %>%
  count(sha256, word) %>%
  cast_dtm(sha256, word, n)

lda_om <- LDA(dtm_om, k = 5, control = list(seed = 1234))

lda_om %>%
  tidy() %>%
  group_by(topic) %>%
  top_n(8, beta) %>%
  ungroup() %>%
  mutate(term = reorder(term, beta)) %>%
  ggplot(aes(term, beta, fill = factor(topic))) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free_y") +
  coord_flip()

words50_acorn <- result_acorn %>%
  group_by(word) %>%
  mutate(word_total = n()) %>%
  ungroup()

dtm_acorn <- words50_acorn %>%
  count(id, word) %>%
  cast_dtm(id, word, n)

lda_acorn <- LDA(dtm_acorn, k = 5, control = list(seed = 1234))

lda_acorn %>%
  tidy() %>%
  group_by(topic) %>%
  top_n(8, beta) %>%
  ungroup() %>%
  mutate(term = reorder(term, beta)) %>%
  ggplot(aes(term, beta, fill = factor(topic))) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free_y") +
  coord_flip()

words50_html <- result_html %>%
  group_by(word) %>%
  mutate(word_total = n()) %>%
  ungroup() 

dtm_html <- words50_html %>%
  count(sha256, word) %>%
  cast_dtm(sha256, word, n)

lda_html <- LDA(dtm_html, k = 5, control = list(seed = 1234))

lda_html %>%
  tidy() %>%
  group_by(topic) %>%
  top_n(8, beta) %>%
  ungroup() %>%
  mutate(term = reorder(term, beta)) %>%
  ggplot(aes(term, beta, fill = factor(topic))) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free_y") +
  coord_flip()

####################- Sentiment cloud - have not included it
set.seed(1234)
result_om %>%
  inner_join(get_sentiments("bing")) %>%
  count(word, sentiment, sort = TRUE) %>%
  acast(word ~ sentiment, value.var = "n", fill = 0) %>%
  comparison.cloud(colors = c("#F8766D", "#00BFC4"),
                   max.words = 100)

result_acorn  %>%
  inner_join(get_sentiments("bing")) %>%
  count(word, sentiment, sort = TRUE) %>%
  acast(word ~ sentiment, value.var = "n", fill = 0) %>%
  comparison.cloud(colors = c("#F8766D", "#00BFC4"),
                   max.words = 100)

result_html  %>%
  inner_join(get_sentiments("bing")) %>%
  count(word, sentiment, sort = TRUE) %>%
  acast(word ~ sentiment, value.var = "n", fill = 0) %>%
  comparison.cloud(colors = c("#F8766D", "#00BFC4"),
                   max.words = 100)

####### Most frequent positive/negative words
contributions_om <- result_om %>%
  inner_join(get_sentiments("afinn"), by = "word") %>%
  group_by(word) %>%
  summarize(occurences = n(),
            contribution = sum(score))
contributions_om %>%
  top_n(25, abs(contribution)) %>%
  mutate(word = reorder(word, contribution)) %>%
  ggplot(aes(word, contribution, fill = contribution > 0)) +
  geom_col(show.legend = FALSE) +
  coord_flip()

contributions_acorn <- result_acorn %>%
  inner_join(get_sentiments("afinn"), by = "word") %>%
  group_by(word) %>%
  summarize(occurences = n(),
            contribution = sum(score))
contributions_acorn %>%
  top_n(25, abs(contribution)) %>%
  mutate(word = reorder(word, contribution)) %>%
  ggplot(aes(word, contribution, fill = contribution > 0)) +
  geom_col(show.legend = FALSE) +
  coord_flip()

contributions_html <- result_html %>%
  inner_join(get_sentiments("afinn"), by = "word") %>%
  group_by(word) %>%
  summarize(occurences = n(),
            contribution = sum(score))
contributions_html %>%
  top_n(25, abs(contribution)) %>%
  mutate(word = reorder(word, contribution)) %>%
  ggplot(aes(word, contribution, fill = contribution > 0)) +
  geom_col(show.legend = FALSE) +
  coord_flip()

### Most positive/negative messages
sentiment_messages_om <- result_om %>%
  inner_join(get_sentiments("afinn"), by = "word") %>%
  group_by(sha256) %>%
  summarize(sentiment = mean(score),
            words = n()) %>%
  ungroup() %>%
  filter(words >= 5)

sentiment_messages_om %>%
  arrange(desc(sentiment))

data_om[data_om$sha256=="189620a1c0fa6753d90908ed0c618d45a4eeb0708092999c90a51105b38b6037",]$content

sentiment_messages_om %>%
  arrange(sentiment)

data_om[data_om$sha256=="6953c16ea800a422559493518b2a1a03c72505365b73525ac56280e19bd5193e",]$content

sentiment_messages_acorn <- result_acorn %>%
  inner_join(get_sentiments("afinn"), by = "word") %>%
  group_by(id) %>%
  summarize(sentiment = mean(score),
            words = n()) %>%
  ungroup() 

sentiment_messages_acorn %>%
  arrange(desc(sentiment))

acorn_comment[acorn_comment$id=="104",]$content

sentiment_messages_acorn %>%
  arrange(sentiment)

acorn_comment[acorn_comment$id=="28",]$content

sentiment_messages_html <- result_html %>%
  inner_join(get_sentiments("afinn"), by = "word") %>%
  group_by(sha256) %>%
  summarize(sentiment = mean(score),
            words = n()) %>%
  ungroup() %>%
  filter(words >= 5)

sentiment_messages_html %>%
  arrange(desc(sentiment))

data_html[data_html$sha256=="88c261d0ed59df75041125c68ad48f3604944dc84094bb67f118092de34a12ba",]$content

sentiment_messages_html %>%
  arrange(sentiment)

data_html[data_html$sha256=="8f47bb74dcd6cb96a54e06f8b1da0b3d62cb6e59a522ec578d7799b3fe465b18",]$content
