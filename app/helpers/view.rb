require "sinatra/base"

Dir[File.join(File.dirname(__FILE__), "view", "*.rb")].each do |file|
  require file
end

module Sinatra
  module ViewHelpers
    def render_view(viewname, params)
      view_class = Sinatra::ViewHelpers::const_get(camelize(viewname))
      viewobj = view_class.new(params)
      erb view_class::TEMPLATE.to_sym, :locals => params.merge(viewobj.data)
    end
  end
  helpers ViewHelpers
end
