require "irb/completion"

$:.unshift File.expand_path("../../../app", __FILE__)

require "active_support"
require "lib/neo4j"
require "lib/solr"
require "lib/config"

Neo4JQueries::connect(Config::Neo4J.username, Config::Neo4J.password)
include Neo4JQueries
SolrQueries::connect()
include SolrQueries