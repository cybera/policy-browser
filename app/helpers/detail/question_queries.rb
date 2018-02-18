module Sinatra
  module DetailHelpers
    class QuestionQueries < DetailHelper
      def data
        queries = graph_query("""
          MATCH (q:Query)
          OPTIONAL MATCH (question:Question)<--(q)
          WHERE ID(question) = $question
          WITH q, EXISTS(question.ref) AS linked
          MATCH (d:Document)--(:Segment)--(q)
          RETURN q.str AS str, COUNT(DISTINCT d) AS hits, ID(q) AS id, linked
        """, question:params[:question].to_i)

        question = graph_query("""
          MATCH (q:Question)
          WHERE ID(q) = $question
          RETURN q.content AS content, q.ref AS ref, ID(q) AS id
        """, question:params[:question].to_i)

        { 
          queries: queries.sort_by { |q| [ q['linked'] ? 0 : 1, q['str'] ] }, 
          question: question.first
        }
      end
    end
  end
end