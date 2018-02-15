library(RNeo4j)
library(dplyr)
library(tidytext)
library(tidyverse)
library(ggplot2)
library(tidyr)
library(readr)
library(data.table)
library(text2vec)


graph <- startGraph("http://localhost:7474/db/data/", username = "neo4j", password = "password")

q.affordability <- "
MATCH (question:Question { ref: $qref })
MATCH (query:Query)-[:ABOUT]-(question)
MATCH (query)<--(segment:Segment)-[:SEGMENT_OF]->(doc:Document)
MATCH (org:Organization)-[:SUBMITTED]->(doc)
RETURN segment.content AS content, org.category as category, 
org.name as organization
"

df.affordability <- cypher(graph, q.affordability, qref="Q12")

words.affordability <- df.affordability %>%
  unnest_tokens(word, content, token = "words") %>%
  filter(str_length(word) < 20)

bigrams.affordability <- df.affordability %>%
  unnest_tokens(bigram, content, token = "ngrams", n = 2) %>%
  filter(str_length(bigram) < 40)


tfidf.affordability <- words.affordability %>%
  count(category, word, sort = TRUE) %>%
  bind_tf_idf(word, category, n) %>%
  arrange(desc(tf_idf))

tfidf.affordability %>%
  mutate(word = factor(word, levels = rev(unique(word)))) %>% 
  group_by(category) %>% 
  top_n(15) %>% 
  ungroup %>%
  ggplot(aes(word, tf_idf, fill = category)) +
  geom_col(show.legend = FALSE) +
  labs(x = NULL, y = "tf-idf") +
  facet_wrap(~category, ncol = 2, scales = "free") +
  coord_flip()

bg.tfidf.affordability <- bigrams.affordability %>%
  separate(bigram, c("word1", "word2"), sep = " ") %>%
  filter(!word1 %in% stop_words$word) %>%
  filter(!word2 %in% stop_words$word) %>%
  mutate(bigram = paste(word1, word2)) %>%
  count(category, bigram, sort = TRUE) %>%
  bind_tf_idf(bigram, category, n) %>%
  arrange(desc(tf_idf))

bg.plot.normal <- bg.tfidf.affordability %>%
  mutate(bigram = factor(bigram, levels = rev(unique(bigram)))) %>% 
  group_by(category) %>% 
  top_n(15) %>% 
  ungroup %>%
  ggplot(aes(bigram, tf_idf, fill = category)) +
  geom_col(show.legend = FALSE) +
  labs(x = NULL, y = "tf-idf") +
  facet_wrap(~category, ncol = 2, scales = "free") +
  coord_flip()
ggsave("notebooks/images/subsidies-affordability-bigram-normal.png",
       bg.plot.normal, width=8, height=14, units="in", dpi=300)

# Load pre-trained GloVe embeddings from http://nlp.stanford.edu/data/glove.6B.zip
embeddings <- read_delim("data/raw/embeddings/glove.6B.100d.txt", delim=" ", 
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

# Use word2vec to find words most similar to "affordability"
# Get top bigrams involving those words

bigrams_separated.affordability <- bigrams.affordability %>%
  separate(bigram, c("word1", "word2"), sep = " ") %>%
  filter(!word1 %in% stop_words$word) %>%
  filter(!word2 %in% stop_words$word)

# Just a quick test on a smaller number of rows
words.affordability[1:100,] %>%
  filter(!(word %in% stop_words$word)) %>%
  mutate(simscore = similarity.scores(word, c("affordability", "cost", "price", "expensive")))

relevant_words = c("affordability", "cost", "price", "expensive")

# Computing the cosine similarity for the entire vocabulary is expensive, so
# we're going to reduce down to just the unique words and compute it once,
# then join the results back up with the regular bigrams dataframe
vocab = rbind(bigrams_separated.affordability %>% mutate(word = word1),
              bigrams_separated.affordability %>% mutate(word = word2)) %>%
          select(word) %>%
          distinct(word) %>%
          filter(!(word %in% stop_words$word)) %>%
          mutate(relevance = similarity.scores(word, relevant_words))


relevance.affordability <- bigrams_separated.affordability %>%
  filter(!(word1 %in% stop_words$word)) %>%
  filter(!(word2 %in% stop_words$word)) %>%
  left_join(vocab, by=c("word1" = "word")) %>%
  rename(relevance1 = relevance) %>%
  left_join(vocab, by=c("word2" = "word")) %>%
  rename(relevance2 = relevance)

# Because it's still a bit of a wait and easier to reload the csv
write_csv(relevance.affordability, "data/processed/relevance_affordability.csv")

# Two approaches... this one tries to order by maximum relevance first, and
# then by tf_idf
tfidf.relevance.affordability <- relevance.affordability %>%
  mutate(bigram = paste(word1, word2)) %>%
  mutate(max_relevance = pmax(relevance1, relevance2)) %>%
  count(category, max_relevance, bigram, sort = TRUE) %>%
  bind_tf_idf(bigram, category, n) %>%
  arrange(max_relevance, desc(tf_idf))

tfidf.relevance.affordability %>%
  mutate(bigram = factor(bigram, levels = rev(unique(bigram)))) %>% 
  group_by(category) %>% 
  top_n(15) %>% 
  ungroup %>%
  ggplot(aes(bigram, tf_idf, fill = category)) +
  geom_col(show.legend = FALSE) +
  labs(x = NULL, y = "tf-idf") +
  facet_wrap(~category, ncol = 2, scales = "free") +
  coord_flip()

# This approach simply uses max relevance to specify a cut off point.
# At least one of the words has to be above (in this case) 0.7. A cosine
# similarity of around 1 would be expected for the same or very similar words,
# while a similarity of -1 would be expected for opposite words. With 0.7,
# we'd expect some pretty close bigrams to our "relevant words", and indeed,
# this seems to be the case. Then we can use the tf_idf scores to get the more
# unique bigrams between the organization types.

bg.plot.relevance <- relevance.affordability %>%
  mutate(bigram = paste(word1, word2)) %>%
  mutate(max_relevance = pmax(relevance1, relevance2)) %>%
  filter(max_relevance > 0.7) %>%
  count(category, bigram, sort = TRUE) %>%
  bind_tf_idf(bigram, category, n) %>%
  arrange(desc(tf_idf)) %>%
  mutate(bigram = factor(bigram, levels = rev(unique(bigram)))) %>% 
  group_by(category) %>% 
  top_n(15) %>% 
  ungroup %>%
  ggplot(aes(bigram, tf_idf, fill = category)) +
  geom_col(show.legend = FALSE) +
  labs(x = NULL, y = "tf-idf") +
  facet_wrap(~category, ncol = 2, scales = "free") +
  coord_flip()
ggsave("notebooks/images/subsidies-affordability-bigram-with-relevance.png",
       bg.plot.relevance, width=8, height=20, units="in", dpi=300)
