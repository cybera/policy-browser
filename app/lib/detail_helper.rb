require "lib/data_display_helper"

class DetailHelper < DataDisplayHelper
  cattr_accessor :registered_helpers
  cattr_accessor :template_path_prefix

  def self.inherited(subclass)
    self.template_path_prefix = "detail"
    self.registered_helpers ||= []
    self.registered_helpers << subclass
  end
end
