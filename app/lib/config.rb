require 'yaml'

module Config
  CONFIG = YAML.load_file("config/neo4j.yml")

  module Neo4J
    mattr_accessor :username, :password
    @@username = CONFIG["username"]
    @@password = CONFIG["password"]
  end
end