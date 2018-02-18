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

q.mbps <- "
MATCH (question:Question { ref: $qref })
MATCH (query:Query)-[:ABOUT]-(question)
MATCH (query)<--(segment:Segment)-[:SEGMENT_OF]->(doc:Document)
MATCH (org:Organization)-[:SUBMITTED]->(doc)
RETURN segment.content AS content, org.category as category, 
org.name as organization
"

# solr queries (should be added via bin/transform):
#
# content:("target speed" && "mbps")
# content:(("should be" OR "should set") && "mbps")
# content:("greater than" && "mbps")

mbps.regex = regex(paste("
  ((upload|download).{1,15}?)?      # does upload or download occur within 15 chars?",
  # fairly lenient mbps string matching
  paste("(", float_or_int.pattern, "[^\\d]{1,4}?)?",float_or_int.pattern, "\\s*?mbps"),
  "(.{1,5}?(up|down))?               # any up/down indicator
", sep="\n"), comments=TRUE, ignore_case=TRUE)

teststrs = c("5 Mbps upload / 6 Mbps download",
             "target speed of 5/1 mbps and stuff",
             "2015), wherein TELUS states: The Commission should not take any action if its 5/1 Mbps",
             "2014 Communications Monitoring Report, broadband service at a 5 Mbps down")
extract_mbps_up(str_extract_all(teststrs, mbps.regex))

float_or_int.pattern = "(\\.\\d+|\\d+(\\.\\d+)?)"

slash_separated_mbps.regex = regex(paste(
  float_or_int.pattern,
  "[\\s/]+                   # slashes or spaces",
  float_or_int.pattern,
  "  .*",
sep="\n"), comments=TRUE, ignore_case=TRUE)

single_mbps.pattern = paste(float_or_int.pattern, "\\s*mbps\\s*")
single_mbps_down.regex = regex(paste(single_mbps.pattern, "down"), ignore_case=TRUE)
single_mbps_up.regex = regex(paste(single_mbps.pattern, "up"), ignore_case=TRUE)

extract_mbps_down <- function(mbps_str) {
  tmp1 <- str_match(mbps_str, slash_separated_mbps_regex)[,2]
  tmp2 <- str_match(mbps_str, single_mbps_down.regex)[,1]
  tmp <- ifelse(is.na(tmp1), tmp2, tmp1)
  tmp <- str_extract(tmp, float_or_int.pattern)
  as.numeric(tmp)
}

extract_mbps_up <- function(mbps_str) {
  tmp1 <- str_match(mbps_str, slash_separated_mbps_regex)[,4]
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

df.mbps <- cypher(graph, q.mbps, qref="Q4-1")
df.mbps.extract <- df.mbps %>%
  mutate(mbps_str = str_extract_all(content, mbps.regex)) %>%
  unnest(mbps_str) %>%
  mutate(mbps_down = extract_mbps_down(mbps_str)) %>%
  mutate(mbps_up = extract_mbps_up(mbps_str)) %>%
  mutate(should_index=get_should_index(content)) %>%
  mutate(mbps_index=get_mbps_index(content, should_index, mbps_str)) %>%
  mutate(should_score=1/(mbps_index - should_index))

plot.mbps <- function(df, mbps_colname, mbps_label="Mbps", threshold=NA) {
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
  
  
  ggplot(df.should_score) +
    geom_jitter(data=df.no_should_score, aes(x=category, y = mbps_col), alpha=0.4) +
    geom_jitter(aes(x=category, y=mbps_col, color=should_score), alpha=0.7) +
    scale_colour_gradient2(low="yellow", mid="orange", high = "red", midpoint=0.07) +
    labs(y=mbps_label, x="", color="'Should' score") +
    coord_flip() +
    theme(panel.background = element_blank(), axis.ticks.y = element_blank())
}  

(plot.mbps.down.500 <- plot.mbps(df.mbps.extract, "mbps_down", "Mbps down", 500))
(plot.mbps.down.50 <- plot.mbps(df.mbps.extract, "mbps_down", "Mbps down", 50))
(plot.mbps.up.500 <- plot.mbps(df.mbps.extract, "mbps_up", "Mbps up", 500))
(plot.mbps.up.50 <- plot.mbps(df.mbps.extract, "mbps_up", "Mbps up", 50))

ggsave("notebooks/images/mbps-down-500.png", plot.mbps.down.500)
ggsave("notebooks/images/mbps-down-50.png", plot.mbps.down.50)
ggsave("notebooks/images/mbps-up-500.png", plot.mbps.up.500)
ggsave("notebooks/images/mbps-up-50.png", plot.mbps.up.50)