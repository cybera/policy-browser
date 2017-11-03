#!/usr/bin/env ruby

require "sinatra"
require "sqlite3"

set :bind, '0.0.0.0'

dbpath = "/mnt/hey-cira/data/processed/docs.db"

DB = SQLite3::Database.new(dbpath)

get "/" do
  query = """
    SELECT value 
    FROM docmeta 
    WHERE 
      key = 'public_process_number' AND 
      source = 'filename-meta';
  """

  public_process_numbers = DB.execute(query).flatten.uniq.sort
  public_process_links = public_process_numbers.map do |ppn|
    "<a href='/public_process/#{ppn}/case/'>#{ppn}</a>"
  end

  """
  <h1>Public Processes</h1>
  #{public_process_links.join('<br/>')}
  """
end

get "/public_process/:ppn/case/:case?" do
  query = """
    SELECT value 
    FROM docmeta 
    WHERE 
      key = 'case' AND 
      source = 'filename-meta' AND
      docid IN (
        SELECT DISTINCT docid
        FROM docmeta
        WHERE
          KEY = 'public_process_number' AND
          value = ?
      )
  """

  ppn = params['ppn']
  casenum = params['case']

  cases = DB.execute(query, [ppn]).flatten.uniq.sort
  case_links = cases.map do |cn|
    "<a href='/public_process/#{ppn}/case/#{cn}'>#{cn}</a>"
  end

  case_text = ""
  if casenum
    case_text = casenum
    query = """
      SELECT docname, content
      FROM docs
      WHERE id IN (
        SELECT DISTINCT docid
        FROM docmeta 
        WHERE 
          key = 'case' AND 
          value = ?
      )
    """
    case_content = DB.execute(query, [casenum])
    case_text = case_content.map do |ccr|
      doc_name = ccr[0]
      doc_paragraphs = ccr[1].split(/\n+/)
      content_html = doc_paragraphs.map { |para| "<p>#{para}</p>" }
      """
      <h3>#{doc_name}</h3>
      #{content_html}
      """
    end
  end

  """
  <h1>Public Process #{params['ppn']}</h1>
  <table>
    <tr>
      <td valign='top' width='30%'>
        #{case_links.join(', ')}
      </td>
      <td valign='top'>
        #{case_text}
      </td>
    </tr>
  </table>
  """
end