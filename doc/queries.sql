-- Just a scratchpad for some random queries that we may be playing with in the project.
-- Check in and comment any ones you find especially helpful.

-- Shows the number of "public_process_number" metadata items (possibly from multiple
-- sources and/or documents) found for each case.
SELECT B.value, A.value, count(*)
FROM docmeta A, 
  docmeta B, 
  docs 
WHERE A.key = 'public_process_number' AND 
  B.docid = docs.id AND
  B.key = 'case' AND
  B.source = 'filename-meta' AND
  B.docid = A.docid
GROUP BY B.value, A.value;

-- Get a count of all of the distinct cases currently being tracked. This relies on there
-- being a "filename-meta" version of "case" (which should be reliable given that we find
-- out the information that we put in the filename as a part of the scraping process and
-- the file wouldn't exist without it). 
SELECT COUNT(DISTINCT B.value)
FROM docmeta A, 
  docmeta B, 
  docs 
WHERE A.key = 'public_process_number' AND 
  B.docid = docs.id AND
  B.key = 'case' AND
  B.source = 'filename-meta' AND
  B.docid = A.docid;

-- Lists various metadata keys and their source document record IDs, organized
-- by their case number and public process number. Note that we're using the 
-- filename-meta version of 'case' as the most reliable way of getting the 
-- case number.
SELECT B.value as casenum, 
  A.value as value, 
  A.source as source, 
  A.docid as sourcedocid
FROM docmeta A, 
  docmeta B, 
  docs 
WHERE A.key = 'public_process_number' AND 
  B.docid = docs.id AND
  B.key = 'case' AND
  B.source = 'filename-meta' AND
  B.docid = A.docid
ORDER BY B.value, A.value;

-- This is like the above, except it restricts the search to a particular case
-- (227322). Note that we're using the filename-meta version of 'case' as the
-- most reliable way of getting the case number.'
SELECT B.value as casenum, 
  A.value as key_value, 
  A.source as key_source, 
  A.docid as source_docid
FROM docmeta A, 
  docmeta B, 
  docs 
WHERE A.key = 'public_process_number' AND 
  B.docid = docs.id AND
  B.key = 'case' AND
  B.source = 'filename-meta' AND
  B.docid = A.docid AND
  casenum = 227322
ORDER BY B.value, A.value;