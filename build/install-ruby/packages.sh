#!/bin/bash

apt-get update

# required for general gem installations
apt-get install -y build-essential

# required for sqlite3 gem
apt-get install -y libsqlite3-dev

# required for yomu gem (tika dependency)
apt-get install -y default-jre-headless

# required for neo4j http adaptor
apt-get install -y curl