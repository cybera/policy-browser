require "sinatra/base"

Dir[File.join(File.dirname(__FILE__), "navigation", "*.rb")].each do |file|
  require file
end

module Sinatra
  module NavigationHelpers
    def render_navigation(navigation, params)
      nav_class = Sinatra::NavigationHelpers::const_get(camelize(navigation))
      nav = nav_class.new(params)
      erb nav_class::TEMPLATE.to_sym, :locals => params.merge(nav.data)
    end
  end
  helpers NavigationHelpers
end
