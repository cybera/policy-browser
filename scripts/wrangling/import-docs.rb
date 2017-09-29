#!/usr/bin/env ruby

require "sqlite3"
require "yomu"
require "nokogiri"
require "timeout"

script_path = File.expand_path(File.dirname(__FILE__))
data_path = File.join(script_path,"..","..","data")
db_path = File.join(data_path, "processed", "docs.db")
docs_path = File.join(data_path, "raw")

DB = SQLite3::Database.new(db_path)
READ_TIMEOUT = 20

def import_doc(fpath)
  fname = File.basename(fpath)
  ftype = File.extname(fpath).downcase

  rows = DB.execute("SELECT * FROM docs WHERE docname = ?", [fname])
  if rows.any?
    puts "Already imported: #{fname} (id: #{rows.first[0]})"
    return
  end

  puts "Reading: #{fname}"

  # If it's an .html file, we have a known format, and we'll just extract the comment block.
  # Otherwise, parse the file with Yomu, which should handle most formats, including pdf, doc,
  # and ppt. Images will fail. We don't really have a good way of dealing with them at the 
  # moment, but there are so few, they're probably not worth trying to parse.
  content = if [".html", ".htm"].include?(ftype)
    doc = Nokogiri::HTML(File.new(fpath))
    comment = doc.xpath("//div[contains(text(),'Comment')]/following::div[1]")
    comment.text
  else
    parser = Yomu.new(fpath)
    parser.text
  end

  DB.execute("INSERT INTO docs(docname,content) VALUES (?,?)", [fname, content])
end

# Go through all of the files that have been downloaded and try to parse them
for fpath in Dir.glob(File.join(docs_path,"*"))
  fname = File.basename(fpath)

  begin
    # Some files may not be readable. Skip over them if they take too long to read.
    Timeout::timeout(READ_TIMEOUT) do
      import_doc(fpath)
    end
  rescue Timeout::Error => e
    puts "Timed out trying to read #{fpath}"
    DB.execute("INSERT INTO docs(docname,content,error) VALUES (?,?,?)", [fname, "", "timeout"])
    # TODO: add error column and set error status
  rescue
    puts "Unknown error trying to read #{fpath}"
    DB.execute("INSERT INTO docs(docname,content,error) VALUES (?,?,?)", [fname, "", "unknown"])
    # TODO: add error column and set error status
  end
end

# Add some helper methods to the document class. The major complications here come from
# the HTML being only concerned with display. In fact, the "Designated representative"
# section actually exists as a child div of the "Client information" div, despite looking
# like siblings when the document is examined visually.
class Nokogiri::HTML::Document
  def top_level(fieldname)
    self.xpath("//div[contains(text(),'#{fieldname}')]/*").text.strip
  end

  def client_info(fieldname)
    self.xpath("//div[contains(text(),'Client information')]/following::div[contains(text(),'#{fieldname}')][1]/*").text.strip
  end

  def designated_representative(fieldname)
    self.xpath("//div[contains(text(),'Designated representative')]/following::div[contains(text(),'#{fieldname}')][1]/*").text.strip
  end
end

# Cycle through just the .html files again, as we know they have other useful information that
# can be relatively easily extracted.
htmls = Dir.glob(File.join(docs_path,"*.htm*"))
for html in htmls
  doc = Nokogiri::HTML(File.new(html))
  fname = File.basename(html)

  # Grab the document record that should already be associated with the file
  docid = DB.execute("SELECT id FROM docs WHERE docname = ?", [fname]).dig(0,0)

  if docid
    meta = {}
    meta["date_arrived"] = doc.top_level("Date Arrived")
    meta["public_process_number"] = doc.top_level("Public Process Number")
    meta["intervention_number"] = doc.top_level("Intervention Number")
    meta["applications"] = doc.top_level("Applications")
    meta["case"] = doc.top_level("Case")
    meta["request_to_appear"] = doc.top_level("Request to appear at the public hearing")
    meta["respondent"] = doc.top_level("Respondent")
    meta["copy_sent"] = doc.top_level("Copy sent to applicant and to any respondent if applicable")
    meta["client_information:name"] = doc.client_info("Name")
    meta["client_information:title"] = doc.client_info("Title")
    meta["client_information:on_behalf_of_company"] = doc.client_info("On behalf of company")
    meta["client_information:email_address"] = doc.client_info("E-mail address")
    meta["client_information:address"] = doc.client_info("Address")
    meta["client_information:postal_code"] = doc.client_info("Postal code")
    meta["client_information:telephone"] = doc.client_info("Telephone")
    meta["client_information:fax"] = doc.client_info("Fax")
    meta["designated_representative:name"] = doc.client_info("Name")
    meta["designated_representative:title"] = doc.client_info("Title")
    meta["designated_representative:on_behalf_of_company"] = doc.client_info("On behalf of company")
    meta["designated_representative:email_address"] = doc.client_info("E-mail address")
    meta["client_information:address"] = doc.client_info("Address")
    meta["designated_representative:postal_code"] = doc.client_info("Postal code")
    meta["designated_representative:telephone"] = doc.client_info("Telephone")
    meta["designated_representative:fax"] = doc.client_info("Fax")


    for k,v in meta
      if !v.empty?
        DB.execute("INSERT OR IGNORE INTO docmeta(docid,key) VALUES (?,?)", [docid,k])
        DB.execute("UPDATE docmeta SET value = ? WHERE docid = ? AND key = ?", [v,docid,k])
      end
    end
  end
end

# Create a new segment, associated with the original document content record, and with a
# sequence number (so they could be recombined in order) for every bit of text separated
# by at least a line break.
docs = DB.execute("SELECT id, docname, content FROM docs WHERE error IS NULL")
for doc in docs
  id, docname, content = doc

  # Don't re-populate segments if they already exist (may end up wanting to change this)
  segments = DB.execute("SELECT content FROM segments WHERE docid = ?", [id])
  if segments.empty?
    segments = content.split(/\n+/)

    segments.each_with_index do |segment,index|
      DB.execute("INSERT INTO segments(docid,seq,content) VALUES (?,?,?)", [id,index+1,segment])
    end
  end
end