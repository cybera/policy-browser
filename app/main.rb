#!/usr/bin/env ruby

require "sinatra"
require "sinatra/base"
require "active_support"
require "active_support/core_ext"

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