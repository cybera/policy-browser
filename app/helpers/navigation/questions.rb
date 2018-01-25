module Sinatra
  module NavigationHelpers
    class Questions < NavigationHelper
      def data
        questions = graph_query("""
          MATCH (q:Question)
          RETURN ID(q) AS id, q.ref as ref, q.content AS content
        """)

        { questions: questions }
      end
    end
  end
end