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

# This creates *.csv files in order to create graphs using the filter provided
# by agentdave 
source("scripts/exploration/neo4j.R")


filter_me_words <- function(filtered, savefile)
{
    relevant_words = c("affordability", "cost", "price", "expensive")
    #relevant_words = c("defined", "essential", "basic", "universal", "mandated", "essential","not", "rights")


    # Computing the cosine similarity for the entire vocabulary is expensive, so
    # we're going to reduce down to just the unique words and compute it once,
    # then join the results back up with the regular bigrams dataframe

    stop_words <- filter(stop_words, word!= c("not","be"))

    vocab = rbind(filtered %>% mutate(word = word1),
                  filtered %>% mutate(word = word2)) %>%
                  select(word) %>%
                  distinct(word) %>%
                  filter(!(word %in% stop_words$word)) %>%
                  mutate(relevance = similarity.scores(word, relevant_words))

    relevance.affordability <- filtered %>%
      filter(!(word1 %in% stop_words$word)) %>%
      filter(!(word2 %in% stop_words$word)) %>%
      left_join(vocab, by=c("word1" = "word")) %>%
      rename(relevance1 = relevance) %>%
      left_join(vocab, by=c("word2" = "word")) %>%
      rename(relevance2 = relevance)

    write_csv(relevance.affordability, savefile)

    rm(relevance.affordability)
}


# Create filters as per agentdave 

embeddings <- read_delim("text_vectors/glove.6B.100d.txt", delim=" ", 
                         quote = "", col_names = FALSE)
# Turn them into a data table so we can look them up quickly via the string
embeddings.dt <- data.table(embeddings)
setkey(embeddings.dt, X1)

# Convenience function to return the embedding vector as a matrix (without the
# first item in every line of the text file, which is the word itself)
embedding.get <- function(word) {
  lapply(word, function(w) {
    return(as.matrix(embeddings.dt[.(w)][,2:101]))
  })
}

# Get the maximum cosine similarity of a target_word to one of the given
# concept_words. Cosine similarity is computed between the target and each
# of the concept words, then the max value is found.
similarity.score <- function(target_word, concept_words) {
  target_word.vector <- embedding.get(target_word)
  concept_words.vectors <- embedding.get(concept_words)
  
  similarities <- sapply(concept_words.vectors, function(x) {
    sim2(x, target_word.vector[[1]])
  })
  return(max(similarities))
}

# Apply the similarity.score function to a group of target_words in a way
# that's compatible with data frames and dplyr's mutation function.
similarity.scores <- function(target_words, concept_words) {
  return(sapply(target_words, function(x) {
    similarity.score(x, concept_words)
  }))
}





files <-  c("doc2vec_other_incumb_afford_filter.csv", 
            "doc2vec_advocacy_afford_filter.csv",
            "doc2vec_telecom_afford_filter.csv",
            "doc2vec_government_afford_filter.csv",
           "doc2vec_other_afford_filter.csv",
          "doc2vec_Cable_afford_filter.csv",
           "doc2vec_SmallInc_afford_filter.csv")


queries <- c( "MATCH (Q:Question)<-[r:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE r.method = 'doc2vec-MonteCarlo'
            AND o.category = 'Network operator: other'
            AND Q.ref = 'Q1'
            RETURN distinct s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[r:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE r.method = 'doc2vec-MonteCarlo'
            AND o.category = 'Advocacy organizations' OR o.category = 'Consumer advocacy organizations'
            AND Q.ref = 'Q1'
            RETURN distinct s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[r:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE r.method = 'doc2vec-MonteCarlo'
            AND o.category = 'Network operator: Telecom Incumbents'
            AND Q.ref = 'Q1'
            RETURN distinct s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[r:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE r.method = 'doc2vec-MonteCarlo'
            AND o.category = 'Government'
            AND Q.ref = 'Q1'
            RETURN distinct s.content AS Segment, o.name as Organization",
       
            "MATCH (Q:Question)<-[r:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE r.method = 'doc2vec-MonteCarlo'
            AND o.category = 'Other'
            AND Q.ref = 'Q1'
            RETURN distinct s.content AS Segment, o.name as Organization",
        

            "MATCH (Q:Question)<-[r:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE r.method = 'doc2vec-MonteCarlo'
            AND o.category = 'Network operator - Cable companies'
            AND Q.ref = 'Q1'
            RETURN distinct s.content AS Segment, o.name as Organization",

             "MATCH (Q:Question)<-[r:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT r.method = 'doc2vec-MonteCarlo'
            AND o.category = 'Small incumbents'
            AND Q.ref = 'Q1'
            RETURN distinct s.content AS Segment, o.name as Organization"
)


print("Doc 2 vec")

files = c("all_orgs_filter.csv")
queries = c(
             "MATCH (Q:Question)<-[r:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE r.method = 'doc2vec-MonteCarlo'
            AND Q.ref = 'Q1'
            RETURN distinct s.content AS Segment, o.name as Organization")

for( i in 1:length(files))
{ 
    data_raw <- cypher(graph, queries[i])
    results <- dplyr::mutate(data_raw, id=as.integer(rownames(data_raw)))
    tibbled_data <- as_tibble(results) 
    print(queries[i])
    print(files[i])

    print(tibbled_data %>% group_by(Organization))
    # change n here to add more n to the n gram
    bigrams <- results %>%
        unnest_tokens(bigram, Segment, token="ngrams", n=2)

    # you'll also need to add "word3" for a trigram
    # note you can turf these mutates if you use a stemmer 
    sep_bigrams <- bigrams %>%
        separate(bigram, c("word1", "word2"), sep = " ") 

    sep_bigrams <- sep_bigrams %>%
        mutate(word1=recode(word1, "services" = "service"))

    sep_bigrams <- sep_bigrams %>%
        mutate(word2=recode(word2, "services" = "service"))

    sep_bigrams <- sep_bigrams %>%
        mutate(word2=recode(word2, "speeds" = "speed"))


    my_stops = data_frame(word=c(as.character(1:15),"postal", "code", "company", "openmedia.ca", "submission",
                                "frpc", "ba", "cal", "arv","july","de","la", "dec", "http", "www.crtc.ca"))

    filtered <- sep_bigrams %>%
    filter(!word1 %in% my_stops$word) %>%
    filter(!word2 %in% my_stops$word) 

    filter_me_words(filtered, files[i])
    
    print("Finished a query!")


}


print("Moving to solr....")
q()
queries <- c( "MATCH (Q:Question)<-[r:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT r.method = 'doc2vec-MonteCarlo'
            AND o.category = 'Network operator: other'
            AND Q.ref = 'Q1'
            RETURN distinct s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[r:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT r.method = 'doc2vec-MonteCarlo'
            AND o.category = 'Advocacy organizations' OR o.category = 'Consumer advocacy organizations'
            AND Q.ref = 'Q1'
            RETURN distinct s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[r:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT r.method = 'doc2vec-MonteCarlo'
            AND o.category = 'Network operator: Telecom Incumbents'
            AND Q.ref = 'Q1'
            RETURN distinct s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[r:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT r.method = 'doc2vec-MonteCarlo'
            AND o.category = 'Government'
            AND Q.ref = 'Q1'
            RETURN distinct s.content AS Segment, o.name as Organization",
           
            "MATCH (Q:Question)<-[r:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT r.method = 'doc2vec-MonteCarlo'
            AND o.category = 'Other'
            AND Q.ref = 'Q1'
            RETURN distinct s.content AS Segment, o.name as Organization",


            "MATCH (Q:Question)<-[r:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT r.method = 'doc2vec-MonteCarlo'
            AND o.category = 'Network operator - Cable companies'
            AND Q.ref = 'Q1'
            RETURN distinct s.content AS Segment, o.name as Organization",

             "MATCH (Q:Question)<-[r:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT r.method = 'doc2vec-MonteCarlo'
            AND o.category = 'Small incumbents'
            AND Q.ref = 'Q1'
            RETURN distinct s.content AS Segment, o.name as Organization"
)



files <- c("solr_other_incumb_afford_filter_300.csv", 
            "solr_advocacy_afford_filter_300.csv",
        "solr_telecom_afford_filter_300.csv",
           "solr_government_afford_filter_300.csv",
          "solr_other_afford_filter_300.csv",
         "solr_Cable_afford_filter_300.csv",
          "solr_SmallInc_afford_filter_300.csv")


for( i in 1:length(files))
{
    data_raw <- cypher(graph, queries[i])
    results <- dplyr::mutate(data_raw, id=as.integer(rownames(data_raw)))
    tibbled_data <- as_tibble(results) 

    print(tibbled_data %>% group_by(Organization))
    # change n here to add more n to the n gram
    bigrams <- results %>%
        unnest_tokens(bigram, Segment, token="ngrams", n=2)# %>%

    # you'll also need to add "word3" for a trigram
    # note if you use a stemmer you can turf these mutates. 
    sep_bigrams <- bigrams %>%
        separate(bigram, c("word1", "word2"), sep = " ") 

    sep_bigrams <- sep_bigrams %>%
        mutate(word1=recode(word1, "services" = "service"))

    sep_bigrams <- sep_bigrams %>%
        mutate(word2=recode(word2, "services" = "service"))

    sep_bigrams <- sep_bigrams %>%
        mutate(word2=recode(word2, "speeds" = "speed"))

    my_stops = data_frame(word=c(as.character(1:15),"postal", "code", "company", "openmedia.ca", "submission",
                                "frpc", "ba", "cal", "arv","july","de","la", "dec", "http", "www.crtc.ca"))

    print("I got here")

    filtered <- sep_bigrams %>%
    filter(!word1 %in% stop_words$word) %>%
    filter(!word2 %in% stop_words$word) %>%
    filter(!word1 %in% my_stops$word) %>%
    filter(!word2 %in% my_stops$word) 

    filter_me_words(filtered, files[i])
    
    print("Finished a query!")


}











