require "sinatra/base"
require "lib/detail_helper"

Dir[File.join(File.dirname(__FILE__), "detail", "*.rb")].each do |file|
  require file
end

module Sinatra
  module DetailHelpers
    def render_detail(detailname, params)
      detail_class = Sinatra::DetailHelpers::const_get(detailname.camelize)
      detail = detail_class.new(params)
      erb detail.template, :locals => params.merge(detail.data)
    end
  end
  helpers DetailHelpers
end
