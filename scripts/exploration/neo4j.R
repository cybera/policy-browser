library(RNeo4j)
library(yaml)
neo4j.config <- yaml.load_file("config/neo4j.yml")
graph <- startGraph("http://localhost:7474/db/data/", username = neo4j.config$username, password = neo4j.config$password)
