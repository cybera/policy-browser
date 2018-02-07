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
          MATCH (o:Organization) 
          WHERE NOT (o)-[:ALIAS_OF]->()
          RETURN COUNT(o)
        """).rows.first[0]
      end

      def count_observed_organizations
        graph_query("""
          #{related_organization_clause}
          RETURN COUNT(DISTINCT o)
        """, question:params[:question].to_i).rows.first[0]
      end

      def missing_organizations
        graph_query("""
          #{related_organization_clause(true)}
          RETURN DISTINCT o.name AS name
        """, question:params[:question].to_i).map do |row|
          row['name']
        end.sort
      end

      def related_organization_clause(missing=false)
        missing_str = missing ? "NOT " : ""

        """
          MATCH (o:Organization)
          MATCH (q:Question)<--(query:Query)<--(s:Segment)-[:SEGMENT_OF]->(d:Document)
          WHERE ID(q) = $question AND
            #{missing_str}(o)<-[:ALIAS_OF*0..1]-()-[:SUBMITTED]->(d) AND
            NOT (o)-[:ALIAS_OF]->()
        """
      end
    end
  end
end