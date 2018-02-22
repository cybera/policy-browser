require 'yaml'

module Config
  NEO4J_CONFIG = YAML.load_file("config/neo4j.yml")
  BROWSER_CONFIG = YAML.load_file("config/browser.yml")

  module Neo4J
    mattr_accessor :username, :password
    @@username = NEO4J_CONFIG["username"]
    @@password = NEO4J_CONFIG["password"]
  end

  module Admin
    mattr_accessor :password
    @@password = BROWSER_CONFIG["password"]
  end
end