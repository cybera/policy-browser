require "sinatra/base"
require "date"
require "timeout"
require "socket"
require "neo4j-core"
require 'neo4j/core/cypher_session/adaptors/http'
require 'neo4j/core/cypher_session/adaptors/bolt'

module Sinatra
  module BasicHelpers
    def int_to_ymd(num)
      day = (num % 100).to_i
      month = (((num - day) / 100) % 100).to_i
      year = ((num - (month * 100 + day)) / 10000).to_i
      return year, month, day
    end
    
    def int_to_datestr(num)
      ymd = int_to_ymd(num)
      Date.new(*ymd).strftime("%B %d, %Y")
    end

    def camelize(snake_case_str)
      snake_case_str.split('_').collect(&:capitalize).join
    end
  end

  helpers BasicHelpers
end