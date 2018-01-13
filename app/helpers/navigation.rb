require "sinatra/base"
require "lib/navigation_helper"

Dir[File.join(File.dirname(__FILE__), "navigation", "*.rb")].each do |file|
  require file
end

module Sinatra
  module NavigationHelpers
    def render_navigation(navigation, params)
      nav_class = Sinatra::NavigationHelpers::const_get(navigation.camelize)
      nav = nav_class.new(params)
      erb nav.template, :locals => params.merge(nav.data)
    end
  end
  helpers NavigationHelpers
end
