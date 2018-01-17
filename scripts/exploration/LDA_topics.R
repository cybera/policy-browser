library(dplyr)
library(ggplot2)
library(tm)
library(topicmodels)
library(tidytext)
library(LDAvis)
library(stringi)
library(magrittr)
library(tsne)
#setwd("~/DS/hey-cira/data/processed")

docs <- read.csv("data_english.csv",fileEncoding="UTF-8", stringsAsFactors =F)
docs_fr <- read.csv("data_french.csv",fileEncoding="UTF-8", stringsAsFactors =F)
docs_fr <- docs_fr[,c(1,2,4)]
colnames(docs_fr) <- colnames(docs)
docs1 <- rbind(docs, docs_fr) 

content <- docs1$content
docs_corpus <- Corpus(VectorSource(content))
docs_corpus <- tm_map(docs_corpus, removePunctuation) 
docs_corpus <- tm_map(docs_corpus, removeNumbers)
docs_corpus <- tm_map(docs_corpus, tolower)
docs_corpus <- tm_map(docs_corpus, stripWhitespace)
docs_corpus <- tm_map(docs_corpus, removeWords, stopwords("english"))
docs_corpus <- tm_map(docs_corpus, removeWords, stopwords("french"))
docs_corpus <- tm_map(docs_corpus, content_transformer(gsub), pattern = "next genetration", replacement = "nextgeneration")
docs_corpus <- tm_map(docs_corpus, content_transformer(gsub), pattern = "non profit", replacement = "nonprofit")
docs_corpus <- tm_map(docs_corpus, content_transformer(gsub), pattern = "services", replacement = "service")
docs_corpus <- tm_map(docs_corpus, content_transformer(gsub), pattern = "communities", replacement = "community")
docs_corpus <- tm_map(docs_corpus, content_transformer(gsub), pattern = "providers", replacement = "provider")
docs_corpus <- tm_map(docs_corpus, content_transformer(gsub), pattern = "highw", replacement = "highway")
docs_corpus <- tm_map(docs_corpus, content_transformer(gsub), pattern = "hig", replacement = "high")
docs_corpus <- tm_map(docs_corpus, content_transformer(gsub), pattern = "highh", replacement = "high")
docs_corpus <- tm_map(docs_corpus, content_transformer(gsub), pattern = "highwayay", replacement = "highway")
my_stopwords <-c("can","name","via","first","last","per", "will", "plus","form","next","non","tre",
                 "forumforresearchandpolicyincommunicationsfrpc","nonno",
                 "httpwwwstatcangccacansimanosecfalseinitialviewperiodnumberwhenconvertingfrequencyusecalendaryearactionaaapplypeyearoutputfrequencyunchangedexporteridtabbedtablehtmltimeascolumnmbrbgeodmbrbcommdsmonthlangengsyearidemonthstbyvalaccessiblefalseretrlangengmanipulationoptionpercentyear",
                 "moreonthisigrmarketstudyhere",
                 "httpsdrivegooglecomfiledbwejdkzpaqrzrhynaqlgunmviewuspsharing" ,
                 "exchangenodeindependantcarrier", 
                 "httpsdrivegooglecomfiledbwejdkzpaqyzcmbtzltqtqviewuspsharing",
                 "crtcparaaug",
                 "httpsdrivegooglecomfiledbwejdkzpaqxumlzyvwrxyuuviewuspsharing", 
                 "httpsdrivegooglecomfiledbwejdkzpaqrcrwtusupyvcviewuspsharing",
                 "httpsnordicitysharepointcomteamsitecnocwirelessreportcnocwirelesssubstitutionfinaldocxtoc",
                 "openmediaresponsedecember",
                 "openmediaengagementnetworkpoboxcommercialdrvancouverbccanada",
                 "openmediaisacommunitybasedorganizationthatsafeguardsthepossibilitiesoftheopeninternet",
                 "increaseminimumservicetandardstombpsdownloadandmbpsforuploadspeeds",
                 "httpwwwteluscomenabgethelpservicetermsffhinternetaccessservicetermssupportdoevarhttpwwwteluscomengethelpservicetermsffhinternetaccessservicetermssupportdo",
                 "httpeceuropaeunewsroomdaedocumentcfmactiondisplaydocid",
                 "publicabridgedssiresponsestoaugustinterrogatoriestnc",
                 "httpwwwcrtcgccaengtranscriptstthtm")
docs_corpus <- tm_map(docs_corpus, removeWords,my_stopwords)
dtm <- DocumentTermMatrix(docs_corpus) 

term_tfidf <- tapply(dtm$v/slam::row_sums(dtm)[dtm$i], dtm$j, mean) *
  log2(tm::nDocs(dtm)/slam::col_sums(dtm > 0))
summary(term_tfidf)

reduced.dtm <- dtm[,term_tfidf >= 0.0022]
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

system.time(model10 <- topicmodels::LDA(reduced.dtm, 10, method = "Gibbs", control =control_list_gibbs))

dtm_topics <- tidy(model10, matrix = "beta")

dtm_top_terms <- dtm_topics %>%
  group_by(topic) %>%
  top_n(10, beta) %>%
  ungroup() %>%
  arrange(topic, -beta)

dtm_top_terms %>%
  mutate(term = reorder(term, beta)) %>%
  ggplot(aes(term, beta, fill = factor(topic))) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free") +
  coord_flip()

topicTerms <- cbind(dtm_top_terms, Rank = rep(1:10))
topTerms <- dplyr::filter(topicTerms, Rank < 4)
topicLabel <- data.frame()
for (i in 1:10){
  z <- dplyr::filter(topTerms, topic == i)
  l <- as.data.frame(paste(z[1,2], z[2,2], z[3,2], sep = " " ), stringsAsFactors = FALSE)
  topicLabel <- rbind(topicLabel, l)
  
}
colnames(topicLabel) <- c("Label")

gamma_dtm10 <- tidy(model10, matrix = "gamma")
max_per_doc10 = aggregate(gamma_dtm10$gamma,by=list(gamma_dtm10$document),max)

ggplot(data=max_per_doc10,aes(x, fill=factor(10))) +
  geom_histogram(bins = 20) +
  scale_fill_discrete(name = "Number of Topics") + 
  xlab("maximum gamma per document") +
  geom_vline(aes(xintercept = 1/10),color="darkred") +
  labs(title = "Gamma for 10 topics")

gamma_dtm10 <- gamma_dtm10 %>% 
  group_by(document) %>%
  filter(gamma==max(gamma))
table(gamma_dtm10$topic)


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
  
  
  return(json_lda)
}

json10 <- topicmodels_json_ldavis(model10, docs_corpus, reduced.dtm)
serVis(json10)

dtm_topics <- topicmodels::topics(model10, 1)
doctopics.df <- as.data.frame(dtm_topics)
docs1<-docs1[rowTotals> 0, ]
doctopics.df <- dplyr::transmute(doctopics.df, X = as.integer(rownames(doctopics.df)), Topic = dtm_topics)
#docs1<-docs1[rowTotals> 0, ]
#doctopics.df$id=docs1$id
docs1 <- dplyr::inner_join(docs1, doctopics.df, by = "X")

#datasets

#documents - X, sha256,topic
doc_topics <-docs1[,c("X", "sha256","Topic")]
write.csv(doc_topics, file = "doc_topics.csv")

#topics - top 5 words
topics=as.data.frame(t(dtm_terms[1:5,]))
rownames(topics) <- NULL
topics$label=topicLabel$Label
write.csv(topics,file = "topics.csv")


