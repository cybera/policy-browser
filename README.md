# hey-cira
repo for various CIRA project deliverables

## Running w/ Docker

1. Install [Docker](https://www.docker.com)

2. Build the Docker image(s)

  ```
  bin/build
  ```

3. Scrape CRTC site for documents

  ```
  bin/scrape
  ```

4. Start Neo4j and Solr

  ```
  bin/neo4j start
  bin/solr start
  ```

  Persistent data for these containers will be stored under *data/neo4j* and *data/solr*. It is not intended to be checked in and is ignored by git.

5. Convert PDF, doc, etc. files to raw text

  ```
  bin/process-docs
  ```

  This will create both copies of the original files and .txt conversions named using a sha256 hash of the contents of the original file. The copies will be found under *data/processed/hashed*, and the .txt conversions will be found under *data/processed/raw_text*. Metadata for the files, including the filenames is stored in .json files under *data/processed/meta* by this process (although, ideally, this should be done in the scraping process, as noted in some code comments there).

6. Import data into Neo4j

  ```
  bin/wrangle-neo4j
  ```

7. Import Neo4j Document nodes into Solr for fuzzy text searches

  ```
  bin/script import/neo4j-to-solr.py
  ```

  Currently, this is a one-time process, though we should probably consider making it a script that can be run multiple times, simply importing new Document nodes or ones that have changed since the last run.

## Getting started with Neo4j

When running Neo4j on your local machine, you can access it in a browser via: [http://localhost:7474](http://localhost:7474). When accessing it at an API level, we use port 7687 and, if we're doing this from another Docker container as opposed to the host machine, we use *neo4j* instead of *localhost*. So the access point from within another Docker container is: *neo4j:7687*.

Neo4j uses [Cypher](https://neo4j.com/docs/developer-manual/current/cypher/) to retrieve graph nodes and relationships matching some pattern.

Here are some example queries that can be run on this dataset:

Count all the nodes or all the relationships in the database:

  ```
  // How many nodes in total?
  MATCH (n)
  RETURN count(n)
  ```

  ```
  // How many relationships in total?
  MATCH ()-[r]->()
  RETURN count(r)
  ```

Show 10 organizations:

  ```
  // Organizations
  MATCH(n:Organization) 
  RETURN n 
  LIMIT 10
  ```

Show organizations and people related to them, along with the relationship:

  ```
  // Organizations and people
  MATCH (o:Organization)<-[r*1..2]-(p:Person)
  RETURN o,p,r
  LIMIT 25
  ```

Wipe the database (useful when you're working on something to do with the imports):

  ```
  // Delete everything!
  MATCH (n) DETACH DELETE n
  ```

  Note that you can be much more specific in your deletions if you don't want to wipe everything. For example, when working on Solr search imports, you might want to occasionally wipe Queries and Segments:

  ```
  // Delete queries and results
  MATCH(n) 
  WHERE n:Segment OR n:Query 
  DETACH DELETE n;
  ```

The basic pattern of a Neo4j query is:

1. Specify one or more `MATCH` patterns. These can include node properties (`MATCH (n:SomeType { prop1: 'some value'}))`, though more complex property matching is probably best done in the next step.
2. Optionally specify a `WHERE` clause, joined by logical operators (such as `AND` or `OR`), specifying further conditions on properties of any nodes referenced in step 1.
3. A `RETURN` clause, specifying what you want back. If you want to see a relationship as well, you should reference and return that. You can dictate the reference name in the `RETURN` clause by using `AS`, similar to how you would do this in SQL.

### Adding data to Neo4J

Adding data isn't very different from querying it. You don't have to specify your schema beforehand. New node labels and properties are created simply by referencing them when creating a node. You can `MATCH` before doing a `CREATE` or `MERGE`, and when creating/merging, you don't need to specify a `RETURN` clause. In **most** cases, you'll probably want to `MERGE` instead of `CREATE`. `MERGE` will first see if it can match an existing node, whereas `CREATE` always makes a new one.

Merging can seem to do some weird things when you're not thinking about it carefully. [This blog post](https://neo4j.com/developer/kb/understanding-how-merge-works/) makes for good reading (and re-reading). The key thing to keep in mind is that, when merging a larger pattern, Neo4j will create all **new** nodes whenever **any** part of the pattern isn't matched. Sometimes you want this. Sometimes you don't. When you don't, simply split your creation into separate `MERGE` statements so that in each case, when the statement **doesn't** match, you actually want Neo4j to create new nodes.

## Getting started with Solr

### Why Solr?

Neo4j provides a good way of modeling the relationships we can find, and some of that information can be easily obtained from structured documents (html submission forms that come with many submissions). However, a lot remains that is unstructured in large blocks of text. We may be able to use various algorithms to extract good information from that, but we'd like to reduce the amount of useless text those more advanced techniques are applied to. The type of fuzzy matching that Solr makes possible can help us extract segments of text that are most likely to contain useful information, and these segments can be further refined to get more structured data to model in Neo4j.

Plus, [they used it on the Panama Papers](https://neo4j.com/blog/analyzing-panama-papers-neo4j/)!

### Web interface

The web interface can be accessed from [http://localhost:8983](http://localhost:8983/) after Solr has been started. In practice, this isn't quite as useful as the Neo4j web interface. Since API requests are also sent directly as HTTP requests, your code will reference something very similar: "solr:8983/solr/cira". Again, since our code is generally **not** running directly on the host machine, but within its own Docker container, we're using the Docker compose reference of "solr" instead of "localhost".

### Solr Query Basics

Solr queries are sent via HTTP requests, and results are HTTP responses. Results can be returned in a number of formats, including XML and JSON. We've only used JSON in our code so far. [The documentation on the Query Parser](https://lucene.apache.org/solr/guide/6_6/the-standard-query-parser.html) is pretty good for figuring out what you might want to put in your query. There's a good collection of logical operators, wildcard matching, and fuzzy match operators. 

The first part of a query string is usually the field you're matching. In our case, it'll almost always be "content". So to search for references to "network speed" in our documents, we might form the query: 'content:"network speed"'. What if we want to grab document sections where people are talking about things like "network needs higher speed" or "network is too slow"? Well, we could choose to be a bit fuzzier with the amount of words we allow between "network" and "speed". So, 'content:"network speed"~2 would allow 2 "edits" to the tokens in the search string in any match. And we could add extra conditions to allow variations: 'content:("network speed"~2 OR "network slow"~2).

There are a lot of different things you can do here, and the above only scratches the surface. One thing you will likely want to do is use the "highligher" functionality. This returns separately the blocks of text that matched your query in each document. It will even highlight (hence the name) the match within those blocks. Here are some useful parameters to help with that...

These are pretty much required for the highlighter to work:

  - `hl=on`
  - `hl.fl=content`

These are more optional:

  - `hl.fragsize=500`: This would create blocks of roughly 500 characters around the match. This is useful for us because we'd actually like to import enough context around our searches back into Neo4j.
  - `hl.encoder=`: Usually we want to turn this off, but it can be used to encode various html values in the string so that they can be inserted directly into html code.
  - `hl.tag.pre=`: When using the "original" highlighter, this is `html.simple.pre`. It defaults to `<em>` as the start tag around a matched word/phrase.
  - `hl.tag.post=`: When using the "original" highlighter, this is `html.simple.post`. It defaults to `</em>` as the end tag around a matched word/phrase.
  - `hl.snippets=200`: Maximum number of matched blocks of text *per* document. We'll probably want to set this high enough to ensure that we return all possible matches within our documents.
  - `hl.method=unified`: The newest (and recommended, though it isn't yet the default) highlighter.

Some other usefult Solr query parameters:

- `fl=`: a comma-separated list of fields to include in the search. To cut down on clutter, you could use something like `fl=id,sha256,name`, which would avoid bringing back the full text of a document. If you're using a highlighter to return matched blocks, you don't really need to see the full document in this context anyway.
- `rows=`: the maximum number of rows to return. The default is 10. Often, we're going to want to return *all* results and re-import them into Neo4j.

All of these query parameters can be added to a Solr search by joining them with `&` on the URL. A quick way to get started in a browser is to go to either [the admin query interface](http://localhost:8983/solr/#/cira/query) or [the browse interface](http://localhost:8983/solr/cira/browse).

### Segment script

Ideally we'll eventually include this in our document browser, but for the time being, one of the easier ways to run Solr searches on our data will be through `bin/segment`. Here are the basics:

To run our network speed query:

  ```
  bin/segment 'content:"target speeds"'
  ```

Matches to the actual search should show up in **bold** text in your terminal. On my screen, this shows "10 of 481 documents". To get the entire set, then, I could run:

  ```
  bin/segment --rows=481 'content:"target speeds"'
  ```

  (Note: While usually, you could do something like '--rows 481', there's a bit of bugginess in the way we're passing parameters that will break here. So use '--rows=481' instead).

Finally, if I'm happy with those results and want to re-import them to Neo4j as "Segment" nodes related to the Document nodes where we found them *and* to the Query we're running to find them, I can add an "--add" flag:

  ```
  bin/segment --rows=481 --add 'content:"target speeds"'
  ```

Now, in Neo4j, you could do something like:

  ```
  MATCH (q:Query { str: 'content:"target speeds"' })
  MATCH (o:Organization)-[r1:ACTING_AS]->(:Participant)-[:PARTICIPATES_IN]->(sub:Submission)
  MATCH (sub)-[r2:CONTAINING]->(d:Document)
  MATCH (q)<-[r4:MATCHES]-(s:Segment)-[r3:SEGMENT_OF]->(d)
  RETURN q,o,d,r1,r2,r3,r4
  ```

This would show all of the segments matched, what documents they came from, and ultimately what companies seem to be attached to those submissions.

With some slight modifications, you could generate a table to show the same data:

  ```
  MATCH (q:Query { str: 'content:"target speeds"'})
  MATCH (o:Organization)-[r1:ACTING_AS]->(:Participant)-[:PARTICIPATES_IN]->(sub:Submission)
  MATCH (sub)-[r2:CONTAINING]->(d:Document)
  MATCH (q)<-[r4:MATCHES]-(s:Segment)-[r3:SEGMENT_OF]->(d)
  RETURN q.str,o.name,d.name,s.content
  ```

Another slight modification would allow us to see how many distinct organizations we have matches for:

  ```
  MATCH (q:Query { str: 'content:"target speeds"'})
  MATCH (o:Organization)-[r1:ACTING_AS]->(:Participant)-[:PARTICIPATES_IN]->(sub:Submission)
  MATCH (sub)-[r2:CONTAINING]->(d:Document)
  MATCH (q)<-[r4:MATCHES]-(s:Segment)-[r3:SEGMENT_OF]->(d)
  RETURN COUNT (DISTINCT o)
  ```

Comparing that with a simple count of organizations allows us to figure out how much we still need to search to get a particular type of answer:

  ```
  MATCH (o:Organization) RETURN COUNT(o)
  ```

Currently on my data set, that search seems to provide matches for 39 out of 128 identified companies.

## Deprecated: old local Ruby installation instructions

1. Install rbenv

  ```
  brew install rbenv
  ```

2. Grab the latest stable release:

  ```
  rbenv install 2.4.2
  ```

  Use the above release to ensure compatibility. If, for some reason, you need to upgrade ruby, run `rbenv install -l` to see what versions are available. Update this document and `.ruby-version` in the project root to reflect the new version.

3. Append the following to your .bashrc or .zshrc:

  ```
  eval "$(rbenv init -)"
  ```

4. Resource your shell init script or open a new terminal.

5. Change to the root project directory and check that it's using rbenv's ruby:

  ```
  cd hey-cira
  ruby -v
  ```

6. Install required gems:

  ```
  gem install nokogiri
  gem install httparty
  gem install pry
  gem install mechanize
  gem install yomu
  gem install sqlite3
  ```