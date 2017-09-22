# setwd("your/hey-cira/project/root") before running

library(xml2)
library(purrr)
library(stringr)
library(ggplot2)
library(dplyr)

str = readr::read_file_raw("data/raw/220700.2015-66.2287027(1d0_j01!).html")
doc = read_html(str, encoding="iso-8859-1")

a = xml_find_all(doc, "//div[contains(text(),'Comment')]/following::div[1]")
xml_text(a)
b = xml_find_all(doc, "//div[contains(text(),'Address')]/*")
xml_text(b)

get_location <- function(fpath) {
  xpath_query = "//div[contains(text(),'Address')]/*"
  str = readr::read_file_raw(fpath)
  doc = read_html(str, encoding="iso-8859-1")
  address_node = xml_find_all(doc, xpath_query)
  xml_text(address_node)
}

get_comment <- function(fpath) {
  xpath_query = "//div[contains(text(),'Comment')]/following::div[1]"
  str = readr::read_file_raw(fpath)
  doc = read_html(str, encoding="iso-8859-1")
  comment_node = xml_find_all(doc, xpath_query)
  xml_text(comment_node)
}

html_files = dir("data/raw", pattern=".html", full.names = TRUE)

province_list = c("AB","BC","MB","NB","NL","NS","NT","NU","ON",
                  "PE","QC","SK","YT")
province_regex = paste0(".*?(",
                        paste(province_list, collapse="|"),
                        ").*")
locations = map(html_files, get_location)
provinces = str_replace(locations, 
                        province_regex, 
                        "\\1")
df = data.frame(province=provinces)

df %>% 
  filter(province %in% province_list) %>%
  ggplot() + geom_bar(aes(x=province), stat="count")
