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

  module Browser
    mattr_accessor :google_analytics
    mattr_accessor :google_analytics_id
    mattr_accessor :domain
    mattr_accessor :session_secret

    @@google_analytics = BROWSER_CONFIG["google_analytics"]
    @@google_analytics_id = BROWSER_CONFIG["google_analytics_id"]
    @@domain = BROWSER_CONFIG["domain"]
    @@session_secret = BROWSER_CONFIG["session_secret"]
  end
end