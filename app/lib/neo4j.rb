require "date"
require "timeout"
require "socket"
require "neo4j-core"
require 'neo4j/core/cypher_session/adaptors/http'
require 'neo4j/core/cypher_session/adaptors/bolt'

module Neo4JQueries
  mattr_accessor :neo4j_db

  class << self
    def connect(username, password, hostname="neo4j", port=7687)
      connect_string = "bolt://#{username}:#{password}@#{hostname}:#{port}"
      bolt_adaptor = Neo4j::Core::CypherSession::Adaptors::Bolt.new(connect_string, timeout: 30)
      Neo4JQueries.neo4j_db = Neo4j::Core::CypherSession.new(bolt_adaptor)
    end
  end

  def graph_query(query, *params)
    self.neo4j_db.query(query, *params)
  end
end
