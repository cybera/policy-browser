import pysolr
import re
from wrangling.util import sha256str

class AddMiscQueries(TransformBase):
  DESCRIPTION = "Add various Solr queries and relate them to questions"

  # If you add a question and related queries here, they should get added in the
  # next bin/transform run...
  QUESTIONS = {
    "Q4-1": [
      'content:("target speed" && "mbps")',
      'content:(("should be" OR "should set") && "mbps")',
      'content:("greater than" && "mbps")'
    ]
  }

  # Copied config from segment.py
  SOLR_CONFIG = {
    'hl.fl': 'content', 
    'hl': 'on', 
    'wt': 'json', 
    'hl.fragsize': 500, 
    'hl.encoder': '', 
    'hl.tag.pre': '<em>', 
    'hl.tag.post': '</em>', 
    'hl.snippets': 200, 
    'hl.method': 'unified', 
    'fq' : 
    '-name:"2015-134.224035.2409354.Intervention(1fn2$01!).pdf" ' +
    '-name:"2015-134.224035.2409353.Intervention(1fn2h01!).pdf" ' +
    '-name:"2015-134.224035.2409355.Intervention(1fn2j01!).pdf" ' +
    '-name:"2015-134.224035.2398004.Intervention(1f#b801!).html" ' +
    '-name:"2015-134.223963.2394421.Intervention Submission 6401 to 9600(1fbjp01!).pdf" ' + 
    '-name:"2015-134.223963.2394419.Intervention Submission 1 to 3200 (1fbjn01!).pdf" ' +
    '-name:"2015-134.223963.2394424.Intervention Submission 16001 to 19200 (1fbjs01!).pdf" ' +
    '-name:"2015-134.223963.2394423.Intervention Submission 12801 to 16000(1fbjr01!).pdf" ' +
    '-name:"2015-134.223963.2394422.Intervention Submission 9601 to 12800(1fbjq01!).pdf" ' +
    '-name:"2015-134.223963.2394420.Intervention Submission 3201 to 6400(1fbj_01!).pdf" ' +
    '-name:"2015-134.223963.2394425.Intervention Submission 19201 to 22386(1fbjt01!).pdf"',
    'fl':['id','sha256','name']
  }

  # There's no real rhyme or reason to this limit past that I haven't yet seen *more* results for a single
  # query and it seems sensible to give some limit to avoid surprises. This script in the first place is 
  # probably not the most ideal way to handle solr result integration. The limit may be able to be set much
  # higher without performance issues when running transformations, but if you're looking at this, well, now
  # you get to think about it and whether or not it justifies minor/major refactoring or just nudging up
  # that limit and crossing your fingers.
  MAX_HITS_PER_QUERY = 6000

  def preconditions(self):
    self.solr = pysolr.Solr('http://solr:8983/solr/crtc-docs', timeout=10)


  def match(self):
    # Check to see if we actually have documents imported into solr before
    # trying to import actual search results. If the field doesn't exist at
    # all, any search will throw a SolrError exception.
    try:
      self.solr.search("content:000000", **self.SOLR_CONFIG)
    except pysolr.SolrError:
      return False

    updates = []

    # Short out if the question doesn't exist yet
    existing_count = neo4j_count("MATCH (q:Question) WHERE q.ref IN $qrefs", qrefs=list(self.QUESTIONS.keys()))
    if existing_count < len(self.QUESTIONS.keys()):
      return updates

    question_info = {}
    existing_questions = {}

    for qref, solr_queries in self.QUESTIONS.items():
      existing_questions[qref] = {}

      # Look for existing queries associated with this question and how many segments matched them
      with neo4j() as tx:
        dbqueries = tx.run("""
          MATCH (question:Question { ref: $qref })<--(q:Query)<--(s:Segment)
          RETURN q.str AS query, COUNT(DISTINCT s.sha256) AS hits
        """, qref=qref)

        for q in dbqueries:
          existing_questions[qref][q['query']] = int(q['hits'])

      # Do the Solr query, collect the segments, and count unique sha256s
      question_info[qref] = []
      for search_query in solr_queries:
        search_results = self.solr.search(search_query, **self.SOLR_CONFIG, rows=self.MAX_HITS_PER_QUERY)
        if len(search_results.docs) < search_results.hits:
          print(f"WARNING: Query results exceeded hard coded MAX_HITS_PER_QUERY ({self.MAX_HITS_PER_QUERY}) in add_misc_queries.py")
          print("Consider increasing MAX_HITS_PER_QUERY, modifying your query, or updating how solr results are imported")
        docs = self.gather_segments(search_results)
        total_hits = len(set([hl256 for doc in docs for hl256 in doc['hl256']]))
        question_info[qref].append({ "query": search_query, "hits": total_hits, "docs": docs })

      # If the counts in the database don't match with those of the Solr results, we'll add them 
      # to the update list
      for i, qinfo in enumerate(question_info[qref]):
        query = qinfo["query"]
        if query not in existing_questions[qref] or existing_questions[qref][query] != qinfo['hits']:
          qinfo['qref'] = qref
          updates.append(qinfo)
      
    return updates

  def transform(self, data):
    search_config = self.SOLR_CONFIG
    
    tx_results = []

    with neo4j() as tx:
      for update in data:
        for doc in update['docs']:
          for i, hl in enumerate(doc['highlights']):
            hit = re.sub(r'<em>(.*?)</em>','\\1', hl)
            hit256 = doc['hl256'][i]

            tx_result = tx.run("""
              MATCH (d:Document { sha256: $sha256 })
              MERGE (s:Segment { sha256: $hit256 } )-[:SEGMENT_OF]->(d)
              ON CREATE SET s.content = $content, s.hlcontent = $hlcontent
              WITH s
              MERGE (q:Query { str: $qstr })
              WITH q, s
              MATCH (question:Question { ref: $qref })
              MERGE (s)-[:MATCHES]->(q)
              MERGE (q)-[:ABOUT]->(question)
            """, sha256=doc['sha256'], qstr=update['query'], content=hit, 
                hlcontent=hl, hit256=hit256, qref=update['qref'])
            tx_results.append(tx_result)
  
    return neo4j_summary(tx_results)

  def gather_segments(self, solr_results):
    docs = []
    for i, solr_doc in enumerate(solr_results.docs):
      solr_id = solr_doc['id']
      sha256 = solr_doc['sha256'][0]
      highlights = []
      if solr_id in solr_results.highlighting and 'content' in solr_results.highlighting[solr_id]:
        highlights = solr_results.highlighting[solr_id]['content']
      hl256 = [sha256str(hl) for hl in highlights]
      docs.append({ "sha256": sha256, "highlights": highlights, "hl256": hl256 })

    return docs