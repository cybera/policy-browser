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

    def smart_paragraphs(newlines_str)
      paragraphs = newlines_str.gsub("\u00A0", " ").split(/\n+/).select do |para| 
        para.strip != ""
      end
      
      avg_length = paragraphs.map { |p| p.length }.reduce(:+).to_f / paragraphs.length
      paragraphs = paragraphs.slice_when do |prevpara, nextpara|
        prevpara.strip =~ /.*?[.?!;:]$/ || prevpara.length < 0.8 * avg_length
      end.map { |parablock| parablock.join("") }

      paragraphs.chunk do | para |
        para.length < 0.8 * avg_length
      end.map do | short, parachunk | 
        short ? parachunk.join("<br/>") : parachunk.map { |para| "<p>#{para}</p>" }
      end.join("\n")
    end

    def navigation_active_css(path)
      if request.path_info == path
        "active"
      else
        ""
      end
    end

    def author(data_row, organization_name_key=:organization, person_name_key=:person)
      if !(data_row[organization_name_key].to_s.empty? || data_row[person_name_key].to_s.empty?)
        "#{data_row[organization_name_key]} (#{data_row[person_name_key]})"
      else
        data_row[organization_name_key].to_s.empty? ? data_row[person_name_key] : data_row[organization_name_key]
      end
    end

    def authored_by(text, author)
      "#{text}#{!author.to_s.empty? ? ': ' : ''}#{author}"
    end
  end

  helpers BasicHelpers
end