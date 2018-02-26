require "date"
require "timeout"
require "socket"
require "neo4j-core"
require 'neo4j/core/cypher_session/adaptors/http'
require 'neo4j/core/cypher_session/adaptors/bolt'

module Neo4JQueries
  mattr_accessor :neo4j_db
  mattr_accessor :connect_string

  class << self
    def connect(username, password, hostname="neo4j", port=7474)
      Neo4JQueries.connect_string = "http://#{username}:#{password}@#{hostname}:#{port}"
      http_adaptor = Neo4j::Core::CypherSession::Adaptors::HTTP.new(Neo4JQueries.connect_string, timeout: 30)
      Neo4JQueries.neo4j_db = Neo4j::Core::CypherSession.new(http_adaptor)
    end
  end

  def graph_query(query, *params)
    begin
      self.neo4j_db.query(query, *params)
    rescue RuntimeError => e
      puts e
      http_adaptor = Neo4j::Core::CypherSession::Adaptors::HTTP.new(Neo4JQueries.connect_string, timeout: 30)
      self.neo4j_db = Neo4j::Core::CypherSession.new(http_adaptor)
    end
  end
end
