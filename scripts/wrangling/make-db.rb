#!/usr/bin/env ruby

require "sqlite3"

script_path = File.expand_path(File.dirname(__FILE__))
data_path = File.join(script_path,"..","..","data")
db_path = File.join(data_path, "processed", "docs.db")

db = SQLite3::Database.new(db_path)

db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS docs(
    id INTEGER PRIMARY KEY,
    docname VARCHAR(256),
    content TEXT,
    error VARCHAR(256)
  );
SQL

db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS segments(
    id INTEGER PRIMARY KEY,
    docid INTEGER,
    seq INTEGER,
    content TEXT,
    UNIQUE(docid, seq),
    FOREIGN KEY(docid) REFERENCES docs(id)
  );
SQL

db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS segmentmeta(
    id INTEGER PRIMARY KEY,
    key VARCHAR(128),
    segmentid INTEGER,
    value TEXT,
    source VARCHAR(128),
    version VARCHAR(32),
    FOREIGN KEY(segmentid) REFERENCES segments(id),
    UNIQUE(segmentid,key,source)
  );
SQL

db.execute <<-SQL
CREATE TABLE IF NOT EXISTS docmeta(
  id INTEGER PRIMARY KEY,
  key VARCHAR(128),
  docid INTEGER,
  value TEXT,
  source VARCHAR(128),
  version VARCHAR(32),
  FOREIGN KEY(docid) REFERENCES docs(id),
  UNIQUE(docid,key,source)
);
SQL

db.execute <<-SQL
CREATE TABLE IF NOT EXISTS docentities(
  id INTEGER PRIMARY KEY,
  docid INTEGER,
  type VARCHAR(128),
  value VARCHAR(256),
  FOREIGN KEY(docid) REFERENCES docs(id),
  UNIQUE(docid,type,value)
);
SQL
