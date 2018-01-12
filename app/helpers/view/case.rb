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

            content = doc["document.content"]
            paragraphs = content.split(/\n+/).select do |para| 
              para.strip != ""
            end
            
            avg_length = paragraphs.map { |p| p.length }.reduce(:+).to_f / paragraphs.length
            paragraphs = paragraphs.slice_when do |prevpara, nextpara|
              prevpara.strip =~ /.*?[.?!;:]$/ || prevpara.length < 0.8 * avg_length
            end.map { |parablock| parablock.join("") }

            content_html = paragraphs.chunk do | para |
              para.length < 0.8 * avg_length
            end.map do | short, parachunk | 
              short ? parachunk.join("<br/>") : parachunk.map { |para| "<p>#{para}</p>" }
            end.join("\n")

            { doc_name: doc_name, content_html: content_html }
          end

          { :cases => cases }
        else
          { :cases => [] }
        end
      end
    end
  end
end