module Sinatra
  module DetailHelpers
    class Matches < DetailHelper
      def data
        if params[:query]
          segments = graph_query("""
            MATCH (q:Query)
            MATCH (o:Organization)<-[:ALIAS_OF*0..1]-()-[r1:ACTING_AS]->(participant:Participant)
            MATCH (participant)-[:PARTICIPATES_IN]->(sub:Submission)
            MATCH (sub)-[r2:CONTAINING]->(d:Document)
            MATCH (q)<-[r4:MATCHES]-(s:Segment)-[r3:SEGMENT_OF]->(d)
            WHERE ID(q) = $query AND
              NOT (o)-[:ALIAS_OF]->()
            RETURN q.str as query, o.name as organization, d.name as document,s.hlcontent as hlcontent, s.content as content
          """, query:params[:query].to_i)
          { documents: segments.group_by { |s| s[:document] } }
        else
          { documents: [] }
        end
      end
    end
  end
end