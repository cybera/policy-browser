#!/usr/bin/env python

import yaml
from os import path
import random
import string

print('''
This script will set up necessary configuration files for you for neo4j, the admin
area of the policy browser, and the scraper. You can re-run it at any time and it
will replace your existing configuration files. Or you can edit those configuration
files by hand.

Hitting Enter accepts the default value, if it exists (indicated between [ and ]) or
leaves that configuration entry blank.
''')

class ConfigEntry:
  def __init__(self, key, prompt=None, generator=None, onlyif=None):
    self.key = key
    self.prompt = prompt
    self.generator = generator
    self._config = None
    self.onlyif = onlyif

  def reconfigure(self):
    value = self._config[self.key]
    value_text = value
    if isinstance(value, bool):
      if value:
        value_text = "Y/n"
      else:
        value_text = "y/N"
    
    if self.prompt:
      prompt_text = f"{self.prompt} [{value_text}]: "

      value_input = input(prompt_text)
      if value_input:
        if isinstance(value, bool):
          if value_input.lower() == "y":
            value = True
          else:
            value = False
        else:
          value = value_input

    if self.generator:
      value = self.generator(value)

    self._config[self.key] = value  

class ConfigFile:
  def __init__(self, outpath):
    self.outpath = outpath
    self._config = None
    self._entries = []

  def inpath(self):
    if path.exists(self.outpath):
      return self.outpath
    else:
      return f"{self.outpath}.example"

  def config(self):
    if not self._config:
      with open(self.inpath()) as infile:
        self._config = yaml.load(infile.read())
    return self._config
  
  def add(self, key, prompt=None, generator=None, onlyif=None):
    ce = ConfigEntry(key, prompt, generator, onlyif)
    ce._config = self.config()
    self._entries.append(ce)

  def reconfigure(self):
    for entry in self._entries:
      if not entry.onlyif or self._config[entry.onlyif]:
        entry.reconfigure()

  def output(self):
    return yaml.dump(self._config, default_flow_style=False)

  def write_output(self):
    with open(self.outpath, "w") as outfile:
      outfile.write(self.output())

neo4j_config = ConfigFile(path.join("config", "neo4j.yml"))
neo4j_config.add("username", "Neo4J username")
neo4j_config.add("password", "Neo4J password")
neo4j_config.reconfigure()

browser_config = ConfigFile(path.join("config", "browser.yml"))
browser_config.add("password", "Policy Browser admin password")
browser_config.add("google_analytics", "Enable Google Analytics?")
browser_config.add("google_analytics_id", "Google Analytics ID", onlyif="google_analytics")

def session_secret(value):
  if value == "some_long_character_string":
    return ''.join(random.choices(string.ascii_letters + string.digits, k=36))
  else:
    return value

browser_config.add("session_secret", generator=session_secret)
browser_config.reconfigure()

scraper_config = ConfigFile(path.join("config", "docker", "scraper.yml"))
scraper_config.add("entry_url", "URL to start scraping")
scraper_config.add("download_folder", "Download folder")
scraper_config.add("ongoing_consultation", "Ongoing Consultation?")
scraper_config.add("consultation", "Consultation")
scraper_config.reconfigure()

if not path.exists(".skip-transforms"):
  open(".skip-transforms", 'w').close()    

neo4j_config.write_output()
browser_config.write_output()
scraper_config.write_output()
