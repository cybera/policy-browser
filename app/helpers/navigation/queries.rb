require "sinatra/base"
require "helpers/basic"

module Sinatra
  module NavigationHelpers
    class Queries
      TEMPLATE = "navigation/queries"

      def initialize(params)
        @params = params
      end

      def data
        queries = graph_query("""
          MATCH (q:Query)
          WITH q
          MATCH (d:Document)--(:Segment)--(q)
          RETURN q.str AS str, COUNT(DISTINCT d) AS hits, ID(q) AS id
        """)
        puts queries
        { :queries => queries }
      end
    end
  end
end