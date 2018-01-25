module Sinatra
  module DetailHelpers
    class DocumentQuality < DetailHelper
      def data
        client_exists = "(:Participant)-[:PARTICIPATES_IN]->(:Submission)-->(doc)"
        org_exists = "(:Organization)-->(doc)"
        summary = {
          "Total Documents" => graph_query("MATCH (doc:Document) RETURN COUNT(doc)").rows.first[0],
          "Documents with Clients" => graph_query("MATCH (doc:Document) WHERE #{client_exists} return COUNT(doc)").rows.first[0],
          "Documents with Organizations" => graph_query("MATCH (doc:Document) WHERE #{org_exists} return COUNT(doc)").rows.first[0]
        }

        { 
          summary: summary,
          unknown_documents: graph_query("MATCH (doc:Document) WHERE NOT #{org_exists} RETURN doc.name").map { |r| r["doc.name"] }
        }
      end
    end
  end
end