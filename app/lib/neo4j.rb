require "date"
require "timeout"
require "socket"
require "neo4j-core"
require 'neo4j/core/cypher_session/adaptors/http'
require 'neo4j/core/cypher_session/adaptors/bolt'

bolt_adaptor = Neo4j::Core::CypherSession::Adaptors::Bolt.new("bolt://neo4j:password@neo4j:7687", timeout: 10)
@@neo4jDB = Neo4j::Core::CypherSession.new(bolt_adaptor)

def graph_query(query, *params)
  @@neo4jDB.query(query, *params)
end
