module Sinatra
  module DetailHelpers
    class Case < DetailHelper
      def data
        if params[:submission]
          documents = graph_query("""
            MATCH (submission:Submission)-[:CONTAINING]->(document:Document)
            WHERE ID(submission) = $id
            WITH submission, document
            OPTIONAL MATCH (org:Organization)<-[:ALIAS_OF*0..1]-()-->(:Participant { role: 'Client' } )-->(submission)
            OPTIONAL MATCH (person:Person)-->(:Participant { role: 'Client' } )-->(submission)
            WHERE NOT (org)-[:ALIAS_OF]->()
            RETURN document.name AS name, document.type AS type, org.name AS organization,
                   COALESCE(document.content_obfuscated, document.content) AS content, 
                   person.name AS person, submission.name AS submission_name
          """, id:params[:submission].to_i)

          { documents: documents }
        else
          { documents: [] }
        end
      end
    end
  end
end