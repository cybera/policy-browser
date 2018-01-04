#!/usr/bin/env ruby

require "sinatra"

# neo4j
require "neo4j-core"
require "date"
require "timeout"
require "socket"
require 'neo4j/core/cypher_session/adaptors/http'
require 'neo4j/core/cypher_session/adaptors/bolt'

bolt_adaptor = Neo4j::Core::CypherSession::Adaptors::Bolt.new("bolt://neo4j:password@neo4j:7687", timeout: 10)
neo4jDB = Neo4j::Core::CypherSession.new(bolt_adaptor)

results = neo4jDB.query("MATCH (p:PublicProcess) RETURN p.ppn AS ppn")
results.map { |r| r[:ppn] }

set :bind, '0.0.0.0'

get "/" do
  public_process_numbers = neo4jDB.query("MATCH (p:PublicProcess) RETURN p.ppn AS ppn ORDER BY ppn").map { |r| r[:ppn] }
  public_process_links = public_process_numbers.map do |ppn|
    "<a href='/public_process/#{ppn}/submission/'>#{ppn}</a>"
  end

  """
  <h1>Public Processes</h1>
  #{public_process_links.join('<br/>')}
  """
end

def int_to_ymd(num)
  day = (num % 100).to_i
  month = (((num - day) / 100) % 100).to_i
  year = ((num - (month * 100 + day)) / 10000).to_i
  return year, month, day
end

get "/public_process/:ppn/submission/:id?" do
  ppn = params["ppn"]

  submissions = neo4jDB.query("""
    MATCH (s:Submission)<-[:INVOLVING]-(i:Intervention)-[:SUBMITTED_TO]->(p:PublicProcess { ppn: $ppn })
    WHERE EXISTS(s.date_arrived)
    RETURN s.date_arrived AS date_arrived, i.case AS case, s.name AS name, ID(s) AS id
    ORDER BY date_arrived
  """, ppn:ppn)

  grouped_submissions = {}
  submissions.each do |s|
    grouped_submissions[s["date_arrived"]] ||= []
    grouped_submissions[s["date_arrived"]] << { :id => s["id"], :case => s["case"], :name => s["name"] }
  end

  timeline = grouped_submissions.map do |date_arrived, submissions_on_date|
    ymd = int_to_ymd(date_arrived)
    date_str = Date.new(*ymd).strftime("%B %d, %Y")
    date_header = "<h3>#{date_str}</h3>"
    submission_links = submissions_on_date.map do |s|
      "<a href='/public_process/#{ppn}/submission/#{s[:id]}'>#{s[:case]}-#{s[:name]}</a>"
    end
    date_header + submission_links.join("<br/>")
  end

  submission_text = ""

  if params[:id]
    documents = neo4jDB.query("""
      MATCH (submission:Submission)-[:CONTAINING]->(document:Document)
      WHERE ID(submission) = $id
      RETURN document.name, document.content
    """, id:params[:id].to_i)

    submission_text = documents.map do |doc|
      doc_name = doc["document.name"]
      doc_paragraphs = doc["document.content"].split(/\n+/)
      content_html = doc_paragraphs.select do |para| 
        para.strip != ""
      end.map do |para| 
        "<p>#{para}</p>"
      end.join("\n")

      """
      <h3>#{doc_name}</h3>
      #{content_html}
      """
    end.join("<br/>\n")
  end

  """
  <h1>Public Process #{ppn}</h1>
  <table>
    <tr>
      <td valign='top' width='20%'>
        #{timeline.join("\n")}
      </td>
      <td valign='top'>
        #{submission_text}
      </td>
    </tr>
  </table>
  """
end
