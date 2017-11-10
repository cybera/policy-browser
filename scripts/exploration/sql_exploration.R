#Script connects to sqlite db set up in data.db for exploration of metadata table
library("RSQLite")
library("DBI")
library(tidyverse)
library(plotly)

# connect to the sqlite file - ensure the correct session path has been set or adjust the dbname
con = dbConnect(RSQLite::SQLite(), dbname="docs.db")
#con_old = dbConnect(RSQLite::SQLite(), dbname="docs_old.db")
# get a list of all tables
#[1] "docentities" "docmeta"     "docs"        "segmentmeta" "segments"  
alltables = dbListTables(con)

# get the each table as a data.frame
docmeta = dbGetQuery( con,'select * from docmeta' )
#docmeta_old = dbGetQuery( con_old,'select * from docmeta' )
docentities = dbGetQuery( con,'select * from docentities' )
docs = dbGetQuery( con,'select * from docs' )
segmentmeta = dbGetQuery( con,'select * from segmentmeta' )
segments = dbGetQuery( con,'select * from segments' )

# count the entries in metadata table
docmeta_count = dbGetQuery( con,'select count(*) from docmeta' )

##Create a column with case number for each row
#First extract a dicitonary of doc ids and case numbers
case_numbers <- docmeta %>% filter(key == "public_process_number") %>% select(docid, value)
#Remove duplicates
case_numbers <- distinct(case_numbers)
docmeta_wcase <- left_join(docmeta, case_numbers, by = "docid")
#Filter based on case number of interest 
docmeta_case2015134 <- docmeta_wcase %>% filter(value.y == "2015-134")
#The above is redundant if it was filtered during scraping

#Do some basic analysis
docmeta_case2015134$key <- as.factor(docmeta_case2015134$key)
docmeta_case2015134$docid <- as.factor(docmeta_case2015134$docid)
table(docmeta_case2015134$key)
ggplot(docmeta_case2015134, aes(x=key)) + geom_histogram(stat="count") + theme(axis.text.x=element_text(angle=45,hjust=1))
#The above could contain duplicate metadata items from different sources - filter to ensure only unique entries are present
docmeta_case2015134 %>% distinct(key, docid, value.x) %>% 
  ggplot(aes(x=key)) + geom_histogram(stat="count") + theme(axis.text.x=element_text(angle=45,hjust=1)) +
  labs(title = "Number of entries for each metadata category in 2015-134")

#Ugly - not really useful with too many docs
docmeta_case2015134 %>% distinct(key, docid, value.x) %>% 
  ggplot(aes(x=docid)) + geom_histogram(stat="count")  + theme(axis.text.x=element_text(angle=45,hjust=1, size=rel(0.75))) +
  labs(title = "Metadata items in eachdocument in 2015-134")

docmeta_15134_unique <- docmeta_case2015134 %>% distinct(key, docid, value.x)

docmeta_15134_unique %>% count(value.x, sort=TRUE)
docmeta_15134_unique %>% group_by(key) %>% count(sort=TRUE)

#How many docs arrived on each date
docmeta_15134_unique %>% filter(key == "date_arrived") %>% group_by(value.x) %>% count(sort=TRUE)
date_arrived <- docmeta_15134_unique %>% filter(key == "date_arrived")
date_arrived$value.x <- as.Date(date_arrived$value.x)

date_arrived %>% group_by(value.x) %>% count() %>% 
  ggplot(aes(x=value.x, y=n)) + geom_point() + labs(x = "Date", y = "Number of submissions") + scale_x_date(date_labels ="%m-%Y")

date_arrived %>% group_by(value.x) %>%  ggplot(aes(x=value.x, y=as.integer(docid))) + geom_point() + 
  labs(x = "Date", y = "DocID #") + scale_x_date(date_labels ="%m-%Y")

#Which were submitted by companies and how many?
on_behalf_of_count <- docmeta_15134_unique %>% filter(key == "client_information:on_behalf_of_company") %>% 
  group_by(value.x) %>% summarise(total = n()) %>% arrange(desc(total))
on_behalf_of_count$value.x <- factor(on_behalf_of_count$value.x, levels = rev(on_behalf_of_count$value.x))
ggplot(on_behalf_of_count[1:50,], aes(total, value.x)) + geom_point()

#Create index of companies 
companies <- docmeta %>% filter(key == "client_information:on_behalf_of_company") %>% select(docid, value)
companies$docid <- as.factor(companies$docid)
date_company <- left_join(date_arrived, companies, by = "docid") 
date_company <- date_company %>% mutate(company = ifelse(!is.na(value), "Company", "No company"))
date_company %>% group_by(value.x) %>%  ggplot(aes(x=value.x, y=as.integer(docid), colour=company)) + geom_point() + 
  +     labs(x = "Date", y = "DocID #") + scale_x_date(date_labels ="%m-%Y")


#### Other SQL queries from an online sample
# find entries of the DB from the last week
p3 = dbGetQuery(con, "SELECT population WHERE DATE(timeStamp) < DATE('now', 'weekday 0', '-7 days')")
#Clear the results of the last query
dbClearResult(p3)
#Select population with managerial type of job
p4 = dbGetQuery(con, "select * from populationtable where jobdescription like '%manager%'")

