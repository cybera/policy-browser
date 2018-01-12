require "sinatra/base"
require "helpers/basic"

module Sinatra
  module ViewHelpers
    class Matches
      TEMPLATE = "view/matches"

      def initialize(params)
        @params = params
      end

      def data
        if @params[:query]
          segments = graph_query("""
            MATCH (q:Query)
            MATCH (o:Organization)-[r1:ACTING_AS]->(:Participant)-[:PARTICIPATES_IN]->(sub:Submission)
            MATCH (sub)-[r2:CONTAINING]->(d:Document)
            MATCH (q)<-[r4:MATCHES]-(s:Segment)-[r3:SEGMENT_OF]->(d)
            WHERE ID(q) = $query
            RETURN q.str as query, o.name as organization, d.name as document,s.hlcontent as hlcontent
          """, query:@params[:query].to_i)
          { :documents => segments.group_by { |s| s['document'] } }
        else
          { :documents => [] }
        end
      end
    end
  end
end