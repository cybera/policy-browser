module Sinatra
  module NavigationHelpers
    class Organizations < NavigationHelper
      def data
        submissions = graph_query("""
          MATCH (o:Organization)<-[:ALIAS_OF*0..1]-()-[:SUBMITTED]->(d:Document)
          MATCH (d)<--(s:Submission)<-[:INVOLVING]-(i:Intervention)
          MATCH (i)-[:SUBMITTED_TO]->(p:PublicProcess { ppn: $ppn })
          WHERE EXISTS(s.date_arrived) AND
            NOT (o)-[:ALIAS_OF]->()
          RETURN DISTINCT o.name as organization, ID(o) as orgid, s.date_arrived AS date_arrived, 
                 i.case AS case, s.name AS name, ID(s) AS id
          ORDER BY date_arrived
        """, ppn:params[:ppn])

        grouped_submissions = submissions.group_by do | submission | 
          { orgid: submission[:orgid], organization: submission[:organization] }
        end.sort_by { | key, submission_group | key[:organization] } 

        { grouped_submissions: grouped_submissions }
      end
    end
  end
end