class DataDisplayHelper
  include Neo4JQueries

  class << self
    def param_name
      self.descriptive_name.underscore
    end

    def descriptive_name
      self.name.split('::').last
    end
  end

  def template
    File.join(self.class.template_path_prefix, self.class.param_name).to_sym
  end
end