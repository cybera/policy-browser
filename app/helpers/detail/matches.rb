module Sinatra
  module DetailHelpers
    class Matches < DetailHelper
      def data
        if params[:query]
          segments = graph_query("""
            MATCH (q:Query)<-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)
            WHERE ID(q) = $query
            WITH q,s,d
            OPTIONAL MATCH (o:Organization)<-[:ALIAS_OF*0..1]-()-->(:Participant)-->(sub:Submission)-[*0..1]->(d)
            WHERE NOT (o)-[:ALIAS_OF]->()
            RETURN q.str AS query, d.name AS document, o.name AS organization, 
                   COALESCE(s.hlcontent_obfuscated, s.hlcontent) AS hlcontent, 
                   COALESCE(s.content_obfuscated, s.content) AS content
          """, query:params[:query].to_i)
          { documents: segments.group_by { |s| s[:document] } }
        else
          { documents: [] }
        end
      end
    end
  end
end