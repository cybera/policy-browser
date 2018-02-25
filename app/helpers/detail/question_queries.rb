module Sinatra
  module DetailHelpers
    class QuestionQueries < DetailHelper
      def data
        queries = graph_query("""
          MATCH (q:Query)
          OPTIONAL MATCH (question:Question)<-[r:ABOUT]-(q)
          WHERE ID(question) = $question
          WITH q, COALESCE(question.ref, false) AS linked, COALESCE(r.quality, 0.0) AS quality
          MATCH (d:Document)--(:Segment)--(q)
          RETURN q.str AS str, COUNT(DISTINCT d) AS hits, ID(q) AS id, linked, quality
        """, question:params[:question].to_i)

        question = graph_query("""
          MATCH (q:Question)
          WHERE ID(q) = $question
          RETURN q.content AS content, q.ref AS ref, ID(q) AS id
        """, question:params[:question].to_i)

        { 
          queries: queries.sort_by { |q| [ q['linked'] ? 0 : 1, q['id'] ] }, 
          question: question.first
        }
      end
    end
  end
end