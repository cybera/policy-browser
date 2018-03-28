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
            RETURN document.name AS name, document.content AS content, document.type AS type,
                   org.name AS organization, person.name AS person, submission.name AS submission_name
          """, id:params[:submission].to_i)

          documents.each do |document|
            obfuscate_content_names!(document[:content])
            obfuscate_content_emails!(document[:content])
            obfuscate_content_phone_number!(document[:content])
          end

          { documents: documents }
        else
          { documents: [] }
        end
      end
      
      def obfuscate_content_names!(content, debug_mode=false)
        replacement = debug_mode ? "\\1**\\2**\\3" : "\\1****\\3"

        # lazily initialize an instance variable for @names
        @names ||= begin 
          name_words = graph_query("MATCH (p:Person) RETURN p.name AS name").map do | record |
            record[:name].split(/\s+/)
          end.flatten.map(&:strip).uniq.reject do | name | 
            name !~ /[A-Z][a-z]+/ ||
            name.length < 3
          end

          org_words = graph_query("MATCH (o:Organization) RETURN o.name AS name").map do | record |
            record[:name].split(/\s+/)
          end.flatten.map(&:strip).uniq.reject do | name | 
            name !~ /[A-Z][a-z]+/
          end

          # Just a list of random words that seem to have gotten caught up in some of the names and we don't
          # really want to hide.
          whitelist = ["You", "Storm"]

          (name_words - org_words) - whitelist
        end

        @names.each do |name|
          content.gsub!(/(^|\s)(#{name})([^A-Za-z'])/, replacement)
        end
      end

      def obfuscate_content_emails!(content)
      end

      def obfuscate_content_phone_number!(content)
      end
    end
  end
end