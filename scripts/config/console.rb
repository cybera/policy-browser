require "irb/completion"

$:.unshift File.expand_path("../../../app", __FILE__)

require "active_support"
require "lib/neo4j"
require "lib/solr"

Neo4JQueries::connect("neo4j", "password")
include Neo4JQueries
SolrQueries::connect()
include SolrQueries