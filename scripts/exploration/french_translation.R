#install.packages("devtools")
#devtools::install_github("nicolewhite/RNeo4j")

library(RNeo4j)
library(textcat)

#setwd("~/DS/hey-cira/data/processed")

graph = startGraph("http://localhost:7474/db/data/", username = "neo4j", password = "password")
query = "MATCH (n:Document) RETURN  n.sha256 AS sha256, n.content as content"
data = cypher(graph, query)

number_docs = dim(data)[1]
data_english=data.frame()
data_french=data.frame()

for (i in 1:number_docs)
{
  text=data[i,]$content
  if (is.na(text)||(text== "Copie envoyée au demandeur et à tout autre intimé si applicable / Copy sent to applicant and to any respondent if applicable: Non/No"))
       next  
  language=textcat(tolower(text))
  if (!is.na(language))
    if (language=="english")
      data_english=rbind(data_english,data[i,])
    else 
      data_french=rbind(data_french,data[i,])
} 

library(translate)
library(stringr)
n_french <- dim(data_french)[1]

data_french$n_sent <- 0
data_french$n_char <- 0
exceptions  <- vector(mode="numeric", length=0)
 for (i in 1:n_french)
 {
   text_fr <-data_french[i,]$content
   #text_fr<-gsub("[[:digit:]]+", " ", text_fr)
   text_fr<-gsub("[\r\n]", " ", text_fr)
   text_fr<-gsub("[\r\t]", " ", text_fr)
   text_fr<-gsub("\\[|\\]|\\$|#|\\(|\\)", " ", text_fr)
   text_fr<-gsub("Non/No", "Non", text_fr)
   text_fr<-str_replace(gsub("\\s+", " ", str_trim(text_fr)), "B", "b")
   data_french[i,]$content<-text_fr
   language=textcat(tolower(text_fr))
   if (!is.na(language))
    if (language=="english") 
      exceptions <-c(exceptions,i) 
   text_splitted <- unlist(strsplit(text_fr, "(?<=[[:punct:]])\\s(?=[A-Z])", perl=T))
   data_french[i,]$n_sent <-length(text_splitted)
   for(j in 1:length(text_splitted))
     data_french[i,]$n_char = data_french[i,]$n_char + nchar(text_splitted[j])
 }

table(data_french$n_sent)

which.max(data_french$n_sent)

#manually added to exceptions docs with highest number of senctences -  138 and 105
data_english <-rbind(data_english,data_french[exceptions,c("sha256","content")])
data_french <-data_french[-exceptions,]

n_french <- dim(data_french)[1]
#my_key <- '' #api key needs to be set here https://console.cloud.google.com
dim(data_english)

data_french$translated <-""

library(profvis)

for (i in 1:n_french)
{
  text_fr <-data_french[i,]$content
  text_splitted <- unlist(strsplit(text_fr, "(?<=[[:punct:]])\\s(?=[A-Z])", perl=T))
  for(j in 1:length(text_splitted))
  {
    tryCatch({
    translated_text <- translate::translate(text_splitted[j], 'fr', 'en', key = my_key)
    data_french[i,]$translated <- paste(data_french[i,]$translated,translated_text,sep = " ")
    }, error=function(e){cat("ERROR :",conditionMessage(e), "\n")})
  }
  pause(100) #pause 100 seconds
}


write.csv(data_french[,c("sha256","content","translated")],file="data_french.csv",fileEncoding="UTF-8")
write.csv(data_english,file="data_english.csv",fileEncoding="UTF-8")
write.csv(data,file = "data.csv",fileEncoding="UTF-8")

library(tm)
library(wordcloud)

content <- data_french$translated
docs_corpus <- Corpus(VectorSource(content))
docs_corpus <- tm_map(docs_corpus, removePunctuation) 
docs_corpus <- tm_map(docs_corpus, removeNumbers)
docs_corpus <- tm_map(docs_corpus, tolower)
#docs_corpus <- tm_map(docs_corpus, stripWhitespace)
docs_corpus <- tm_map(docs_corpus, removeWords, stopwords("french"))
docs_corpus <- tm_map(docs_corpus, removeWords, stopwords("english"))

wordcloud(docs_corpus, max.words = 100, random.order = FALSE)

content <- data_french$content
docs_corpus <- Corpus(VectorSource(content))
docs_corpus <- tm_map(docs_corpus, removePunctuation) 
docs_corpus <- tm_map(docs_corpus, removeNumbers)
docs_corpus <- tm_map(docs_corpus, tolower)
#docs_corpus <- tm_map(docs_corpus, stripWhitespace)
docs_corpus <- tm_map(docs_corpus, removeWords, stopwords("french"))
docs_corpus <- tm_map(docs_corpus, removeWords, stopwords("english"))

wordcloud(docs_corpus, max.words = 100, random.order = FALSE)

