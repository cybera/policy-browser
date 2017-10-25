#!/usr/bin/env python

import os
import sqlite3
import re

META_SOURCE = "filename-meta"
META_VERSION = "1.0"

dbpath = os.path.join("data", "processed", "docs.db")
DB = sqlite3.connect(dbpath)

scrapedir = os.path.join("data", "raw")

def insert_meta(docid, key, value, source=META_SOURCE, version=META_VERSION, conn=DB):
  DB.execute("INSERT OR IGNORE INTO docmeta(docid,key,source) VALUES (?,?,?)", [docid,key,source])
  DB.execute("UPDATE docmeta SET value = ?, version = ? WHERE docid = ? AND key = ? AND source = ?", 
             [value,version,docid,key,source])

for fname in os.listdir(scrapedir):
  result = DB.execute("SELECT id FROM docs WHERE docname LIKE ?", [fname]).fetchone()
  if result:
    docid = result[0]
    [case,public_process_number,dmid] = re.sub(r'\(.*',"",fname).split(".")
    insert_meta(docid, "case", case)
    insert_meta(docid, "public_process_number", public_process_number)
    insert_meta(docid, "dmid", dmid)

DB.commit()