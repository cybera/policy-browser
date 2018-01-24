#!/bin/bash

#Update apt-get package index
sudo apt-get update

#Install packages to allow apt to use a repository over HTTPS
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

#Get Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

#Set-up stable Docker repository
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

#Update apt-get package index
sudo apt-get update

#Install Docker Community Edition (CE)
sudo apt-get install docker-ce

#Install Docker Compose
sudo apt-get install docker-compose
sudo curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

#Clone Neo4j branch of cybera/hey-cira git repo
cd /home/ubuntu
git clone -b neo4j git@github.com:cybera/hey-cira.git
cd /home/ubuntu/hey-cira

#Build `hey-cira` project
bin/build

#Scrape and process CRTC documents
bin/scrape
bin/process-docs

#Neo4j
#Add security groups ports 7473, 7474, 7687
#https://neo4j.com/docs/operations-manual/current/configuration/ports/

#Start-up neo4j database browser http://162.246.157.116:7474/browser/
bin/neo4j start
#Change password on Neo4j database to
#Delete existing nodes using `MATCH (n) DETACH DELETE n;`
#bin/neo4j stop

#Apache Solr
#Add security group port 8983, optionally add 9983
docker run --name my_solr -d -p 8983:8983 -t solr
bin/solr start
#bin/solr stop

bin/process-docs
bin/wrangle-neo4j
bin/script import/neo4j-to-solr.py
#see github readme for more instructions on how to work with Solr and Neo4j https://github.com/cybera/hey-cira/tree/neo4j


#Load Balancing
#HAProxy Load Balancer - set-up front end proxy to our back end services
sudo apt-get install haproxy
#add front-end and back-end services to /etc/haproxy/haproxy.cfg
sudo service haproxy restart

##Next steps
#HTTPS certificates
#first: get domain name and point at IPv4 address
#second: generate the certs from the certbot thing and place them in the right spots (haproxy or whatever frontend we’d end up using is the only thing that would be paying attention to these https certs)

#Other security
#change the password for our neo4j database to something better
#try to wall off anything else, possibly closing down ports to the outside (only haproxy, running on that machine needs access)
