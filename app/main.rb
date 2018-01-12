#!/usr/bin/env ruby

require "sinatra"
require "sinatra/base"

$:.unshift File.expand_path("..", __FILE__)

require "lib/neo4j"

require "helpers/basic"
require "helpers/detail"
require "helpers/navigation"

set :bind, '0.0.0.0'

get '/browser' do
  safe_params = Sinatra::IndifferentHash.new
  safe_params[:navigation] = params[:navigation] || "timeline"
  safe_params[:detail] = params[:detail] || "case"
  safe_params[:ppn] = params[:ppn]
  safe_params[:submission] = params[:submission]
  safe_params[:query] = params[:query]

  erb :browser, :locals => safe_params, :layout => :layout
end