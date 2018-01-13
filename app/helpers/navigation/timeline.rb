require "sinatra/base"
require "helpers/basic"

module Sinatra
  module NavigationHelpers
    class Timeline < NavigationHelper
      def data
        submissions = graph_query("""
          MATCH (s:Submission)<-[:INVOLVING]-(i:Intervention)-[:SUBMITTED_TO]->(p:PublicProcess { ppn: $ppn })
          WHERE EXISTS(s.date_arrived)
          RETURN s.date_arrived AS date_arrived, i.case AS case, s.name AS name, ID(s) AS id
          ORDER BY date_arrived
        """, ppn:params[:ppn])

        grouped_submissions = submissions.group_by do | submission |
          submission[:date_arrived]
        end.sort_by { | date_arrived, submission_group | date_arrived }

        { grouped_submissions: grouped_submissions }
      end
    end
  end
end