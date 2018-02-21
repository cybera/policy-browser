library(RNeo4j)
library(dplyr)
library(tidytext)
library(tidyverse)
library(ggplot2)
library(tidyr)
library(readr)
library(data.table)
library(text2vec)
library(stringr)

graph <- startGraph("http://localhost:7474/db/data/", username = "neo4j", password = "password")

########################
#Functions setup
extract_mbps_down <- function(mbps_str) {
  tmp1 <- str_match(mbps_str, slash_separated_mbps.regex)[,2]
  tmp2 <- str_match(mbps_str, single_mbps_down.regex)[,1]
  tmp <- ifelse(is.na(tmp1), tmp2, tmp1)
  tmp <- str_extract(tmp, float_or_int.pattern)
  as.numeric(tmp)
}

extract_mbps_up <- function(mbps_str) {
  tmp1 <- str_match(mbps_str, slash_separated_mbps.regex)[,4]
  tmp2 <- str_match(mbps_str, single_mbps_up.regex)[,1]
  tmp <- ifelse(is.na(tmp1), tmp2, tmp1)
  tmp <- str_extract(tmp, float_or_int.pattern)
  as.numeric(tmp)
}

get_should_index <- function(content) {
  tmp <- regexpr('(should|must|needs to|target)', content)
  tmp <- ifelse(tmp == -1, NA, tmp)
  tmp
}

get_mbps_index <- function(content, should_index, mbps_str) {
  tmp <- str_locate(substring(content, should_index), coll(mbps_str))[,'start']  
  tmp <- tmp + should_index
  tmp
}

plot.mbps <- function(df, mbps_colname, mbps_label="Mbps", threshold=NA, remove_dups=TRUE) {
  df$mbps_col <- df[[mbps_colname]]
  if(is.na(threshold)) {
    threshold <- max(df$mbps_col, na.rm=TRUE)
  }
  
  df <- df %>%
    filter(mbps_col < threshold) %>%
    mutate(should_score = ifelse(should_score < 0.05, NA, should_score))
  df.no_should_score <- df %>%
    filter(is.na(should_score))
  df.should_score <- df %>%
    filter(!is.na(should_score))
  if(remove_dups == TRUE){
    df.should_score <- df.should_score %>% arrange(desc(should_score)) %>% 
      distinct(content, .keep_all = TRUE) 
    df.no_should_score <- df.no_should_score %>% arrange(desc(should_score)) %>% 
      distinct(content, .keep_all = TRUE) 
  }
  
  
  ggplot(df.should_score) +
    geom_jitter(data=df.no_should_score, aes(x=category, y = mbps_col), alpha=0.4) +
    geom_jitter(aes(x=category, y=mbps_col, color=should_score), alpha=0.7) +
    scale_colour_gradient2(low="yellow", mid="orange", high = "red", midpoint=0.07) +
    labs(y=mbps_label, x="", color="'Should' score") +
    coord_flip() +
    theme(panel.background = element_blank(), axis.ticks.y = element_blank())
}  
########################

########################
#Queries

q.mbps <- "
MATCH (question:Question { ref: $qref })
MATCH (query:Query)-[:ABOUT]-(question)
MATCH (query)<--(segment:Segment)-[:SEGMENT_OF]->(doc:Document)
MATCH (org:Organization)-[:SUBMITTED]->(doc)
RETURN segment.content AS content, org.category as category, 
org.name as organization
"
q.mbps.date <- "
MATCH (question:Question { ref: $qref })
MATCH (query:Query)-[:ABOUT]-(question)
MATCH (query)<--(segment:Segment)-[:SEGMENT_OF]->(doc:Document)<--(s:Submission)
MATCH (org:Organization)-[:SUBMITTED]->(doc)
RETURN segment.content AS content, org.category as category, 
org.name as organization, s.name AS submission_name, s.date_arrived AS date
"

q.mbps.html <- "
MATCH (question:Question { ref: $qref })
MATCH (query:Query)-[:ABOUT]-(question)
MATCH (query)<--(segment:Segment)-[:SEGMENT_OF]->(doc:Document)<--(s:Submission)
MATCH (person:Person)-->(:Participant { role: 'Client' } )-->(s)
RETURN segment.content AS content, 
person.name as person, s.name AS submission_name, s.date_arrived AS date
"
q.mbps.test <- "
MATCH (question:Question { ref: $qref})
MATCH (query:Query)-[:ABOUT]-(question)
MATCH (query)<--(segment:Segment)-[:SEGMENT_OF]->(doc:Document)<--(s:Submission)
MATCH path=(person:Person)-[]-(p:Participant)-[]-(:Submission)-[]-(doc:Document {type:'html'})
WHERE NOT (:Organization)-[]-(p)
RETURN segment.content AS content, 
person.name as person, s.name AS submission_name, s.date_arrived AS date
"

q.mbps.openmedia <- "
MATCH (question:Question { ref: $qref })
MATCH (query:Query)-[:ABOUT]-(question)
MATCH (query)<--(segment:Segment)-[:SEGMENT_OF]->(doc:Document)
MATCH (person:Person)-[:SUBMITTED]->(doc)
RETURN segment.content AS content, person.name as person, person.location as location
"
########################

# solr queries (should be added via bin/transform):
#
# content:("target speed" && "mbps")
# content:(("should be" OR "should set") && "mbps")
# content:("greater than" && "mbps")

########################
#Regex
float_or_int.pattern = "(\\.\\d+|\\d+(\\.\\d+)?)"

mbps.regex = stringr::regex(paste("
  ((upload|download).{1,15}?)?      # does upload or download occur within 15 chars?",
  # fairly lenient mbps string matching
  paste("(", float_or_int.pattern, "[^\\d]{1,4}?)?",float_or_int.pattern, "\\s*?mbps"),
  "(.{1,5}?(up|down))?               # any up/down indicator
", sep="\n"), comments=TRUE, ignore_case=TRUE)

slash_separated_mbps.regex = stringr::regex(paste(
  float_or_int.pattern,
  "[\\s/]+                   # slashes or spaces",
  float_or_int.pattern,
  "  .*",
  sep="\n"), comments=TRUE, ignore_case=TRUE)

single_mbps.pattern = paste(float_or_int.pattern, "\\s*mbps\\s*")
single_mbps_down.regex = stringr::regex(paste(single_mbps.pattern, "down"), ignore_case=TRUE)
single_mbps_up.regex = stringr::regex(paste(single_mbps.pattern, "up"), ignore_case=TRUE)
########################

########################
#Test, Data extraction, and plotting

#Test case to see if we can extract upload speeds: 
teststrs = c("5 Mbps upload / 6 Mbps download",
             "target speed of 5/1 mbps and stuff",
             "2015), wherein TELUS states: The Commission should not take any action if its 5/1 Mbps",
             "2014 Communications Monitoring Report, broadband service at a 5 Mbps down",
             "I want faster internet. Something like 20Mbps download and 10Mbps upload.")
extract_mbps_up(str_extract_all(teststrs, mbps.regex))


df.mbps <- cypher(graph, q.mbps, qref="Q4-1")
df.mbps.extract <- df.mbps %>%
  mutate(mbps_str = str_extract_all(content, mbps.regex)) %>%
  unnest(mbps_str) %>%
  mutate(mbps_down = extract_mbps_down(mbps_str)) %>%
  mutate(mbps_up = extract_mbps_up(mbps_str)) %>%
  mutate(should_index=get_should_index(content)) %>%
  mutate(mbps_index=get_mbps_index(content, should_index, mbps_str)) %>%
  mutate(should_score=1/(mbps_index - should_index))

(plot.mbps.down.500 <- plot.mbps(df.mbps.extract, "mbps_down", "Mbps down", 500))
(plot.mbps.down.50 <- plot.mbps(df.mbps.extract, "mbps_down", "Mbps down", 50))
(plot.mbps.up.500 <- plot.mbps(df.mbps.extract, "mbps_up", "Mbps up", 500))
(plot.mbps.up.50 <- plot.mbps(df.mbps.extract, "mbps_up", "Mbps up", 50))

ggsave("notebooks/images/mbps-down-500.png", plot.mbps.down.500, remove_dups=TRUE)
ggsave("notebooks/images/mbps-down-50.png", plot.mbps.down.50, remove_dups=TRUE)
ggsave("notebooks/images/mbps-up-500.png", plot.mbps.up.500, remove_dups=TRUE)
ggsave("notebooks/images/mbps-up-50.png", plot.mbps.up.50, remove_dups=TRUE)
########################

########################
#Looking only at intervention docs

df.mbps.dates <- cypher(graph, q.mbps.date, qref="Q4-1")
df.mbps.intervention <- df.mbps.dates %>% 
  filter(submission_name %in% c("Intervention", "Interventions", "Intervention ")) 

df.mbps.intervention.extract <- 
  df.mbps.intervention %>%
  mutate(mbps_str = str_extract_all(content, mbps.regex)) %>%
  unnest(mbps_str) %>%
  mutate(mbps_down = extract_mbps_down(mbps_str)) %>%
  mutate(mbps_up = extract_mbps_up(mbps_str)) %>%
  mutate(should_index=get_should_index(content)) %>%
  mutate(mbps_index=get_mbps_index(content, should_index, mbps_str)) %>%
  mutate(should_score=1/(mbps_index - should_index))

plot.mbps(df.mbps.intervention.extract, "mbps_down", "Mbps down", 50, remove_dups = TRUE)
plot.mbps(df.mbps.intervention.extract, "mbps_up", "Mbps up", 50, remove_dups = TRUE)

#Looking at datapoints with should score >0.05
df.mbps.intervention.extract %>% arrange(desc(should_score)) %>% 
  distinct(content, .keep_all = TRUE) %>% filter((should_score > 0.05) & (mbps_up > 0))
df.mbps.intervention.extract %>% arrange(desc(should_score)) %>% 
  distinct(content, .keep_all = TRUE) %>% filter((should_score > 0.05) & (mbps_down > 0))
########################

########################
#Adding in openmedia docs

df.mbps.openmedia <- cypher(graph, q.mbps.openmedia, qref="Q4-1")
df.mbps.html <- cypher(graph, q.mbps.html, qref="Q4-1")
df.mbps.test <- cypher(graph, q.mbps.test, qref="Q4-1")
########################

########################
# Evaluation - trying to score how well the automated speed detection works
# This is a work in progress
# Pulling segments from the entire pool of segments (even if no up or download speeds were identified)
set.seed(1000)
evaluate_samples <- sample_n(df.mbps, 20)
#Manually assessed scores of text segments
#NA means no statement was made wrt what the basic speeds should be
down_true <- c(NA, 5, NA, NA, NA, NA, 25, NA, NA, NA, 5, NA, NA, NA, NA, NA, 5, 25, NA, NA)
up_true <- c(NA, 1, NA, NA, NA, NA, 3, NA, NA, NA, 1, NA, NA, NA, NA, NA, 1, 10, NA, NA)
evaluate_samples <- cbind(evaluate_samples, down_true)
evaluate_samples <- cbind(evaluate_samples, up_true)

test_against_samples <- function(df=df.mbps.extract){
  df.nodupe <- df %>% arrange(desc(should_score)) %>% 
    distinct(content, .keep_all = TRUE) 
  
  df.with.scored <- evaluate_samples %>% left_join(df.nodupe, by="content") %>%
  mutate(correct_answer_down = ifelse((down_true == mbps_down) | 
                                        (is.na(down_true) & is.na(mbps_down)), 1, 0)) %>%
  mutate(correct_answer_up = ifelse((up_true == mbps_up) | 
                                      (is.na(up_true) & is.na(mbps_up)), 1, 0)) %>%
  select(down_true, mbps_down, correct_answer_down, up_true, mbps_up, correct_answer_up) %>%
  mutate(correct_answer_down = ifelse(is.na(correct_answer_down), 0, correct_answer_down)) %>%
  mutate(correct_answer_up = ifelse(is.na(correct_answer_up), 0, correct_answer_up))
  print(df.with.scored)
  
  a <- c(mean(df.with.scored$correct_answer_down), mean(df.with.scored$correct_answer_up))
  return(a)
}

test_against_samples(df.mbps.extract)

#Only pulling from segments with upload and download speeds identified
set.seed(1000)
eval_download_scored_only <- df.mbps.extract %>% arrange(desc(should_score)) %>% 
  distinct(content, .keep_all = TRUE) %>% filter(mbps_down >= 0)
eval_upload_scored_only <- df.mbps.extract %>% arrange(desc(should_score)) %>% 
  distinct(content, .keep_all = TRUE) %>% filter(mbps_up >= 0)

eval_download_scored_only <- sample_n(eval_download_scored_only, 10)
eval_upload_scored_only <- sample_n(eval_upload_scored_only, 10)

eval_scored_only <- rbind(eval_download_scored_only, eval_upload_scored_only)

