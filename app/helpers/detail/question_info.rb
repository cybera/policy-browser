module Sinatra
  module DetailHelpers
    class QuestionInfo < DetailHelper
      def data
        vars = {}
        vars[:organization_count] = count_all_organizations
        vars[:observed_organization_count] = count_observed_organizations
        vars[:missing_organizations] = missing_organizations

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
          MATCH (org:Organization)<-[:ALIAS_OF*0..1]-()-[:SUBMITTED]->(doc:Document)
          MATCH (question:Question)<--(query:Query)
          WHERE 
            NOT (org)-[:ALIAS_OF]->() AND
            ID(question) = $question AND
            #{missing_str}(query)<--(:Segment)-->(doc)<-[:SUBMITTED]-()-[:ALIAS_OF*0..1]->(org)
        """
      end
    end
  end
end