module Sinatra
  module DetailHelpers
    class GenericQuality < DetailHelper
      def data
        # Empty for now, unless we figure out some good generic quality stuff for nodes
        { }
      end
    end
  end
end