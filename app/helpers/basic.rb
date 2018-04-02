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
      paragraphs = newlines_str.to_s.gsub("\u00A0", " ").split(/\n+/).select do |para| 
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

    def obfuscate_person_name(name)
      return nil if name.to_s.empty?

      # lazily initialize a module level variable to keep track of names
      @@people_to_refs ||= {}
      @@person_ref_seq ||= 1

      if !@@people_to_refs[name]
        @@people_to_refs[name] = @@person_ref_seq
        @@person_ref_seq += 1
      end

      "Intervenor #{@@people_to_refs[name]}"
    end

    def author(data_row, organization_name_key=:organization, person_name_key=:person)
      person_name = obfuscate_person_name(data_row[person_name_key])

      if !(data_row[organization_name_key].to_s.empty? || person_name.nil?)
        "#{data_row[organization_name_key]} (#{person_name})"
      else
        data_row[organization_name_key].to_s.empty? ? person_name : data_row[organization_name_key]
      end
    end

    def authored_by(text, author)
      "#{text}#{!author.to_s.empty? ? ': ' : ''}#{author}"
    end

    class ::String
      def obfuscate
        text = self.dup
        obfuscate_content_names!(text)
        obfuscate_content_emails!(text)
        obfuscate_content_phone_number!(text)
        obfuscate_content_postal_code!(text)
        text
      end

      def obfuscate_content_names!(content, debug_mode=false)
        replacement = debug_mode ? "\\1**\\2**\\3" : "\\1****\\3"

        # lazily initialize an instance variable for @names
        @@names ||= begin 
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
        @@names_regexp ||= @@names.join("|")

        content.gsub!(/(^|\s)(#{@@names_regexp})([^A-Za-z'])/, replacement)
      end

      def obfuscate_content_emails!(content)
        content.gsub!(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i, "******@***.com")
      end

      def obfuscate_content_phone_number!(content)
        content.gsub!(/(\d\.?|\+\d\.?)?\(?\d{3}(\.| |-|\))\d{3}(\.| |-)\d{4}/, "*-***-***-****")

      end

      def obfuscate_content_postal_code!(content)
          content.gsub!(/[ABCEGHJKLMNPRSTVXY]{1}\d{1}[A-Z]{1} *\d{1}[A-Z]{1}\d{1}/, "*** ***")
      end
    end
  end

  helpers BasicHelpers
end