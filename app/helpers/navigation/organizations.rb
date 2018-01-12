require "sinatra/base"
require "helpers/basic"

module Sinatra
  module NavigationHelpers
    class Organizations
      TEMPLATE = "navigation/organizations"

      def initialize(params)
        @params = params
      end

      def data
        submissions = graph_query("""
          MATCH (o:Organization)-[:ACTING_AS]->(:Participant)-[:PARTICIPATES_IN]->(s:Submission)<-[:INVOLVING]-(i:Intervention)-[:SUBMITTED_TO]->(p:PublicProcess { ppn: $ppn })
          WHERE EXISTS(s.date_arrived)
          RETURN o.name as organization, s.date_arrived AS date_arrived, i.case AS case, s.name AS name, ID(s) AS id
          ORDER BY date_arrived
        """, ppn:@params[:ppn])

        grouped_submissions = {}
        submissions.each do |s|
          grouped_submissions[s["organization"]] ||= []
          grouped_submissions[s["organization"]] << { 
            :id => s["id"], 
            :case => s["case"], 
            :name => s["name"] 
          }
        end

        { :grouped_submissions => grouped_submissions }
      end
    end
  end
end