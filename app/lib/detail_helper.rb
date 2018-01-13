class DetailHelper
  include Neo4JQueries

  def template
    template_name = self.class.name.split('::').last.underscore
    File.join("detail", template_name).to_sym
  end
end
