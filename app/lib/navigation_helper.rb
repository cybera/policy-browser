class NavigationHelper
  include Neo4JQueries

  def template
    template_name = self.class.name.split('::').last.underscore
    File.join("navigation", template_name).to_sym
  end
end
