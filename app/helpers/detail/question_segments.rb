module Sinatra
  module DetailHelpers
    class QuestionSegments < DetailHelper
      def data
        results = self.related_data
        orgs = results.group_by { |r| r['organization'] }
        categories = results.group_by { |r| r['category'] }
        queries = results.group_by { |r| r['query'] }

        quality_org_segment_ids = orgs.map do |name,records| 
          records.sort_by { |v| -v[:quality] }[0...5].map { |record| record[:segment_id]}
        end.flatten
        quality_org_segments = self.related_segment_texts(quality_org_segment_ids)

        quality_category_segment_ids = categories.map do |name,records| 
          records.sort_by { |v| -v[:quality] }[0...5].map { |record| record[:segment_id]}
        end.flatten
        quality_category_segments = self.related_segment_texts(quality_category_segment_ids)

        vars = {}
        vars[:categories] = quality_category_segments.group_by { |r| r['category'] }
        vars[:organizations] = quality_org_segments.group_by { |r| r['organization'] }

        question = graph_query("""
          MATCH (q:Question)
          WHERE ID(q) = $question
          RETURN q.content AS content, q.ref AS ref, ID(q) AS id
        """, question:params[:question].to_i)
        vars[:question] = question.first

        vars
      end

      def related_data
        graph_query("""
          MATCH (question:Question)
          MATCH (query:Query)-[r:ABOUT]-(question)
          MATCH (query)<--(segment:Segment)-[:SEGMENT_OF]->(doc:Document)
          MATCH (org:Organization)<-[:ALIAS_OF*0..1]-()-[:SUBMITTED]->(doc)
          WHERE ID(question) = $question AND
                NOT (org)-[:ALIAS_OF]->()
          RETURN ID(segment) AS segment_id, query.str as query, org.category as category, 
          org.name as organization, COALESCE(r.quality, 0.2) AS quality
        """, question:params[:question].to_i)
      end

      def related_segment_texts(segment_ids)
        graph_query("""
          MATCH (question:Question)
          MATCH (query:Query)-[r:ABOUT]-(question)
          MATCH (query)<--(segment:Segment)-[:SEGMENT_OF]->(doc:Document)
          MATCH (org:Organization)<-[:ALIAS_OF*0..1]-()-[:SUBMITTED]->(doc)
          WHERE ID(question) = $question AND
                NOT (org)-[:ALIAS_OF]->() AND
                ID(segment) IN $segment_ids
          RETURN segment.content AS content, query.str as query, org.category as category, 
          org.name as organization, COALESCE(r.quality, 0.2) AS quality
        """, question:params[:question].to_i, segment_ids:segment_ids)
      end
    end
  end
end