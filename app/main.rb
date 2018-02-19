#!/usr/bin/env ruby

require "sinatra"
require "sinatra/base"
require "active_support"
require "active_support/core_ext"
require "csv"

$:.unshift File.expand_path("..", __FILE__)

require "lib/neo4j"

require "helpers/basic"
require "helpers/detail"
require "helpers/navigation"
require "lib/solr"

set :bind, '0.0.0.0'

Neo4JQueries::connect("neo4j", "password")
include Neo4JQueries
SolrQueries::connect()
include SolrQueries

def default_ppn
  if !@default_ppn
    public_processes = graph_query("MATCH (p:PublicProcess) RETURN p.ppn as ppn")
    @default_ppn = public_processes.map { |r| r[:ppn] }.first
  end
  @default_ppn
end

get '/' do
  redirect "/browser?ppn=#{default_ppn}"
end

get '/browser' do
  redirect "/browser?ppn=#{default_ppn}" if !params[:ppn]

  safe_params = Sinatra::IndifferentHash.new
  safe_params[:navigation] = params[:navigation] || "timeline"
  safe_params[:detail] = params[:detail] || "case"
  safe_params[:ppn] = params[:ppn] || default_ppn
  safe_params[:submission] = params[:submission]
  safe_params[:query] = params[:query]
  safe_params[:question] = params[:question]

  erb :browser, :locals => safe_params, :layout => :layout
end

solr_search = lambda do
  results = EmptySolrResults.new

  if request.env["REQUEST_METHOD"] == "POST"
    query = params[:solr_query_string]

    search_params = {
      "hl.fragsize": params[:solr_segment_size] || 500
    }

    if params[:action] == "show_all"
      search_params[:rows] = params[:search_hits].to_i || 6000
    elsif params[:visible_hits].to_i > 10 && params[:action] != "search"
      search_params[:rows] = params[:visible_hits].to_i
    end

    results = solr_query(query, **search_params)
    results_to_add = nil

    if params[:action] == "add_all" && params[:visible_hits] < params[:search_hits]
      add_all_params = search_params.dup
      add_all_params[:rows] = params[:search_hits].to_i || 6000
      results_to_add = solr_query(query, **add_all_params)
    elsif params[:action] == "add_all" || params[:action] == "add_visible"
      results_to_add = results
    end

    results_to_add.add if results_to_add    
  end

  solr_query_string = (params['solr_query_string'] || "").gsub('"','&quot;')
  solr_segment_size = params['solr_segment_size'] || "500"
  erb :search, :locals => { results: results, solr_query_string: solr_query_string, 
                            solr_segment_size: solr_segment_size,
                          }
end

get '/search', &solr_search
post '/search', &solr_search

post '/question/:question_id/link/:query_id' do
  quality = params[:quality].to_f || 0.2

  results = graph_query("""
    MATCH (question:Question)
    MATCH (query:Query)
    WHERE ID(question) = $question AND ID(query) = $query
    MERGE (query)-[r:ABOUT { method:'browser' }]->(question)
    SET r.quality = $quality
  """, question:params[:question_id].to_i, query:params[:query_id].to_i, quality:quality)

  content_type :json
  { linked: true, quality: quality }.to_json
end

post '/question/:question_id/unlink/:query_id' do
  quality = (params[:quality].to_f || 0.2) - 0.2
  graph_query("""
    MATCH (query:Query)-[r:ABOUT]->(question:Question)
    WHERE ID(question) = $question AND ID(query) = $query
    #{quality > 0.0 ? 'SET r.quality = $quality' : 'DELETE r'}
  """, question:params[:question_id].to_i, query:params[:query_id].to_i, quality:quality)

  content_type :json
  { linked: false, quality: quality }.to_json
end

get '/csv/:question' do
  csv_data = graph_query("""
    MATCH (question:Question)
    MATCH (query:Query)-[r:ABOUT]-(question)
    MATCH (query)<--(segment:Segment)-[:SEGMENT_OF]->(doc:Document)
    MATCH (org:Organization)<-[:ALIAS_OF*0..1]-()-[:SUBMITTED]->(doc)
    WHERE ID(question) = $question AND
          NOT (org)-[:ALIAS_OF]->()
    RETURN doc.name as document, segment.content AS segment, query.str as query, org.category as category, 
    org.name as organization, COALESCE(r.quality, 0.2) AS quality
  """, question:params[:question].to_i)

  question = graph_query("""
    MATCH (q:Question)
    WHERE ID(q) = $question
    RETURN q.content AS content, q.ref AS ref, ID(q) AS id
  """, question:params[:question].to_i).first

  content_type :csv
  headers["Content-Disposition"] = "attachment;filename=#{question['ref']}-segments.csv"

  str = ""
  str += CSV.generate_line(csv_data.columns, { :force_quotes => true })
  str += csv_data.rows.map do |row|
    CSV.generate_line(row, { :force_quotes => true }).strip.gsub(/\n/,"\\n")
  end.join("\n")
  str
end