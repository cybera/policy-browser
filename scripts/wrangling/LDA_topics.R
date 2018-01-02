library(RSQLite)
library(DBI)
library(dplyr)
library(ggplot2)
library(tm)
library(topicmodels)
library(tidytext)
library(ldatuning)
library(LDAvis)
library(stringi)
library(magrittr)
library(tsne)
#setwd("~/DS/hey-cira/data/processed")

con = dbConnect(RSQLite::SQLite(), dbname="docs.db")
docs = dbGetQuery( con,'select id, cast(docname as TEXT) as docname, content, error from docs' )
dbDisconnect(con)

docs$Category="Other"
index_s<- grepl("Final Submission", docs$docname)
docs[index_s,]$Category <-"Final Submission"
index_i<- grepl("Intervention", docs$docname)
docs[index_i,]$Category <-"Intervention"
index_fc<- grepl("Further Comments", docs$docname)
docs[index_fc,]$Category <-"Further Comments"
index_ph<- grepl("Presentations at hearing", docs$docname)
docs[index_ph,]$Category <-"Presentations at hearing"
index_fr<- grepl("Final Replies", docs$docname)
docs[index_fr,]$Category <-"Final Replies"
index_u<- grepl("Undertakings", docs$docname)
docs[index_u,]$Category <-"Undertakings"
index_ip2<- grepl("Interventions Phase 2", docs$docname)
docs[index_ip2,]$Category <-"Interventions Phase 2"

table(docs$Category)

docs[docs$Category=="Other",]$docname
docs1 <- docs[docs$content!="",]
docs1 <- docs1[!is.na(docs1$content),]

#temporary category
content <- docs1$content
utf8_content <- iconv(content, "LATIN2", "UTF-8")
#utf8_content <- utf8_content[!utf8_content==""] #23 documents with blank content
docs_corpus <- Corpus(VectorSource(utf8_content))
docs_corpus <- tm_map(docs_corpus, removePunctuation) 
docs_corpus <- tm_map(docs_corpus, removeNumbers)
docs_corpus <- tm_map(docs_corpus, tolower)
docs_corpus <- tm_map(docs_corpus, removeWords, stopwords("english"))
docs_corpus <- tm_map(docs_corpus, removeWords, stopwords("french"))
docs_corpus <- tm_map(docs_corpus, content_transformer(gsub), pattern = "non profit", replacement = "nonprofit")
docs_corpus <- tm_map(docs_corpus, removeWords, c("can","name","via","first","last","per", "will", "plus","form","next","non"))
docs_corpus <- tm_map(docs_corpus, content_transformer(gsub), pattern = "services", replacement = "service")
docs_corpus <- tm_map(docs_corpus, content_transformer(gsub), pattern = "communities", replacement = "community")
docs_corpus <- tm_map(docs_corpus, content_transformer(gsub), pattern = "providers", replacement = "provider")
docs_corpus <- tm_map(docs_corpus, content_transformer(gsub), pattern = "highw", replacement = "highway")
docs_corpus <- tm_map(docs_corpus, content_transformer(gsub), pattern = "highwayay", replacement = "highway")
#docs_corpus <- tm_map(docs_corpus, PlainTextDocument)
#docs_corpus <- tm_map(docs_corpus, stemDocument) 
dtm <- DocumentTermMatrix(docs_corpus) 

summary(slam::col_sums(dtm))
inspect(dtm[1,1:20])

term_tfidf <- tapply(dtm$v/slam::row_sums(dtm)[dtm$i], dtm$j, mean) *
  log2(tm::nDocs(dtm)/slam::col_sums(dtm > 0))
summary(term_tfidf)

reduced.dtm <- dtm[,term_tfidf >= 0.00915]
summary(slam::col_sums(reduced.dtm))

rowTotals <- apply(reduced.dtm, 1, sum) #Find the sum of words in each Document
reduced.dtm   <- reduced.dtm[rowTotals> 0, ]

control_list_gibbs <- list(
  burnin = 2500,
  iter = 5000,
  seed = 0:4,
  nstart = 5,
  best = TRUE
)
##find optimal topics number 2-15
## this takes forever to run I was never patient enough 
system.time(
  topic_number <- FindTopicsNumber(
    reduced.dtm,
    topics = seq(from = 2, to = 15, by = 1),
    metrics = c( "Griffiths2004", "CaoJuan2009", "Arun2010", "Deveaud2014"),
    method = "Gibbs",
    control = control_list_gibbs,
    mc.cores = 16L,
    verbose = TRUE
  )
)
FindTopicsNumber_plot(topic_number)
############

system.time(model5 <- topicmodels::LDA(reduced.dtm, 5, method = "Gibbs", control =control_list_gibbs))
system.time(model10 <- topicmodels::LDA(reduced.dtm, 10, method = "Gibbs", control =control_list_gibbs))
system.time(model15 <- topicmodels::LDA(reduced.dtm, 15, method = "Gibbs", control =control_list_gibbs))
system.time(model2 <- topicmodels::LDA(reduced.dtm, 2, method = "Gibbs", control =control_list_gibbs))

topics2 <- topicmodels::topics(model2, 1)
terms2 <- as.data.frame(topicmodels::terms(model2, 10), stringsAsFactors = FALSE)
terms2

topics5 <- topicmodels::topics(model5, 1)
terms5 <- as.data.frame(topicmodels::terms(model5, 10), stringsAsFactors = FALSE)
terms5

topics10 <- topicmodels::topics(model10, 1)
terms10 <- as.data.frame(topicmodels::terms(model10, 10), stringsAsFactors = FALSE)
terms10

topics15 <- topicmodels::topics(model15, 1)
terms15 <- as.data.frame(topicmodels::terms(model15, 10), stringsAsFactors = FALSE)
terms15

gamma_dtm2 <- tidy(model2, matrix = "gamma")
max_per_doc2 = aggregate(gamma_dtm2$gamma,by=list(gamma_dtm2$document),max)

ggplot(data=max_per_doc2,aes(x, fill=factor(2))) +
  geom_histogram(bins = 20) +
  scale_fill_discrete(name = "Number of\nTopics") + 
  xlab("maximum gamma per document") +
  geom_vline(aes(xintercept = 1/2),color="darkred") +
  labs(title = "Gamma for 2 topics")

gamma_dtm2 <- gamma_dtm2 %>% 
  group_by(document) %>%
  filter(gamma==max(gamma))
table(gamma_dtm2$topic)

gamma_dtm5 <- tidy(model5, matrix = "gamma")
max_per_doc5 = aggregate(gamma_dtm5$gamma,by=list(gamma_dtm5$document),max)

ggplot(data=max_per_doc5,aes(x, fill=factor(5))) +
  geom_histogram(bins = 20) +
  scale_fill_discrete(name = "Number of\nTopics") + 
  xlab("maximum gamma per document") +
  geom_vline(aes(xintercept = 1/5),color="darkred") +
  labs(title = "Gamma for 5 topics")

gamma_dtm5 <- gamma_dtm5 %>% 
  group_by(document) %>%
  filter(gamma==max(gamma))
table(gamma_dtm5$topic)

gamma_dtm10 <- tidy(model10, matrix = "gamma")
max_per_doc10 = aggregate(gamma_dtm10$gamma,by=list(gamma_dtm10$document),max)

ggplot(data=max_per_doc10,aes(x, fill=factor(10))) +
  geom_histogram(bins = 20) +
  scale_fill_discrete(name = "Number of\nTopics") + 
  xlab("maximum gamma per document") +
  geom_vline(aes(xintercept = 1/10),color="darkred") +
  labs(title = "Gamma for 10 topics")

gamma_dtm10 <- gamma_dtm10 %>% 
  group_by(document) %>%
  filter(gamma==max(gamma))
table(gamma_dtm10$topic)

gamma_dtm15 <- tidy(model15, matrix = "gamma")
max_per_doc15 = aggregate(gamma_dtm15$gamma,by=list(gamma_dtm15$document),max)

ggplot(data=max_per_doc15,aes(x, fill=factor(15))) +
  geom_histogram(bins = 20) +
  scale_fill_discrete(name = "Number of\nTopics") + 
  xlab("maximum gamma per document") +
  geom_vline(aes(xintercept = 1/15),color="darkred") +
  labs(title = "Gamma for 15 topics")

gamma_dtm15 <- gamma_dtm15 %>% 
  group_by(document) %>%
  filter(gamma==max(gamma))
table(gamma_dtm15$topic)

zero_docs <- unname(which(rowTotals==0))
svd_tsne <- function(x) tsne(svd(x)$u)
topicmodels_json_ldavis <- function(fitted, corpus, doc_term){
  phi <- posterior(fitted)$terms %>% as.matrix
  theta <- posterior(fitted)$topics %>% as.matrix
  vocab <- colnames(phi)
  doc_length <- vector()
  for (i in 1:length(corpus)) 
    if (!(i %in% zero_docs)){
      temp <- paste(corpus[[i]]$content, collapse = ' ')
      doc_length <- c(doc_length, stri_count(temp, regex = '\\S+'))
    }
  temp_frequency <- as.matrix(doc_term)
  freq_matrix <- data.frame(ST = colnames(temp_frequency),
                            Freq = colSums(temp_frequency))
  rm(temp_frequency)
  json_lda <- LDAvis::createJSON(phi = phi, theta = theta,
                                 vocab = vocab,
                                 doc.length = doc_length,
                                 term.frequency = freq_matrix$Freq)
                                 #mds.method = svd_tsne) #for 2 topics
  
  return(json_lda)
}

json10 <- topicmodels_json_ldavis(model10, docs_corpus, reduced.dtm)
serVis(json10)

json2 <- topicmodels_json_ldavis(model2, docs_corpus, reduced.dtm)
serVis(json2)

json5 <- topicmodels_json_ldavis(model5, docs_corpus, reduced.dtm)
serVis(json5)

json15 <- topicmodels_json_ldavis(model15, docs_corpus, reduced.dtm)
serVis(json15)

dtm_topics <- topicmodels::topics(model10, 1)
doctopics.df <- as.data.frame(dtm_topics)
docs1<-docs1[rowTotals> 0, ]
doctopics.df <- dplyr::transmute(doctopics.df, id = rownames(doctopics.df), Topic = dtm_topics)
doctopics.df$id=docs1$id
docs1 <- dplyr::inner_join(docs1, doctopics.df, by = "id")

dtm_terms <- as.data.frame(topicmodels::terms(model10, 30), stringsAsFactors = FALSE)
dtm_terms[1:5]
topicTerms <- tidyr::gather(dtm_terms, Topic)
topicTerms <- cbind(topicTerms, Rank = rep(1:30))
topTerms <- dplyr::filter(topicTerms, Rank < 4)
topTerms <- dplyr::mutate(topTerms, Topic = stringr::word(Topic, 2))
topTerms$Topic <- as.numeric(topTerms$Topic)
topicLabel <- data.frame()
for (i in 1:10){
  z <- dplyr::filter(topTerms, Topic == i)
  l <- as.data.frame(paste(z[1,2], z[2,2], z[3,2], sep = " " ), stringsAsFactors = FALSE)
  topicLabel <- rbind(topicLabel, l)
  
}
colnames(topicLabel) <- c("Label")
topicLabel

theta <- as.data.frame(topicmodels::posterior(model10)$topics)
head(theta)

x <- as.data.frame(row.names(theta), stringsAsFactors = FALSE)
colnames(x) <- c("id")
x$id <- as.numeric(x$id)
theta2 <- cbind(x, theta)
theta2$id=docs1$id

docs1$docname

CategoryById=docs1[,c("id","Category")]
theta2 <- dplyr::left_join(theta2, CategoryById, by = "id")
theta.mean.by <- by(theta2[, 2:11], theta2$Category, colMeans)
theta.mean <- do.call("rbind", theta.mean.by)

library(corrplot)
c <- cor(theta.mean)
corrplot(c, method = "circle")

theta.mean.ratios <- theta.mean
for (ii in 1:nrow(theta.mean)) {
  for (jj in 1:ncol(theta.mean)) {
    theta.mean.ratios[ii,jj] <-
      theta.mean[ii,jj] / sum(theta.mean[ii,-jj])
  }
}
topics.by.ratio <- apply(theta.mean.ratios, 1, function(x) sort(x, decreasing = TRUE, index.return = TRUE)$ix)

# The most diagnostic topics per category are found in the theta 1st row of the index matrix:
topics.most.diagnostic <- topics.by.ratio[1,]
topics.most.diagnostic
#Construct datasets
#1document name, id,topic Category
doc_topics <-docs1[,c("id", "docname","Topic","Category")]
write.csv(doc_topics, file = "doc_topics.csv")
#2topic top 5 words
topics=as.data.frame(t(dtm_terms[1:5,]))
rownames(topics) <- NULL
topics$label=topicLabel$Label
write.csv(topics,file = "topics.csv")
#3Category  - topic
write.csv(topics.most.diagnostic, file="Categories.csv")

