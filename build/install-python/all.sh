#!/bin/bash

python -m nltk.downloader popular

pip install neo4j-driver
conda install -c conda-forge scrapy

pip install ftfy

# workaround until this fix gets in the released version of nltk:
# https://github.com/nltk/nltk/pull/1863/files/6157b7bc51f0361665c62f408f58b0720e6ddebe
patch /opt/conda/lib/python3.6/site-packages/nltk/tokenize/texttiling.py < /tmp/install/texttiling.patch