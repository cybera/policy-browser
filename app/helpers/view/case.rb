require "sinatra/base"
require "helpers/basic"

module Sinatra
  module ViewHelpers
    class Case
      TEMPLATE = "view/case"

      def initialize(params)
        @params = params
      end

      def data
        submission_text = ""

        if @params[:submission]
          documents = graph_query("""
            MATCH (submission:Submission)-[:CONTAINING]->(document:Document)
            WHERE ID(submission) = $id
            RETURN document.name, document.content, document.type
          """, id:@params[:submission].to_i)

          cases = documents.map do |doc|
            doc_name = doc["document.name"]
            { doc_name: doc_name, content: doc["document.content"] }
          end

          { :cases => cases }
        else
          { :cases => [] }
        end
      end
    end
  end
end