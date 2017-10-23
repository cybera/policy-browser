#!/bin/env python

import sqlite3
CONNECTION = sqlite3.connect('data/processed/docs.db')

def check_count(query, params=[]):
  global CONNECTION
  rows = CONNECTION.execute(query, params).fetchall()
  count_result = rows[0][0]
  return count_result

DOC_COUNT = check_count("SELECT COUNT(id) FROM docs")

def docmeta_count(key):
  global DOC_COUNT
  query = "SELECT COUNT(DISTINCT docid) FROM docmeta WHERE key = ?"
  key_count = check_count(query, [key])
  percent = (key_count / DOC_COUNT) * 100
  return "%.2f%% (%i/%i)" % (percent, key_count, DOC_COUNT)

WISHLIST = {}

def wishlist_add(metadata_type, candidate_key=None):
  global WISHLIST

  if metadata_type not in WISHLIST:
    WISHLIST[metadata_type] = []
  
  if candidate_key:
    WISHLIST[metadata_type].append(candidate_key)

wishlist_add("unsorted", "date_arrived")
wishlist_add("Public Process Number", "public_process_number")
wishlist_add("Intervention Number", "intervention_number")
wishlist_add("Case Number", "case")
wishlist_add("unsorted", "request_to_appear")
wishlist_add("unsorted", "respondent")

for metadata_type in WISHLIST:
  print("%s:" % metadata_type)

  for candidate_key in WISHLIST[metadata_type]:
    summary = "%s: %s" % (candidate_key, docmeta_count(candidate_key))
    print("\t%s" % summary)

# copy_sent
# client_information:name
# client_information:title
# client_information:on_behalf_of_company
# client_information:email_address
# client_information:address
# client_information:postal_code
# client_information:telephone
# client_information:fax
# designated_representative:name
# designated_representative:title
# designated_representative:on_behalf_of_company
# designated_representative:email_address
# designated_representative:postal_code
# designated_representative:telephone
# designated_representative:fax
