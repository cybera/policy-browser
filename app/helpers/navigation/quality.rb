module Sinatra
  module NavigationHelpers
    class Quality < NavigationHelper
      def data
        labels = graph_query("""
          CALL db.labels() YIELD label RETURN label
        """).rows.flatten.map do | label |
          detail = if ["Document"].include?(label)
            "#{label.underscore}_quality"
          else
            "generic_quality"
          end

          { text: label, href: "/browser?ppn=#{params[:ppn]}&navigation=quality&detail=#{detail}" }
        end

        { labels: labels }
      end
    end
  end
end