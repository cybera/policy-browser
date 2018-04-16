# setwd to the project root
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

source("scripts/exploration/neo4j.R")

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


###ACORN
#setwd("~/DS/policy-browser/data/raw")
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
#query_html= "MATCH path=(:Person)-[]-(p:Participant)-[]-(:Submission)-[]-(d:Document{type:\"html\"})
#WHERE NOT (:Organization)-[]-(p)
#RETURN d.content as content, d.sha256 as sha256, d.translated as translated"
query_html="MATCH (d:Document{type:\"html\"})<-[r:CONTAINING]-(s:Submission{name:\"Interventions Phase 2\"})
RETURN d.content as content, d.sha256 as sha256, d.translated as translated"
data_html = cypher(graph, query_html) 
dim(data_html) #dim 529
data_html <- data_html[!data_html$content== "Copie envoyée au demandeur et à tout autre intimé si applicable / Copy sent to applicant and to any respondent if applicable: Non/No",]
data_html <- data_html[!data_html$content== "Copie envoyée au demandeur et à tout autre intimé si applicable / Copy sent to applicant and to any respondent if applicable: Oui/Yes",]
data_html$content <- lapply(data_html$content, function(x) gsub("\\n+ |\\t |\\s+", " ", x))
data_html$content <- unlist(data_html$content)
data_html <- data_html[!data_html$content== " ",]
dim(data_html) #466
data_html_english <- data_html[is.na(data_html$translated),] #dim 378
data_html_french <- data_html[!is.na(data_html$translated),] #dim 88
data_html_french <-data_html_french[,c("sha256","translated")]
data_html_english <-data_html_english[,c("sha256","content")]
colnames(data_html_french) <- colnames(data_html_english)
data_html <- rbind(data_html_french, data_html_english) 

#Some cleaning
data_html$content <- gsub('\u009c|\u00F0|\u0093|\u0094|\u0092',' ',data_html$content)
data_html$content <- gsub('Raisons pour comparaitre / Reasons for appearance', ' ',data_html$content)
data_html$content <- gsub('Reasons to appear / Reasons for appearance', ' ',data_html$content)
write.csv(data_html, file = "data_html.csv")

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

#Some words were parsed not correctly
acorn_comment$content <- gsub('informa on','information',acorn_comment$content)
acorn_comment$content <- gsub('op on','option',acorn_comment$content)
acorn_comment$content <- gsub('transac on','transaction',acorn_comment$content)
acorn_comment$content <- gsub('ac vi es','activities',acorn_comment$content)
acorn_comment$content <- gsub('ac vity','activity',acorn_comment$content)
acorn_comment$content <- gsub('ac ve','active',acorn_comment$content)
acorn_comment$content <- gsub('essen al','essential',acorn_comment$content)
acorn_comment$content <- gsub('communica ','communicati',acorn_comment$content)
acorn_comment$content <- gsub('ge ng','getting',acorn_comment$content)
acorn_comment$content <- gsub('medica ons','medications',acorn_comment$content)
acorn_comment$content <- gsub('wai ng','waiting',acorn_comment$content)
acorn_comment$content <- gsub('applica ','applicati',acorn_comment$content)
acorn_comment$content <- gsub('cri cal','critical',acorn_comment$content)
acorn_comment$content <- gsub('recrea onal','recreational',acorn_comment$content)
acorn_comment$content <- gsub('educa onal','educational',acorn_comment$content)
acorn_comment$content <- gsub('connec ','connecti',acorn_comment$content)
acorn_comment$content <- gsub('ma er','matter',acorn_comment$content)
acorn_comment$content <- gsub('be er','better',acorn_comment$content)
acorn_comment$content <- gsub('elimina ng','eliminating',acorn_comment$content)
acorn_comment$content <- gsub('ea ng','eating',acorn_comment$content)
acorn_comment$content <- gsub('rela ve','relative',acorn_comment$content)
acorn_comment$content <- gsub('posi ve','positive',acorn_comment$content)
acorn_comment$content <- gsub('necessi','necessiti',acorn_comment$content)
acorn_comment$content <- gsub('alterna ve','alternative',acorn_comment$content)
acorn_comment$content <- gsub('inter- net','internet',acorn_comment$content)
acorn_comment$content <- gsub('ac- cess','access',acorn_comment$content)

######################### Comparing data_om, acorn_comment and html submissions

#########################  Word count
my_stopwords <- data_frame(word = c(as.character(1:10),"canada","service","canadians", "canadian", "services"))
stopwords_html <- data_frame(word = c(as.character(1:10),"http","14","879x", "00058", "refhub.elsevier.com", "s2213","www.scribd.com","87308119","takebackyourpower.net","sbref0005", "témiscsmingue","2012","2014"))

result_om <- data_om[,c("sha256","content")] %>% 
  unnest_tokens(word, content) %>% 
  anti_join(stop_words)  %>%
  anti_join(my_stopwords)

counts_om <- result_om %>%
  count(word, sort = TRUE)

counts_om$n <- counts_om$n*100/sum(counts_om$n)

result_acorn <- acorn_comment%>% 
  unnest_tokens(word, content) %>% 
  anti_join(stop_words)  %>%
  anti_join(my_stopwords) %>%
  anti_join(proustr::proust_stopwords()) #for french data

counts_acorn <- result_acorn %>%
  count(word, sort = TRUE) 

counts_acorn$n <- counts_acorn$n*100/sum(counts_acorn$n)

result_html <- data_html%>% 
  unnest_tokens(word, content) %>% 
  anti_join(stop_words)  %>%
  anti_join(my_stopwords) %>%
  anti_join(stopwords_html) %>%
  filter(!str_detect(word, "\\bsbref\\w+"))#,!str_detect(word, "\\b[[:alpha:]]{15,}\\b"),!str_detect(word, "[[:digit:]]+"))

counts_html <- result_html %>%
  count(word, sort = TRUE)

counts_html$n <- counts_html$n*100/sum(counts_html$n)

#################### Bigrams
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
graph_om <- ggraph(bigram_graph_om, layout = "fr") +
  geom_edge_link(
    aes(edge_alpha=n), 
    show.legend=FALSE,
    end_cap = circle(0.03, 'inches')) +
  geom_node_point(color="palevioletred", size=4) +
  geom_node_text(aes(label=name), repel=TRUE, size=4) +
  theme_void() 


ggsave("notebooks/images/2gram_om.png", graph_om)


bigram_counts_acorn <- acorn_comment %>%
  unnest_tokens(bigram, content, token = "ngrams", n = 2)%>%
  separate(bigram, c("word1", "word2"), sep = " ")%>%
  filter(!word1 %in% stop_words$word) %>%
  filter(!word2 %in% stop_words$word) %>% 
  filter(!word1 %in% proustr::proust_stopwords()$word) %>%
  filter(!word2 %in% proustr::proust_stopwords()$word) %>% 
  count(word1, word2, sort = TRUE)

bigram_counts_acorn2<- bigram_counts_acorn
bigram_counts_acorn2$n <- bigram_counts_acorn$n*100/sum(bigram_counts_acorn$n)

bigram_graph_acorn <- bigram_counts_acorn%>%
  filter(n > 2) %>%
  graph_from_data_frame()

set.seed(4321)
graph_acorn <- ggraph(bigram_graph_acorn, layout = "fr") +
  geom_edge_link(
    aes(edge_alpha=n), 
    show.legend=FALSE,
    end_cap = circle(0.03, 'inches')) +
  geom_node_point(color="palevioletred", size=4) +
  geom_node_text(aes(label=name), repel=TRUE, size=4) +
  theme_void() 

ggsave("notebooks/images/2gram_acorn.png", graph_acorn)

bigram_counts_html <- data_html%>%
  unnest_tokens(bigram, content, token = "ngrams", n = 2)%>%
  separate(bigram, c("word1", "word2"), sep = " ")%>%
  filter(!word1 %in% stop_words$word) %>%
  filter(!word2 %in% stop_words$word) %>%
  filter(!word1 %in% stopwords_html$word) %>%
  filter(!word2 %in% stopwords_html$word) %>% 
  #filter(!str_detect(word1, "\\bsbref\\w+"),!str_detect(word1, "\\b[[:alpha:]]{15,}\\b"),!str_detect(word1, "[[:digit:]]+"))%>%
  #filter(!str_detect(word2, "\\bsbref\\w+"),!str_detect(word2, "\\b[[:alpha:]]{15,}\\b"),!str_detect(word2, "[[:digit:]]+"))%>%
  count(word1, word2, sort = TRUE)

bigram_counts_html2 <- bigram_counts_html
bigram_counts_html2$n <- bigram_counts_html$n*100/sum(bigram_counts_html$n)

bigram_graph_html <- bigram_counts_html %>%
  filter(n > 10) %>%
  graph_from_data_frame()

set.seed(1234)
graph_html <- ggraph(bigram_graph_html, layout = "fr") +
  geom_edge_link(
    aes(edge_alpha=n), 
    show.legend=FALSE,
    end_cap = circle(0.03, 'inches')) +
  geom_node_point(color="palevioletred", size=4) +
  geom_node_text(aes(label=name), repel=TRUE, size=4) +
  theme_void() 

ggsave("notebooks/images/2gram_html.png", graph_html)
############## Trigramms

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
  filter(!word1 %in% stopwords_html$word,
         !word2 %in% stopwords_html$word,
         !word3 %in% stopwords_html$word) %>% 
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

topics_om <-lda_om %>%
  tidy() %>%
  group_by(topic) %>%
  top_n(8, beta) %>%
  ungroup() %>%
  mutate(term = reorder(term, beta)) %>%
  ggplot(aes(term, beta, fill = factor(topic))) +
  theme(text = element_text(size=15)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free_y") +
  coord_flip()
ggsave("notebooks/images/topicsOM.png", topics_om)

words50_acorn <- result_acorn %>%
  group_by(word) %>%
  mutate(word_total = n()) %>%
  ungroup()

dtm_acorn <- words50_acorn %>%
  count(id, word) %>%
  cast_dtm(id, word, n)

lda_acorn <- LDA(dtm_acorn, k = 5, control = list(seed = 1234))

topics_acorn <-lda_acorn %>%
  tidy() %>%
  group_by(topic) %>%
  top_n(8, beta) %>%
  ungroup() %>%
  mutate(term = reorder(term, beta)) %>%
  ggplot(aes(term, beta, fill = factor(topic))) +
  theme(text = element_text(size=15)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free_y") +
  coord_flip()
ggsave("notebooks/images/topicsAC.png", topics_acorn)

words50_html <- result_html %>%
  group_by(word) %>%
  mutate(word_total = n()) %>%
  ungroup() 

dtm_html <- words50_html %>%
  count(sha256, word) %>%
  cast_dtm(sha256, word, n)

lda_html <- LDA(dtm_html, k = 5, control = list(seed = 1234))

topics_html <-lda_html %>%
  tidy() %>%
  group_by(topic) %>%
  top_n(8, beta) %>%
  ungroup() %>%
  mutate(term = reorder(term, beta)) %>%
  ggplot(aes(term, beta, fill = factor(topic))) +
  theme(text = element_text(size=15)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free_y") +
  coord_flip()
ggsave("notebooks/images/topicsHTML.png", topics_html)

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
words_om <- contributions_om %>%
  top_n(25, abs(contribution)) %>%
  mutate(word = reorder(word, contribution)) %>%
  ggplot(aes(word, contribution, fill = contribution > 0)) +
  theme(text = element_text(size=15)) +
  geom_col(show.legend = FALSE) +
  coord_flip()
ggsave("notebooks/images/wordsOM.png", words_om)

contributions_acorn <- result_acorn %>%
  inner_join(get_sentiments("afinn"), by = "word") %>%
  group_by(word) %>%
  summarize(occurences = n(),
            contribution = sum(score))
words_acorn <- contributions_acorn %>%
  top_n(25, abs(contribution)) %>%
  mutate(word = reorder(word, contribution)) %>%
  ggplot(aes(word, contribution, fill = contribution > 0)) +
  theme(text = element_text(size=15)) +
  geom_col(show.legend = FALSE) +
  coord_flip()
ggsave("notebooks/images/wordsAC.png", words_acorn)

contributions_html <- result_html %>%
  inner_join(get_sentiments("afinn"), by = "word") %>%
  group_by(word) %>%
  summarize(occurences = n(),
            contribution = sum(score))
words_html <- contributions_html %>%
  top_n(25, abs(contribution)) %>%
  mutate(word = reorder(word, contribution)) %>%
  ggplot(aes(word, contribution, fill = contribution > 0)) +
  theme(text = element_text(size=15)) +
  geom_col(show.legend = FALSE) +
  coord_flip()
ggsave("notebooks/images/wordsHTML.png", words_html)

###################### Most positive/negative messages
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

acorn_comment[acorn_comment$id=="194",]$content

sentiment_messages_html <- result_html %>%
  inner_join(get_sentiments("afinn"), by = "word") %>%
  group_by(sha256) %>%
  summarize(sentiment = mean(score),
            words = n()) %>%
  ungroup() %>%
  filter(words >= 5)

sentiment_messages_html %>%
  arrange(desc(sentiment))

data_html[data_html$sha256=="7f1890084e316ec000830f1182b4c7e871f5db96124d68daa182f8eaa6d62755",]$content

sentiment_messages_html %>%
  arrange(sentiment)

data_html[data_html$sha256=="c17c4a7d96c9b64b3840a038c210acb6a3dff7f2717be423c3bdae86ca3f7c93",]$content

###NRC part for Phase2 individual submissions
sentiment_nrc <- result_html %>% 
  inner_join(get_sentiments("nrc")) %>% 
  count(sha256, sentiment) %>%
  spread(sentiment, n, fill=0) %>%
  setNames(c(names(.)[1],paste0('nrc_', names(.)[-1]))) %>%
  mutate(score_nrc = nrc_positive - nrc_negative) %>%
  ungroup()

data_sentiments <- Reduce(full_join,
                          list(sentiment_nrc) )%>% 
  mutate_each(funs(replace(., which(is.na(.)), 0)))

data_full <- full_join(data_html, data_sentiments)  %>% 
  mutate_each(funs(replace(., which(is.na(.)), 0)), starts_with("score"), starts_with("nrc"))

data_full %>%
  top_n(1, score_nrc) %>%
  select(sha256, score_nrc, content) 

data_full %>%
  top_n(1, nrc_anger) %>%
  select(sha256, nrc_anger, content) 

data_full %>%
  top_n(1, nrc_surprise) %>%
  select(sha256, nrc_surprise, content)
