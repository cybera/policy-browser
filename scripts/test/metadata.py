#!/usr/bin/env python

# Usage:
#
# The basic idea with this is to have a list that we can generate of all of the metadata we are
# interested in, if we've been able to collect any of it, and the coverage provided by any that
# we have collected.
#
# If you're adding a true "wishlist" item that you don't know of any existing metadata for, use
# something like:
#
#   wishlist_add("Some Awesome Metadata", "?")
#
# If you know of what specific keys and sources a piece of metadata has, add it to the list so
# that we can keep track of its coverage (and possibly other future stats):
#
#   wishlist_add("Some Awesome Metadata", "actual_key", "actual_source")
# 
# The "actual_key" and "actual_source" should exist in the docsmeta table. See existing scripts
# for how to populate those values. "Some Awesome Metadata" is a more general name of the thing
# we want. It can be anything, but it should match up with how we're actually using it, and if
# there are multiple actual pieces of metadata that might provide that information, they should
# all have that same general name when added to the wishlist (so that we can see them grouped)
# together in the summary. The "actual_source" will probably be a particular script. By convention,
# you would set the source for all metadata derived by a particular script when inserting that
# metadata, so that we can have some idea of the metadata's provenance (especially helpful when
# dealing with conflicting metadata).

import sqlite3
CONNECTION = sqlite3.connect('data/processed/docs.db')

def check_count(query, params=[]):
  global CONNECTION
  rows = CONNECTION.execute(query, params).fetchall()
  count_result = rows[0][0]
  return count_result

DOC_COUNT = check_count("SELECT COUNT(DISTINCT value) FROM docmeta WHERE key = 'case' AND source = 'filename-meta'")

def docmeta_count(key, source):
  global DOC_COUNT
  query = """
    SELECT COUNT(DISTINCT B.value)
    FROM docmeta A, 
      docmeta B, 
      docs 
    WHERE A.key = ? AND 
      B.docid = docs.id AND
      B.key = 'case' AND
      B.source = 'filename-meta' AND
      B.docid = A.docid
  """
  params = [key]
  if source:
    query = query + "AND A.source = ?"
    params.append(source)
  key_count = check_count("%(query)s" % locals(), params)
  percent = (key_count / DOC_COUNT) * 100
  return "%.2f%% (%i/%i)" % (percent, key_count, DOC_COUNT)

WISHLIST = {}

def wishlist_add(metadata_type, key=None, source=None):
  global WISHLIST

  if metadata_type not in WISHLIST:
    WISHLIST[metadata_type] = []
  
  if key:
    WISHLIST[metadata_type].append([key,source])

def summary():
  global WISHLIST

  for metadata_type in sorted(WISHLIST):
    print("%s:" % metadata_type)

    for [key, source] in WISHLIST[metadata_type]:
      summary_stats = docmeta_count(key,source)
      if not source:
        source = "?"
      summary = "%s: %s (source: %s)" % (key, summary_stats, source)
      print("\t%s" % summary)

wishlist_add("Public Process Number", "public_process_number", "import-docs")
wishlist_add("Public Process Number", "public_process_number", "filename-meta")
wishlist_add("Intervention Number", "intervention_number", "import-docs")
wishlist_add("Case Number", "case", "import-docs")
wishlist_add("Case Number", "case", "filename-meta")
wishlist_add("Intervener Name","client_information:name", "import-docs")
wishlist_add("Title","client_information:title", "import-docs")
wishlist_add("Company","client_information:on_behalf_of_company", "import-docs")
wishlist_add("Email Address","client_information:email_address", "import-docs")
wishlist_add("Address","client_information:address", "import-docs")
wishlist_add("Postal Code","client_information:postal_code", "import-docs")
wishlist_add("Telephone","client_information:telephone", "import-docs")
wishlist_add("Fax Number","client_information:fax", "import-docs")
wishlist_add("Intervener Name","designated_representative:name", "import-docs")
wishlist_add("Title","designated_representative:title", "import-docs")
wishlist_add("Company","designated_representative:on_behalf_of_company", "import-docs")
wishlist_add("Email Address","designated_representative:email_address", "import-docs")
wishlist_add("Postal Code","designated_representative:postal_code", "import-docs")
wishlist_add("Telephone","designated_representative:telephone", "import-docs")
wishlist_add("Fax Number","designated_representative:fax", "import-docs")
wishlist_add("Topic Area", "?")
wishlist_add("City", "?")
wishlist_add("Province", "?")
wishlist_add("Responding To", "?")
wishlist_add("Date", "date_arrived")

wishlist_add("?", "request_to_appear", "import-docs")
wishlist_add("?", "respondent", "import-docs")
wishlist_add("?","copy_sent", "import-docs")
wishlist_add("Company sector", "?")
wishlist_add("Document Type", "?")
wishlist_add("Document Length", "?")
# Would be interesting to know if we can track something like a request being made in the submission and maybe just specific for 
# our analysis, whether we could automatically extract how much bandwidth they would like to get. 
wishlist_add("Request submitted", "?")
wishlist_add("Bandwidth requested", "?")
wishlist_add("Words in submission", "?")
wishlist_add("Submission format (eg. PDF, doc, html)", "?")
wishlist_add("Stage document was submitted in", "?")


summary()
