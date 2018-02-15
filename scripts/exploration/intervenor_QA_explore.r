#Script analyzing the questions and answers that took place during CRTC consultation 2015-134
#Top part of script is general analysis 
#Bottom is for chord diagrams 

library(tidyverse)
library(plotly)
library(cowplot)
library(forcats)
library(chorddiag)
library(lubridate)
library(RColorBrewer)

interrogs <- read.csv("data/processed/intervenors_Q_A_raw_from_Middleton_group.csv")
#Filter out columns that aren't needed
interrogs_filter <- interrogs %>% select(3,4,5,6,8,11,14,17,21,24,28,31)
#Gather the columns - go from a messy to a tidy format; i.e. from a wide to a long df format for analysis
interrogs_gathered <- interrogs_filter %>% gather(key=Type, value=Date, c(-1,-2, -3,-4)) %>% 
  arrange(Questioner_reformat) %>% filter(Date != "")

#Fixing inconsistent date format and changing question Types
interrogs_gathered <- interrogs_gathered %>% mutate(Date = replace(Date, Date == "10-Dec-15", "2015/12/10"))
interrogs_gathered$Date <- as.Date(interrogs_gathered$Date)
interrogs_gathered <- interrogs_gathered %>% 
  mutate(Type = replace(Type, Type == "Interrogatory.Date", "Q.Phase1")) %>%
  mutate(Type = replace(Type, Type == "Follow.Up.1", "Q.Phase2")) %>%
  mutate(Type = replace(Type, Type == "Follow.up.2", "Q.Phase3")) %>%
  mutate(Type = replace(Type, Type == "Follow.up.3", "Q.Phase4")) %>%
  mutate(Type = replace(Type, Type == "Response.Date", "A.Phase1")) %>%
  mutate(Type = replace(Type, Type == "Reply.2", "A.Phase2")) %>%
  mutate(Type = replace(Type, Type == "Reply.3", "A.Phase3")) %>%
  mutate(Type = replace(Type, Type == "Reply.4", "A.Phase4")) 

q_list <- (c("Q.Phase1", "Q.Phase2", "Q.Phase3", "Q.Phase4"))
################################
#End data prep
################################
#Summary stats
#How many questions were asked  and in which rounds? 
interrogs_gathered %>% filter(Type %in% q_list) %>%
  group_by(Type) %>% dplyr::summarise(Qs_asked = n()) %>% arrange(desc(Qs_asked)) 

q_a_dates <- interrogs_gathered %>% group_by(Date) %>% dplyr::summarise(Sub_count = n()) %>% 
  ggplot(aes(x=Date, y=Sub_count)) + geom_point() + labs(x = "Date", y = "Number of submissions") +
  scale_x_date(date_labels ="%m-%Y", limits = c(dmy("01-08-2015"), dmy("01-03-2016")), date_breaks = "1 month") +
  ggtitle("Date all Q & As were submitted")

q_dates <- interrogs_gathered %>% filter(Type %in% q_list) %>%
  group_by(Date) %>% dplyr::summarise(Sub_count = n()) %>% 
  ggplot(aes(x=Date, y=Sub_count)) + geom_point() + labs(x = "Date", y = "Number of submissions") + 
  scale_x_date(date_labels ="%m-%Y", limits = c(dmy("01-08-2015"), dmy("01-03-2016")), date_breaks = "1 month") +
  ggtitle("Date questions were submitted")

r_dates <-   interrogs_gathered %>% filter(!(Type %in% q_list)) %>%
  group_by(Date) %>% dplyr::summarise(Sub_count = n()) %>% 
  ggplot(aes(x=Date, y=Sub_count)) + geom_point() + labs(x = "Date", y = "Number of submissions") + 
  scale_x_date(date_labels ="%m-%Y", limits = c(dmy("01-08-2015"), dmy("01-03-2016")), date_breaks = "1 month") + 
  ggtitle("Date answers were submitted") 

plot_grid(q_a_dates, q_dates, r_dates, align="h", ncol=1)

interrogs_gathered %>% group_by(Date, Type) %>% dplyr::summarise(Sub_count = n()) %>% 
  mutate(Type = fct_relevel(Type, "Q.Phase1")) %>% 
  mutate(Type = fct_relevel(Type, "Q.Phase2", after = 2)) %>% 
  mutate(Type = fct_relevel(Type, "Q.Phase3", after = 4)) %>% 
  mutate(Type = fct_relevel(Type, "Q.Phase4", after = 6)) %>% 
  ggplot(aes(x=Date, y=Sub_count)) + geom_point(aes(colour = factor(Type)), size=4) + labs(x = "Date", y = "Number of submissions") +
  scale_x_date(date_labels ="%m-%Y", limits = c(dmy("01-08-2015"), dmy("01-03-2016")), date_breaks = "1 month") +
  labs(colour = "Q&A Phase") + ggtitle("Date all Q & As were submitted") 

#Date questions and responses came in
dates_submitted.plot <- interrogs_gathered %>% group_by(Date) %>% 
  ggplot(aes(x=Date, y=Type)) + geom_point() + labs(x = "Date", y = "Submission Type") + scale_x_date(date_labels ="%m-%Y")

ggplotly(dates_submitted.plot)


#Count of how many Q & A there were per round and from whom
interrogs_gathered %>% filter(Type %in% q_list) %>%
  ggplot(aes(Type)) + geom_bar(aes(fill=Q_category)) +
  ggtitle("Question phases and count") + labs(x = "Question Round", fill = "Intervenor Category")
interrogs_gathered %>% filter(!(Type %in% q_list)) %>%
  filter(R_category != "") %>% 
  ggplot(aes(Type)) + geom_bar(aes(fill=R_category)) + 
  ggtitle("Response phases and count") + labs(x = "Question Round", fill = "Intervenor Category")

#Normalized for easier comparison of who particates in each round
q <- interrogs_gathered %>% filter(Type %in% q_list) %>%
  ggplot(aes(Type)) + geom_bar(aes(fill=Q_category), position = position_fill())
r <- interrogs_gathered %>% filter(!(Type %in% q_list)) %>%
  filter(R_category != "") %>% 
  ggplot(aes(Type)) + geom_bar(aes(fill=R_category), position = position_fill())

plot_grid(q, r)

ggplotly(q)
ggplotly(r)

#Which orgs ask most of the questions? 
interrogs_gathered %>% filter(Type %in% q_list) %>%
  group_by(Questioner_reformat, Q_category) %>% dplyr::summarise(Qs_asked = n()) %>% 
  arrange(desc(Qs_asked))

#Questions by category
interrogs_gathered %>% filter(Type %in% q_list) %>%
  group_by(Q_category) %>% dplyr::summarise(Qs_asked = n()) %>% arrange(desc(Qs_asked))

#Top askers for each category
interrogs_gathered %>% filter(Type %in% q_list) %>%
  group_by(Questioner_reformat, Q_category) %>% dplyr::summarise(Qs_asked = n()) %>%
  dplyr::ungroup() %>% group_by(Q_category) %>% dplyr::mutate(Category_total = sum(Qs_asked)) %>%
  filter(Qs_asked == max(Qs_asked)) %>% 
  arrange(desc(Qs_asked))

# Who has the largest imbalance on questioner and receiver side? 
questions_received <- interrogs_gathered %>% filter(Type %in% q_list) %>% group_by(Responder_reformat, R_category) %>% dplyr::summarise(Qs_received = n()) %>% arrange(desc(Qs_received))
questions_asked <- interrogs_gathered %>% filter(Type %in% q_list) %>% group_by(Questioner_reformat, Q_category) %>% dplyr::summarise(Qs_asked = n()) %>% arrange(desc(Qs_asked))

Qs_asked_received <- full_join(questions_received, questions_asked, by=c("Responder_reformat"="Questioner_reformat")) %>% replace_na(list(Qs_received = 0, Qs_asked = 0)) %>%
  mutate(delta = Qs_asked - Qs_received) %>% arrange(desc(delta)) %>% mutate(org_category = ifelse(is.na(R_category), as.character(Q_category), as.character(R_category))) %>% 
  select(-Q_category, -R_category)


Qs_asked_received %>% group_by(org_category) %>% summarise(total_delta = sum(delta)) %>% arrange(desc(total_delta))

#Largest imbalance on received side
tail(Qs_asked_received, n=10)
#Largest imbalance on questioner side
head(Qs_asked_received, n=10)

Qs_asked_received %>% group_by(org_category) %>% summarise(total_delta = sum(delta)) %>% arrange(desc(total_delta))


#What rounds do intervenors ask questions?
interrogs_gathered %>% filter(Type %in% q_list) %>% 
  ggplot(aes(Questioner_reformat)) + geom_bar(aes(fill=fct_rev(Type)), position = position_stack()) + 
  theme(axis.text = element_text(angle = 90, vjust = 0.9, hjust = 1)) +
  labs(fill = "Question Round", x = "")

interrogs_gathered %>% filter(Type %in% q_list) %>% 
  ggplot(aes(Responder_reformat)) + geom_bar(aes(fill=fct_rev(Type)), position = position_stack()) + 
  theme(axis.text = element_text(angle = 90, vjust = 0.9, hjust = 1)) +
  labs(fill = "Question Round", x = "")





################################
################################
# Chord diagrams 
################################
################################

chord_prep <- function(df){
  df$to <-  droplevels(df$to)
  df$from <-  droplevels(df$from)
  lf <- levels(df$from)
  lt <- levels(df$to)
  new_levels <- sort(union(lf,lt))
  df$from = factor(df$from,levels =new_levels)
  df$to = factor(df$to,levels =new_levels)
  df_complete <- df %>% tidyr::complete(from, to, fill=list(value = 0))
  
  df.mat <- as.data.frame(df_complete) %>% spread(key=to, value=value, fill=0)
  r_names <- df.mat$from
  df.mat <- df.mat %>% select(-from)
  row.names(df.mat) <- r_names
  df.mat <- as.matrix(df.mat)
  return(df.mat)
}

chord_prep_asked <- function(df){
  df$to <-  droplevels(df$to)
  df$from <-  droplevels(df$from)
  lf <- levels(df$from)
  lt <- levels(df$to)
  new_levels <- sort(union(lf,lt))
  df$from = factor(df$from,levels =new_levels)
  df$to = factor(df$to,levels =new_levels)
  df_complete <- df %>% tidyr::complete(from, to, fill=list(value = 0))
  
  df.mat <- as.data.frame(df_complete) %>% spread(key=from, value=value, fill=0)
  r_names <- df.mat$to
  df.mat <- df.mat %>% select(-to)
  row.names(df.mat) <- r_names
  df.mat <- as.matrix(df.mat)
  return(df.mat)
}

chord_pre_prep <- function(count_input){
  names(count_input) <- c("from", "to", "value")
  count_input <- data.frame(count_input) %>% filter(to !="")
  count.df <- as.data.frame(count_input)
  return(count.df)
}

get_cols <- function(count.df, col_list){
  count.df$from <- droplevels(count.df$from)
  count.df$to <- droplevels(count.df$to)
  lf <- levels(count.df$from)
  lt <- levels(count.df$to)
  org_levels <- data.frame(sort(union(lf,lt)))
  colnames(org_levels) <- "categories"
  plot_colours <- dplyr::left_join(org_levels, col_list, by=c("categories" = "all_levels")) %>% 
    select(cols)
  return(plot_colours)
}

individual_chord <- function(df, type=""){
  df <- chord_pre_prep(df)
  if(type == "asked"){
    df.mat <- chord_prep_asked(df)  
  } else {
    df.mat <- chord_prep(df)
  }
  cdiag <- chorddiag(df.mat, groupnameFontsize = 10, groupnamePadding = 20, tickInterval = 5)
  return(cdiag)
}

category_chord <- function(interrog_count, colourdict, type=""){
  chord_input <- chord_pre_prep(interrog_count)
  plot_cols <- get_cols(chord_input, colourdict)
  if(type == "asked"){
    df.mat <- chord_prep_asked(chord_input)  
  } else {
    df.mat <- chord_prep(chord_input)
  }
  chorddiag(df.mat, groupnameFontsize = 10, groupnamePadding = 20, groupColors = plot_cols$cols, tickInterval = 5)
}

#Set up all colours: 
lq <- levels(interrogs_gathered$Q_category)
lr <- levels(interrogs_gathered$R_category)
all_levels <- sort(union(lq,lr))

cols <- brewer.pal(n = 12, name = 'Set3')

colourdict <- cbind(all_levels, cols)
colourdict <- data.frame(colourdict)


#####################
### 
#Look at all questions together & the different phases: 
interrog_count <- interrogs_gathered %>% filter(Type %in% q_list) %>% group_by(Q_category, R_category) %>% dplyr::summarise(count= n())
category_chord(interrog_count, colourdict)
#Rounds 1-4: 
interrog_count_rd1 <- interrogs_gathered %>% filter(Type %in% "Q.Phase1") %>% group_by(Q_category, R_category) %>% dplyr::summarise(count= n())
category_chord(interrog_count_rd1, colourdict)

interrog_count_rd2 <- interrogs_gathered %>% filter(Type %in% "Q.Phase2") %>% group_by(Q_category, R_category) %>% dplyr::summarise(count= n())
category_chord(interrog_count_rd2, colourdict)

interrog_count_rd3 <- interrogs_gathered %>% filter(Type %in% "Q.Phase3") %>% group_by(Q_category, R_category) %>% dplyr::summarise(count= n())
category_chord(interrog_count_rd3, colourdict)

interrog_count_rd4 <- interrogs_gathered %>% filter(Type %in% "Q.Phase4") %>% group_by(Q_category, R_category) %>% dplyr::summarise(count= n())
category_chord(interrog_count_rd4, colourdict)

### 
#Look at who being asked together & the different phases: 
interrog_count <- interrogs_gathered %>% filter(Type %in% q_list) %>% group_by(Q_category, R_category) %>% dplyr::summarise(count= n())
category_chord(interrog_count, colourdict, type="asked")
#Rounds 1-4: 
interrog_count_rd1 <- interrogs_gathered %>% filter(Type %in% "Q.Phase1") %>% group_by(Q_category, R_category) %>% dplyr::summarise(count= n())
category_chord(interrog_count_rd1, colourdict, type="asked")

interrog_count_rd2 <- interrogs_gathered %>% filter(Type %in% "Q.Phase2") %>% group_by(Q_category, R_category) %>% dplyr::summarise(count= n())
category_chord(interrog_count_rd2, colourdict, type="asked")

interrog_count_rd3 <- interrogs_gathered %>% filter(Type %in% "Q.Phase3") %>% group_by(Q_category, R_category) %>% dplyr::summarise(count= n())
category_chord(interrog_count_rd3, colourdict, type="asked")

interrog_count_rd4 <- interrogs_gathered %>% filter(Type %in% "Q.Phase4") %>% group_by(Q_category, R_category) %>% dplyr::summarise(count= n())
category_chord(interrog_count_rd4, colourdict, type="asked")


#NB: Can change labels under groupNames to make them fit the graphic better
chorddiag(all_Q_A.mat, groupnameFontsize = 10, groupnamePadding = 20, 
          groupNames = c("Advocacy orgs","Chamber of commerce",
                         "Consumer advocacy orgs", "Government", "Individual", "#N/A",
                         "Network op: Cable co", "Network op: other",
                         "Network op: Telco Incumbents", "Other", "Small incumbents"))


###################
# Questions by individual organizations
interrog_individual <- interrogs_gathered %>% filter(Type %in% q_list) %>% group_by(Questioner_reformat, Responder_reformat) %>% dplyr::summarise(count= n())
individual_chord(interrog_individual)

interrog_individ_rd1 <- interrogs_gathered %>% filter(Type %in% "Q.Phase1") %>% group_by(Questioner_reformat, Responder_reformat) %>% dplyr::summarise(count= n())
individual_chord(interrog_individ_rd1)

interrog_individ_rd2 <- interrogs_gathered %>% filter(Type %in% "Q.Phase2") %>% group_by(Questioner_reformat, Responder_reformat) %>% dplyr::summarise(count= n())
individual_chord(interrog_individ_rd2)

interrog_individ_rd3 <- interrogs_gathered %>% filter(Type %in% "Q.Phase3") %>% group_by(Questioner_reformat, Responder_reformat) %>% dplyr::summarise(count= n())
individual_chord(interrog_individ_rd3)

interrog_individ_rd4 <- interrogs_gathered %>% filter(Type %in% "Q.Phase4") %>% group_by(Questioner_reformat, Responder_reformat) %>% dplyr::summarise(count= n())
individual_chord(interrog_individ_rd4)


# Investigate which orgs got asked in each round
interrog_individual_asked <- interrogs_gathered %>% filter(Type %in% q_list) %>% group_by(Questioner_reformat, Responder_reformat) %>% dplyr::summarise(count= n())
individual_chord(interrog_individual_asked, type="asked")

interrog_individ_rd1_asked <- interrogs_gathered %>% filter(Type %in% "Q.Phase1") %>% group_by(Questioner_reformat, Responder_reformat) %>% dplyr::summarise(count= n())
individual_chord(interrog_individ_rd1_asked, type="asked")

interrog_individ_rd2_asked <- interrogs_gathered %>% filter(Type %in% "Q.Phase2") %>% group_by(Questioner_reformat, Responder_reformat) %>% dplyr::summarise(count= n())
individual_chord(interrog_individ_rd2_asked, type="asked")

interrog_individ_rd3_asked <- interrogs_gathered %>% filter(Type %in% "Q.Phase3") %>% group_by(Questioner_reformat, Responder_reformat) %>% dplyr::summarise(count= n())
individual_chord(interrog_individ_rd3_asked, type="asked")

interrog_individ_rd4_asked <- interrogs_gathered %>% filter(Type %in% "Q.Phase4") %>% group_by(Questioner_reformat, Responder_reformat) %>% dplyr::summarise(count= n())
individual_chord(interrog_individ_rd4_asked, type="asked")