require "sinatra/base"
require "helpers/basic"

module Sinatra
  module NavigationHelpers
    class Timeline
      TEMPLATE = "navigation/timeline"

      def initialize(params)
        @params = params
      end

      def data
        submissions = graph_query("""
          MATCH (s:Submission)<-[:INVOLVING]-(i:Intervention)-[:SUBMITTED_TO]->(p:PublicProcess { ppn: $ppn })
          WHERE EXISTS(s.date_arrived)
          RETURN s.date_arrived AS date_arrived, i.case AS case, s.name AS name, ID(s) AS id
          ORDER BY date_arrived
        """, ppn:@params[:ppn])

        grouped_submissions = {}
        submissions.each do |s|
          grouped_submissions[s["date_arrived"]] ||= []
          grouped_submissions[s["date_arrived"]] << { 
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