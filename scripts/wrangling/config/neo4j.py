import yaml

with open("config/neo4j.yml") as config_file:
  config = yaml.load(config_file)

username = config['username']
password = config['password']
ppn = config['ppn']
