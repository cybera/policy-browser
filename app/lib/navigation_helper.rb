require "lib/data_display_helper"

class NavigationHelper < DataDisplayHelper
  cattr_accessor :registered_helpers
  cattr_accessor :template_path_prefix

  def self.inherited(subclass)
    self.template_path_prefix = "navigation"
    self.registered_helpers ||= []
    self.registered_helpers << subclass
  end
end
