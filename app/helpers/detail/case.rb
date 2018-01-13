require "sinatra/base"
require "helpers/basic"

module Sinatra
  module DetailHelpers
    class Case < DetailHelper
      def initialize(params)
        @params = params
      end

      def data
        if @params[:submission]
          documents = graph_query("""
            MATCH (submission:Submission)-[:CONTAINING]->(document:Document)
            WHERE ID(submission) = $id
            RETURN document.name AS name, document.content AS content, 
                   document.type AS type
          """, id:@params[:submission].to_i)

          { :documents => documents }
        else
          { :documents => [] }
        end
      end
    end
  end
end