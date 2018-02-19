module Sinatra
  module NavigationHelpers
    class Timeline < NavigationHelper
      def data
        submissions = graph_query("""
          MATCH (s:Submission)<-[:INVOLVING]-(i:Intervention)-[:SUBMITTED_TO]->(p:PublicProcess { ppn: $ppn })
          MATCH (doc:Document)<--(s)
          OPTIONAL MATCH (org:Organization)-->(:Participant { role: 'Client' } )-->(s)
          OPTIONAL MATCH (person:Person)-->(:Participant { role: 'Client' } )-->(s)
          WHERE EXISTS(s.date_arrived)
          WITH s.date_arrived AS date_arrived, i.case AS case, s.name AS name, ID(s) AS id, COUNT(doc) AS docs, org.name AS organization, person.name AS person
          WHERE date_arrived IS NOT NULL
          RETURN date_arrived, case, name, id, docs, organization, person, NULL AS author
          ORDER BY date_arrived
        """, ppn:params[:ppn])

        submissions = submissions.group_by { |submission| submission[:id] }.map do |id, submission_set| 
          submission = submission_set.first
          submission[:person] = submission_set.map { |s| s[:person] }.join(", ")
          submission[:organization] = submission_set.map { |s| s[:organization] }.join(", ")
          submission[:author] = if !(submission[:organization].empty? || submission[:person].empty?)
            "#{submission[:organization]} (#{submission[:person]})"
          else
            submission[:organization].empty? ? submission[:person] : submission[:organization]
          end
          submission
        end

        grouped_submissions = submissions.group_by do | submission |
          submission[:date_arrived]
        end.sort_by { | date_arrived, submission_group | date_arrived }

        { grouped_submissions: grouped_submissions }
      end
    end
  end
end