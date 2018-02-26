library(RNeo4j)
library(dplyr)
library(tidytext)
library(widyr)
library(tidyverse)
library(ggplot2)
library(igraph)
library(ggraph)
library(tidyr)
library(reshape2)
library(knitr)

# This is an R script that runs sentiment analysis over the answers to questions. 


source("scripts/exploration/neo4j.R")

scaler <- function(x)
{  
    if(is.na(x))
    {
        return(NA)
    }
    if(x >0)
    {   
      
        return(x-0.5 )
    }
    if(x < 0)
    {   
        
        return(x+0.5 )

    }

}

scale <- function(list)
{   
    r = sapply(list, function(x) scaler(x))
    return(r)
}
# Function for scripting the creation of sentiment! 
# hooray 
QuerySentiment <- function(query,graph)
{

    data_raw <- cypher(graph, query)
    results <- dplyr::mutate(data_raw, id=as.integer(rownames(data_raw)))
    tibbled_data <- as_tibble(results)

 
    # Symbols are dumb. 
    cleaned_text <- tibbled_data  %>%
        filter(str_detect(Segment, "^[^>]+[A-Za-z\\d]"))

    use_words <- cleaned_text %>%
         unnest_tokens(word, Segment) %>%
         filter(str_detect(word, "[a-z']$"),
         !word %in% stop_words$word)

    words_by_org <- use_words %>%
        count(Organization, word, sort = TRUE) %>%
        ungroup()


    afinn <- sentiments %>%
         filter(lexicon == 'AFINN')%>%
         select(word, afinn = score)

    pre_scored <- words_by_org %>%
        left_join(afinn, by = 'word') %>%
        mutate(afinn=scale(afinn))

    # SO this was probably a stupid way to do it, but I did it anyways so if 
    # anyone reads this please berate me and let me know of a better way
    scored <- pre_scored%>%
        group_by(Organization)%>%
        summarise(afinn_score = list(afinn),
                  mean_afinn=mean(afinn,na.rm=T), 
                  sd_afinn=sd(afinn,na.rm=T), 
                  len_afinn=length(afinn[!is.na(afinn)]))

   
    return(scored)
}

# 2242

Mr.County <- function(data)
{   
    return(length(data))
}



PlotMyQuery <-function(queries, files, titles, graph, print_tables=FALSE)
{
    
for(i in 1:length(queries))
    { 
       print(c("Beginning query",i))
       # Some things may not return data, that's what this try is here for 
       sentiments<- tryCatch(
        {
            QuerySentiment(queries[i], graph)

        },
        error = function(e)
        {   print(c(queries[i], ' Had no data, skipping'))
            return(c())
        }
        )


       if(length(sentiments) > 0)
       {    
            names = sentiments$Organization
            
            affin_dat <- sentiments$afinn_score
            # Remove NA so we can put it back in later...
            # this could be improved if I was better at R
            l <-lapply(affin_dat, function(x) c(x[!is.na(x)]))
            max.length <- max(sapply(l, length))
            l <- lapply(l, function(v) { c(v, rep(NA, max.length-length(v)))})
            
            df <-do.call(rbind, l)
            df <- t(df)
            colnames(df) <- names
            melted <- melt(df, id.vars="names")

            ggplot(melted, aes(x=value,y=value, fill=value)) +
            geom_bar(stat='summary', fun.y=Mr.County, position="dodge") +
            facet_wrap(~Var2, 
                scales = "free", 
                ncol=3, 
                labeller=labeller(Var2=label_wrap_gen(35))) +
            theme(legend.position='none', 
                  axis.text=element_text(size=12), 
                  axis.title=element_text(size=14, face="bold"), 
                  title=element_text(size=20, face="bold"),
                  strip.text = element_text(size=12)) +
            labs(x = "", title = titles[i], y= "Sentiment Counts", x = "Sentiment Value") +
             scale_x_continuous(limits = c(-4.5,4.5),breaks= scales::pretty_breaks(n=9))
            ggsave(save[i], width=12, height=12)

            # if you want sumarry stats for git
            if(print_tables == TRUE)
            {
                printer <- list(list(sentiments$Organization), 
                                lapply(list(sentiments$mean_afinn), round, 2), 
                                lapply(list(sentiments$sd_afinn), round, 2),
                                list(sentiments$len_afinn))
                
                frame <- as.data.frame(matrix(unlist(printer), nrow=length(unlist(printer[1]))))
                names(frame) <- c("Organization", "Sentiment_Mean", "Sentiment_SD", "Number_of_points")

                print(save[i])

                print(kable(frame))
            }
            
        }
        rm(sentiments)
    }
}


# YOu can probably remove the where not id.... for where r.method = 'doc2vec-MonteCarlo' etc

queries <- c(
            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT ID(Qe) = 144132
            AND Q.ref='Q1'
            RETURN s.content AS Segment, o.category as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT ID(Qe) = 144132
            AND Q.ref='Q1'
            AND o.category = 'Network operator: other'
            RETURN s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT ID(Qe) = 144132
            AND Q.ref='Q1'
            AND o.category = 'Government'
            RETURN s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT ID(Qe) = 144132
            AND Q.ref='Q1'
            AND o.category = 'Advocacy organizations'
            RETURN s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT ID(Qe) = 144132
            AND Q.ref='Q1'
            AND o.category = 'Other'
            RETURN s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT ID(Qe) = 144132
            AND Q.ref='Q1'
            AND o.category = 'Network operator - Cable companies'
            RETURN s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT ID(Qe) = 144132
            AND Q.ref='Q1'
            AND o.category = 'Network operator: Telecom Incumbents'
            RETURN s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
             WHERE NOT ID(Qe) = 144132
            AND Q.ref='Q1'
            AND o.category = 'Consumer advocacy organizations'
            RETURN s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
             WHERE NOT ID(Qe) = 144132
            AND Q.ref='Q1'
            AND o.category = 'Small incumbents'
            RETURN s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT ID(Qe) = 144132
            AND Q.ref='Q1'
            AND o.category = 'Rural/remote community association'
            RETURN s.content AS Segment, o.name as Organization")

titles = c("AFINN solr Affordability All Organizations", "AFINN solr Affordability Network Op Other",
           "AFINN solr Affordability Government",
           "AFINN solr Affordability Advocacy Groups","AFINN solr Affordability Other",
           "AFINN solr Affordability Cable Companies","AFINN solr Affordability Telecom Companies",
           "AFINN solr Affordability ConsumerAdv", "AFINN solr Affordability Small Incumbents",
           "AFINN solr Affordability Rural Community")

save = c("AllOrgsAffordsolr.png", "OtherNetworkOpAfford.png",
         "GovernmentAffordsolr.png", "AdvocacyOrgsAffordsolr.png",
         "OtherAffordsolr.png", "CableAffordsolr.png",
         "TelecomAffordsolr.png",
         "ConsumerAdvAffordsolr.png", "SmallIncAffordsolr.png",
         "RuralComAffordsolr.png")

#PlotMyQuery(queries,save, titles,graph)

q()


queries <- c(
            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT ID(Qe) = 140612
            AND Q.ref='Q9'
            
            RETURN s.content AS Segment, o.category as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT ID(Qe) = 140612
            AND Q.ref='Q9'
            
            AND o.category = 'Network operator: other'
            RETURN s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT ID(Qe) = 140612
            AND Q.ref='Q9'
            
            AND o.category = 'Government'
            RETURN s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT ID(Qe) = 140612
            AND Q.ref='Q9'
            
            AND o.category = 'Advocacy organizations'
            RETURN s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT ID(Qe) = 140612
            AND Q.ref='Q9'
            
            AND o.category = 'Other'
            RETURN s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT ID(Qe) = 140612
            AND Q.ref='Q9'
            
            AND o.category = 'Network operator - Cable companies'
            RETURN s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
            WHERE NOT ID(Qe) = 140612
            AND Q.ref='Q9'
            
            AND o.category = 'Network operator: Telecom Incumbents'
            RETURN s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
             WHERE NOT ID(Qe) = 140612
            AND Q.ref='Q9'
            
            AND o.category = 'Consumer advocacy organizations'
            RETURN s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
             WHERE NOT ID(Qe) = 140612
            AND Q.ref='Q9'
            
            AND o.category = 'Small incumbents'
            RETURN s.content AS Segment, o.name as Organization",

            "MATCH (Q:Question)<-[:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
             WHERE NOT ID(Qe) = 140612
            AND Q.ref='Q9'
             
             AND o.category = 'Rural/remote community association'
            RETURN s.content AS Segment, o.name as Organization")

titles = c("AFINN solr BTS All Organizations", "AFINN solr BTS Network Op Other",
           "AFINN solr BTS Government",
           "AFINN solr BTS Advocacy Groups","AFINN solr BTS Other",
           "AFINN solr BTS Cable Companies","AFINN solr BTS Telecom Companies",
           "AFINN solr BTS ConsumerAdv", "AFINN solr VTS Small Incumbents",
           "AFINN solr BTS Rural Community")

save = c("AllOrgsBTSsolr.png", "OtherNetworkBTSsolr.png",
         "GovernmentBTSsolr.png", "AdvocacyOrgsBTSsolr.png",
         "OtherBTSsolr.png", "CableBTSsolr.png",
         "TelecomBTSsolr.png",
         "ConsumerAdvBTSsolr.png", "SmallIncBTSsolr.png",
         "RuralComBTSsolr.png")


PlotMyQuery(queries,save, titles,graph, print_tables=TRUE)




    
