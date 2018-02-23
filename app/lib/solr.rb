require "rsolr"
require "digest"



module SolrQueries
  mattr_accessor :solr_db

  class << self
    def connect(path="solr/crtc-docs", hostname="solr", port=8983)
      SolrQueries.solr_db = RSolr.connect :url => "http://#{hostname}:#{port}/#{path}"
    end
  end

  class SolrResults
    attr_accessor :results
    attr_accessor :query

    def initialize(results, query)
      @results = results
      @query = query
    end

    def docs
      if !@docs
        highlights = @results["highlighting"] || {}
    
        @docs = @results["response"]["docs"].map do |r|
          rhl = highlights[r['id']]
          r["sha256"] = r["sha256"].first
          r["name"] = r["name"].first
          r["segments"] ||= []
          r["segments"] += rhl["content"] if rhl
          r
        end

        sha256s = @docs.map { |d| d['sha256'] }
        orgs = graph_query("""
          MATCH (o:Organization)-->(d:Document)
          WHERE d.sha256 IN $sha256s
          RETURN o.name as name, d.sha256 AS sha256
        """, sha256s:sha256s)
        orgs = orgs.map { |o| { o["sha256"] => o["name"] } }.reduce({}, :merge)
        @docs.each { |doc| doc["organization"] = orgs[doc["sha256"]] }
      end
      @docs
    end

    def hits
      @results["response"]["numFound"]
    end

    def add
      this = self
      neo4j_db.queries do
        this.docs.each do | doc |
          sha256 = doc["sha256"]
          doc["segments"].each do | hlhit |
            hit = hlhit.gsub(/<em>(.*?)<\/em>/, "\\1")
            hit256 = Digest::SHA256.hexdigest(hit)
            append("""
              MATCH (d:Document { sha256: $sha256 })
              MERGE (s:Segment { sha256: $hit256 } )-[:SEGMENT_OF]->(d)
              WITH s
              MERGE (q:Query { str: $qstr })
              WITH q, s
              MERGE (s)-[:MATCHES]->(q)
              SET s.content = $content, s.hlcontent = $hlcontent
            """, sha256:sha256, qstr:this.query, content:hit, 
                hlcontent:hlhit, hit256:hit256)
          end
        end
      end
    end
  end

  class EmptySolrResults < SolrResults
    def initialize
    end

    def docs
      return []
    end
    
    def hits
      return 0
    end

    def add
    end
  end

  def solr_query(query, **params)
    query_params = { 
      "q" => query,
      "hl.fl" => "content", 
      "hl" => "on", 
      "hl.fragsize" => 500,
      "hl.encoder" => "",
      "hl.tag.pre" => "<em>",
      "hl.tag.post" => "</em>",
      "hl.snippets" => 200,
      "hl.method" => "unified",
      "fl" => ["id", "sha256", "name"]
    }

    params.each do |p,v|
      query_params[p.to_s] = v
    end

    results = self.solr_db.get :select, :params => query_params

    SolrResults.new(results, query)
  end
end
