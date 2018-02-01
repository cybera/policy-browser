#!/usr/bin/env bash

# Renew the certificate
certbot renew --force-renewal --tls-sni-01-port=8888

# Concatenate new cert files, with less output (avoiding the use tee and its output to stdout)
bash -c "cat /etc/letsencrypt/live/neo4j.databrowser.data.cybera.ca/fullchain.pem /etc/letsencrypt/live/neo4j.databrowser.data.cybera.ca/privkey.pem > /etc/ssl/neo4j.databrowser.data.cybera.ca/neo4j.databrowser.data.cybera.ca.pem"

bash -c "cat /etc/letsencrypt/live/solr.databrowser.data.cybera.ca/fullchain.pem /etc/letsencrypt/live/solr.databrowser.data.cybera.ca/privkey.pem > /etc/ssl/solr.databrowser.data.cybera.ca/solr.databrowser.data.cybera.ca.pem"

bash -c "cat /etc/letsencrypt/live/databrowser.data.cybera.ca/fullchain.pem /etc/letsencrypt/live/databrowser.data.cybera.ca/privkey.pem > /etc/ssl/databrowser.data.cybera.ca/databrowser.data.cybera.ca.pem"
# Reload  HAProxy
service haproxy reload
