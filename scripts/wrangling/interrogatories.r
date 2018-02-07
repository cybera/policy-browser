library(tidyverse)
library(circlize)
library(forcats)
library(chorddiag)

##For chorddiag() function, need a square matrix, with the same levels in the same order
#Since there are more levels in "to" column, use that as the complete list of levels
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

interrogs <- read.csv("data/raw/interrogs.csv")
#Filter out columns that aren't needed
interrogs_filter <- interrogs %>% select(3,4,5,6,8,11,14,17,21,24)
#Gather the columns - go from a messy to a tidy format; i.e. from a wide to a long df format for analysis
interrogs_gathered <- interrogs_filter %>% gather(key=Type, value=Date, c(-1,-2, -3,-4)) %>% 
  arrange(Questioner_reformat) %>% filter(Date != "")

#####################
#Count all entries, including all questions and answers, filter out empty rows
interrog_count <- interrogs_gathered %>% group_by(Q_category, R_category) %>% dplyr::summarise(count= n())
interrog_count <- interrog_count %>% filter(R_category !="")
names(interrog_count) <- c("from", "to", "value")
interrog_count.df <- as.data.frame(interrog_count)

all_Q_A.mat <- chord_prep(interrog_count.df)
chorddiag(all_Q_A.mat, groupnameFontsize = 10, groupnamePadding = 20)

#NB: Can change labels under groupNames to make them fit the graphic better
chorddiag(all_Q_A.mat, groupnameFontsize = 10, groupnamePadding = 20, 
          groupNames = c("Advocacy orgs","Chamber of commerce",
          "Consumer advocacy orgs", "Government", "Individual", "#N/A",
          "Network op: Cable co", "Network op: other",
          "Network op: Telco Incumbents", "Other", "Small incumbents"))

#####################
#Look at who asked questions:
interrogs_gathered_Qs <- interrogs_gathered %>% filter(Type %in% c("Follow.Up.1", "Follow.up.2", "Interrogatory.Date"))
interrog_count <- interrogs_gathered_Qs %>% group_by(Q_category, R_category) %>% dplyr::summarise(count= n())
interrog_count <- interrog_count %>% filter(R_category !="")
names(interrog_count) <- c("from", "to", "value")
interrog_count.df <- as.data.frame(interrog_count)

only_Q.mat <- chord_prep(interrog_count.df)
chorddiag(only_Q.mat, groupnameFontsize = 10, groupnamePadding = 20)

#####################
#Look at who provided answers: 
interrogs_gathered_As <- interrogs_gathered %>% filter(!(Type %in% c("Follow.Up.1", "Follow.up.2", "Interrogatory.Date")))
interrog_count <- interrogs_gathered_As %>% group_by(Q_category, R_category) %>% dplyr::summarise(count= n())
interrog_count <- interrog_count %>% filter(R_category !="")
names(interrog_count) <- c("from", "to", "value")
interrog_count.df <- as.data.frame(interrog_count)

only_Q.mat <- chord_prep(interrog_count.df)
chorddiag(only_Q.mat, groupnameFontsize = 10, groupnamePadding = 20)
