#!/usr/bin/env ruby

require "yomu"
require "timeout"
require "fileutils"

script_path = File.expand_path(File.dirname(__FILE__))
data_path = File.join(script_path,"..","..","data")
processed_path = File.join(data_path, "processed", "raw_text")
docs_path = File.join(data_path, "raw")

READ_TIMEOUT = 20

FileUtils.mkdir_p(processed_path)

def convert_doc(fpath, processed_path)
  fname = File.basename(fpath)
  ftype = File.extname(fpath).downcase

  text_path = File.join(processed_path, "#{fname}.txt")
  if File.exist?(text_path)
    puts "Already converted: #{fname}"
    return
  end

  puts "Reading: #{fname}"

  # If it's an .html file, we have a known format, and we'll just extract the comment block.
  # Otherwise, parse the file with Yomu, which should handle most formats, including pdf, doc,
  # and ppt. Images will fail. We don't really have a good way of dealing with them at the 
  # moment, but there are so few, they're probably not worth trying to parse.
  content = if [".html", ".htm"].include?(ftype)
    IO.read(fpath)
  elsif [".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".odt", ".ods", ".odp", ".rtf", ".pdf"].include?(ftype)
    parser = Yomu.new(fpath)
    parser.text
  end

  if !content.nil?
    IO.write(text_path, content)
  end
end

# Go through all of the files that have been downloaded and try to parse them
for fpath in Dir.glob(File.join(docs_path,"*"))
  fname = File.basename(fpath)

  begin
    # Some files may not be readable. Skip over them if they take too long to read.
    Timeout::timeout(READ_TIMEOUT) do
      convert_doc(fpath, processed_path)
    end
  rescue Timeout::Error => e
    puts "Timed out trying to read #{fpath}"
  rescue => e
    puts e
    puts "Unknown error trying to read #{fpath}"
  end
end