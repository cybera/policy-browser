require "sinatra/base"

Dir[File.join(File.dirname(__FILE__), "detail", "*.rb")].each do |file|
  require file
end

module Sinatra
  module DetailHelpers
    def render_detail(detailname, params)
      detail_class = Sinatra::DetailHelpers::const_get(camelize(detailname))
      detail_obj = detail_class.new(params)
      erb detail_class::TEMPLATE.to_sym, :locals => params.merge(detail_obj.data)
    end
  end
  helpers DetailHelpers
end
