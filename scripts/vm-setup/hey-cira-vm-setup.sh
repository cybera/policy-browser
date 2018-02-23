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

#Clone Neo4j branch of cybera/policy-browser git repo
cd /home/ubuntu
git clone -b neo4j git@github.com:cybera/policy-browser.git
cd /home/ubuntu/policy-browser

#Build `policy-browser` project
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
bin/transform
bin/script import/neo4j-to-solr.py
#see github readme for more instructions on how to work with Solr and Neo4j https://github.com/cybera/policy-browser/tree/neo4j


#Load Balancing
#HAProxy Load Balancer - set-up front end proxy to our back end services
sudo apt-get install haproxy
#add front-end and back-end services to /etc/haproxy/haproxy.cfg
sudo service haproxy restart

#HTTPS certificates

#generate certs
certbot certonly --standalone -d databrowser.data.cybera.ca --non-interactive --agree-tos --email tatiana.meleshko@cybera.ca  --http-01-port=8888
certbot certonly --standalone -d solr.databrowser.data.cybera.ca --non-interactive --agree-tos --email tatiana.meleshko@cybera.ca  --http-01-port=8888
certbot certonly --standalone -d neo4j.databrowser.data.cybera.ca --non-interactive --agree-tos --email tatiana.meleshko@cybera.ca  --http-01-port=8888

#prepare certs for haproxy:
cat /etc/letsencrypt/live/neo4j.databrowser.data.cybera.ca/fullchain.pem /etc/letsencrypt/live/neo4j.databrowser.data.cybera.ca/privkey.pem > /etc/ssl/neo4j.databrowser.data.cybera.ca/neo4j.databrowser.data.cybera.ca.pem
cat /etc/letsencrypt/live/solr.databrowser.data.cybera.ca/fullchain.pem /etc/letsencrypt/live/solr.databrowser.data.cybera.ca/privkey.pem > /etc/ssl/solr.databrowser.data.cybera.ca/solr.databrowser.data.cybera.ca.pem
cat /etc/letsencrypt/live/databrowser.data.cybera.ca/fullchain.pem /etc/letsencrypt/live/databrowser.data.cybera.ca/privkey.pem > /etc/ssl/databrowser.data.cybera.ca/databrowser.data.cybera.ca.pem

#update haproxy with new certs + setup https vim /etc/haproxy/haproxy.cfg
#update crontab for certbot to renew once a month vim /etc/cron.d/certbot
#create renewal script vim /opt/update-certs.sh chmod +x  /opt/update-certs.sh 


#Other security
#change the password for our neo4j database to something better
#try to wall off anything else, possibly closing down ports to the outside (only haproxy, running on that machine needs access)
#certbot needs open port 80 for ipv4 and ipv6
