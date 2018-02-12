library(RNeo4j)
library(dplyr)
library(ggplot2)
library(cld2)
library(stringr)

graph <- startGraph("http://localhost:7474/db/data/", username = "neo4j", password = "password")

q.docs_per_category <- "
  MATCH (o:Organization)-->(d:Document) 
  RETURN o.category AS category, COUNT(DISTINCT d.sha256) AS n
"

df.docs_per_category <- cypher(graph, q.docs_per_category)
plot.doc_submissions_per_organization_type <- df.docs_per_category %>% 
  mutate(category = reorder(category, n)) %>%
  ggplot(aes(x=category, y=n)) + 
  geom_bar(stat="identity") + 
  coord_flip() +
  xlab("Organization type") +
  ylab("Number of submissions") +
  theme(panel.background = element_blank()) +
  ggtitle("Document Submissions per Organization Type")
ggsave("notebooks/images/document_submissions_per_organization_type.png",
       plot.doc_submissions_per_organization_type)

q.doc_contents <- "
  MATCH (o:Organization)-->(d:Document) 
  RETURN DISTINCT o.category AS category, d.name AS name, 
         d.sha256 AS sha256, d.content AS content
"

df.doc_contents <- cypher(graph, q.doc_contents)
df.doc_lang <- df.doc_contents %>%
  mutate(lang = detect_language(content)) %>%
  select(-content)

# Uggh... ggplot really makes pie charts hard to produce. It was a disasterously
# bad idea to even try... but I like ggplot and this seemed like one of those few
# instances where a pie chart was appropriate. But if it wasn't the legend labels
# getting messed up, it was the percent labels being put on the wrong slices, etc.
#
# plot.doc_submissions_by_lang.pie <- df.doc_lang %>%
#  mutate(lang = ifelse(lang %in% c('en', 'fr'), lang, NA)) %>%
#  mutate(lang = ifelse(is.na(lang), "unknown", lang)) %>%
#  count(lang) %>%
#  mutate(proportion = round(n/sum(n) * 100, 2)) %>%
#  mutate(lang = reorder(lang, proportion)) %>%
#  mutate(midpoint = cumsum(proportion) - proportion/2) %>%
#  mutate(proportion_labels = paste0(proportion, "%")) %>%
#  ggplot(aes(x="", y=proportion, fill=lang)) +
#    geom_bar(width=1, stat="identity") +
#    coord_polar("y") +
#    scale_fill_brewer(palette="Blues", labels=c("French", "Unknown", "English")) +
#    geom_text(aes(x=1.3, y = midpoint + 1.5, label = proportion_labels)) +
#    theme_void() +
#    labs(fill = "Language") +
#    ggtitle("Percent of Document Submissions by Language")
#ggsave("notebooks/images/document_submissions_by_language_pie.png",
#       plot.doc_submissions_by_lang.pie)

plot.doc_submissions_by_lang <- df.doc_lang %>%
  mutate(lang = ifelse(lang %in% c('en', 'fr'), lang, NA)) %>%
  mutate(lang = ifelse(is.na(lang), "unknown", lang)) %>%
  count(lang) %>%
  mutate(proportion = round(n/sum(n) * 100, 2)) %>%
  mutate(midpoint = cumsum(proportion) - proportion/2) %>%
  mutate(proportion_labels = paste0(proportion, "%")) %>%
  ggplot(aes(x="", y=proportion, fill=lang)) +
  geom_bar(stat="identity", position = "stack") +
  scale_fill_brewer(palette="Blues", labels=c("English", "French", "Unknown")) +
  theme(panel.background = element_blank(), legend.position = "bottom") +
  labs(fill = "Language") +
  coord_flip() +
  xlab("") +
  ylab("% of submissions") +
  ggtitle("Percent of Document Submissions by Language")
ggsave("notebooks/images/document_submissions_by_language.png",
       plot.doc_submissions_by_lang)

plot.doc_lang_categories <- df.doc_lang %>%
  mutate(lang = ifelse(lang %in% c('en', 'fr'), lang, NA)) %>%
  mutate(lang = ifelse(is.na(lang), "unknown", lang)) %>%
  count(category, lang) %>%
  mutate(category = reorder(category, n)) %>%
  ggplot(aes(x=category, y=n, fill=lang)) +
  geom_bar(stat="identity", position = "fill") +
  scale_fill_brewer(palette="Blues", labels=c("English", "French", "Unknown")) +
  theme(panel.background = element_blank(), legend.position = "bottom", 
        axis.ticks.y = element_blank()) +
  labs(fill = "Language") +
  coord_flip() +
  xlab("") +
  ylab("Submission proportion") +
  ggtitle("Document Submissions by Language per Organization Type")
ggsave("notebooks/images/document_submissions_by_language_per_organization_type.png",
       plot.doc_lang_categories)

q.submissions <- "
  MATCH (o:Organization)-[r*2]->(s:Submission)-->(d:Document)
  RETURN DISTINCT s.name AS name, o.name AS organization, o.category AS category,
                  COUNT(DISTINCT d.sha256) AS n, ID(s) AS id
"
df.submissions <- cypher(graph, q.submissions)
plot.submissions_by_stage <- df.submissions %>%
  mutate(name = str_trim(name)) %>%
  mutate(name = factor(name, levels = rev(c("Intervention", "Interventions Phase 2",
                                        "Responses to requests for information - 14 July 2015",
                                        "Further Comments", "Final Submission", "Final Replies")))) %>%
  ggplot(aes(x=name)) +
  geom_bar() +
  coord_flip() +
  xlab("") +
  ylab("") +
  theme(panel.background = element_blank(), axis.ticks.y = element_blank()) +
  ggtitle("Submissions by Stage")
ggsave("notebooks/images/submissions_by_stage.png",
       plot.submissions_by_stage)


q.open_media <- "
MATCH (d:Document { sha256:'996cdc9c830fc7f76fd8dae382916fd38906e776d092363ac0f5fbcd679a9ad0'})<--(subdoc:Document)<--(p:Person)
RETURN p.name AS person, p.location AS location, p.postal AS postal_code, 
       subdoc.content AS content
"
df.open_media <- cypher(graph, q.open_media)
plot.open_media.top_locations <- df.open_media %>%
  count(location) %>%
  top_n(20) %>%
  mutate(location = reorder(location, n)) %>%
  ggplot(aes(x=location, y=n)) +
  geom_bar(stat="identity") +
  coord_flip() +
  xlab("") +
  ylab("") +
  theme(panel.background = element_blank(), axis.ticks.y = element_blank()) +
  ggtitle("Top Locations for Non-Form Letter Open Media Submissions")
ggsave("notebooks/images/top_locations_for_open_media_submissions.png",
       plot.open_media.top_locations)
