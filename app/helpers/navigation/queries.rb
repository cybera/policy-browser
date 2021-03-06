module Sinatra
  module NavigationHelpers
    class Queries < NavigationHelper
      def data
        queries = graph_query("""
          MATCH (q:Query)
          WITH q
          MATCH (d:Document)--(:Segment)--(q)
          RETURN q.str AS str, COUNT(DISTINCT d) AS hits, ID(q) AS id
        """)

        { queries: queries }
      end
    end
  end
end