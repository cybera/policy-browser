module Sinatra
  module DetailHelpers
    class QuestionInfo < DetailHelper
      def data
        question_id = params[:question]
        results = cache_get("question-segments.#{question_id}") { self.related_data.map { |r| r.to_h.stringify_keys } }

        orgs = results.group_by { |r| r['organization'] }
        categories = results.group_by { |r| r['category'] }
        queries = results.group_by { |r| r['query'] }

        vars = {}
        vars[:organization_count] = count_all_organizations
        vars[:observed_organization_count] = results.map { |r| r['organization'] }.uniq.count
        vars[:missing_organizations] = missing_organizations
        vars[:categories] = categories
        vars[:queries] = queries
        vars[:organizations] = orgs 

        question = graph_query("""
          MATCH (q:Question)
          WHERE ID(q) = $question
          RETURN q.content AS content, q.ref AS ref, ID(q) AS id
        """, question:params[:question].to_i)
        vars[:question] = question.first

        vars
      end

      def count_all_organizations
        graph_query("""
          MATCH (org:Organization) 
          WHERE NOT (org)-[:ALIAS_OF]->()
          RETURN COUNT(org)
        """).rows.first[0]
      end

      def count_observed_organizations
        graph_query("""
          #{related_organization_clause}
          RETURN COUNT(DISTINCT org)
        """, question:params[:question].to_i).rows.first[0]
      end

      def missing_organizations
        graph_query("""
          #{related_organization_clause(true)}
          RETURN DISTINCT org.name AS name
        """, question:params[:question].to_i).map do |row|
          row['name']
        end.sort
      end

      def related_organization_clause(missing=false)
        missing_str = missing ? "NOT " : ""
        """
          MATCH (question:Question)
          WHERE ID(question) = $question
          WITH question
          MATCH (org:Organization)
          WHERE NOT (org)-[:ALIAS_OF]->() AND
                #{missing_str} (org)<-[:ALIAS_OF*0..1]-(:Organization)-->(:Document)<--(:Segment)-->(:Query)-->(question)
        """
      end

      def related_data
        graph_query("""
          MATCH (question:Question)
          MATCH (query:Query)-[r:ABOUT]->(question)
          MATCH (query)<--(segment:Segment)-[:SEGMENT_OF]->(doc:Document)
          MATCH (org:Organization)<-[:ALIAS_OF*0..1]-(:Organization)-[:SUBMITTED]->(doc)
          WHERE ID(question) = $question AND
                NOT (org)-[:ALIAS_OF]->()
          RETURN ID(segment) AS segment_id, query.str as query, org.category as category, 
          org.name as organization, COALESCE(r.quality, 0.2) AS quality
        """, question:params[:question].to_i)
      end
    end
  end
end