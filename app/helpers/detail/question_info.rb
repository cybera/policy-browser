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
        graph_query("MATCH (o:Organization) RETURN COUNT(o)").rows.first[0]
      end

      def count_observed_organizations
        graph_query("""
          #{related_organization_clause}
          RETURN COUNT(DISTINCT o)
        """, question:params[:question].to_i).rows.first[0]
      end

      def missing_organizations
        []

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
          MATCH (s:Segment)-->(obs:Observation)
          MATCH (obs)-->(q:Question)
          MATCH (s)-[:SEGMENT_OF]->(d:Document)
          WHERE ID(q) = $question AND
            #{missing_str}(o)-[:SUBMITTED]->(d)
        """
      end
    end
  end
end