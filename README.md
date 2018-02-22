# hey-cira
repo for various CIRA project deliverables

<!-- TOC depthFrom:1 depthTo:6 withLinks:1 updateOnSave:1 orderedList:0 -->

- [hey-cira](#hey-cira)
  - [Running w/ Docker](#running-w-docker)
  - [Configuration](#configuration)
  - [Getting started with Neo4j](#getting-started-with-neo4j)
    - [Adding data to Neo4J](#adding-data-to-neo4j)
  - [Getting started with Solr](#getting-started-with-solr)
    - [Why Solr?](#why-solr)
    - [Web interface](#web-interface)
    - [Solr Query Basics](#solr-query-basics)
    - [Segment script](#segment-script)
  - [The Hey CIRA Browser](#the-hey-cira-browser)
    - [Running the browser](#running-the-browser)
    - [Adding new styles of navigation](#adding-new-styles-of-navigation)
    - [Adding to the navigation selector](#adding-to-the-navigation-selector)
    - [Navigation links](#navigation-links)
    - [Adding a new style of detail display](#adding-a-new-style-of-detail-display)
    - [TODO](#todo)
    - [CSS, Javascript, and Bootstrap](#css-javascript-and-bootstrap)
  - [Transformation Scripts](#transformation-scripts)
    - [Preconditions](#preconditions)
    - [Helper functions](#helper-functions)
    - [The .skip-transforms file](#the-skip-transforms-file)
    - [I just want to change some data. Why do it this way?](#i-just-want-to-change-some-data-why-do-it-this-way)
  - [Deprecated: old local Ruby installation instructions](#deprecated-old-local-ruby-installation-instructions)

<!-- /TOC -->

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

  The neo4j database will be available at [localhost:7474](localhost:7474). In order to make the next step work, change the password to 'password'.

5. Convert PDF, doc, etc. files to raw text

  ```
  bin/process-docs
  ```

  This will create both copies of the original files and .txt conversions named using a sha256 hash of the contents of the original file. The copies will be found under *data/processed/hashed*, and the .txt conversions will be found under *data/processed/raw_text*. Metadata for the files, including the filenames is stored in .json files under *data/processed/meta* by this process (although, ideally, this should be done in the scraping process, as noted in some code comments there).

6. Import and modify various other pieces of the Neo4j database  
  See the [Transformation Scripts](#transformation-scripts) section for more details.

  ```
  bin/transform
  ```

## Configuration

You'll need to create configuration files for logging into Neo4J and getting access to administrative functions on the browser. There are already templates in the *config* folder (with a *".example"* extension). Make a copy of the files where the extension is removed and update the Neo4J username and password to whatever you set for Neo4J. Update the browser admin password to whatever password you want to use to log in as an admin (it simply has to match what's submitted).

```
cd config
cp browser.yml.example browser.yml
cp neo4j.yml.example neo4j.yml
```

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

## The Hey CIRA Browser

The "prototype browser" has been refactored, renamed, and moved to the *app* folder. It uses Sinatra as a basic framework, with ERB templates and Bootstrap CSS.

### Running the browser

```
bin/app
```

The app will be available at [localhost:4567/browser?ppn=2015-134](localhost:4567/browser?ppn=2015-134)

### Adding new styles of navigation

Adding a new navigation style invovles two main tasks:

1. Gathering the data needed for navigation

  You'll find code for doing this with existing styles of navigation under *app/helpers/navigation*. To add a new style of navigation, create a new file in *app/helpers/navigation* with the following:

  ```ruby
  module Sinatra
    module NavigationHelpers
      class YourHelperClassName < NavigationHelper
        def data
          # Optional: Run a Neo4J graph query, using any safe parameters that have been passed
          #           in via the request. You don't have to access the database. If it made sense
          #           to supply some sort of static navigation elements, you could simply create
          #           those in this method.
          #

          # results = graph_query("MATCH (n) WHERE ID(n) = $id", id:params[:id])

          # Optional: Do whatever transformations on the data you want to prepare it for display.
          #           Remember that ERB templates provide a lot of flexibility, so you can do many
          #           things directly in them, but operations like grouping and sorting are best
          #           done here.

          # transformed_results = results

          # Required: Make sure the last line of the method returns the data in the form that you
          #           will be using it in the associated ERB template. You can explicitly call
          #           "return" or let the Ruby language implementation implicitly assume the last
          #           line is the return value.

          # transformed_results
        end
      end
    end
  end
  ```

  By convention, the app assumes that you have a matching ERB template for this in *views/navigation*
  named *your_helper_class_name.erb*. There are other conventions that you can find in `NavigationHelper`
  and its superclass, `DataDisplayHelper`, under the *lib* folder. You can override these if necessary,
  but hopefully you shouldn't have to. If you're doing that often, it's probably time to consider updating
  the convention.

2. Deciding how to display that data

  The app expects to find *views/navigation/your_helper_class_name.erb*. The template filename is the
  "snake case" or "underscore case" version of your "camel case" class name, without any of its containing
  modules. "Foo" turns into "foo". "FooBar" turns into "foo_bar". Etc.

  These templates use [ERB](http://www.kuwata-lab.com/erubis/users-guide.html), a common templating engine
  in Ruby apps. There's plenty of documentation floating around online about how to use them, but here are
  the basics: `<%= some_ruby_code %>` will put the results of `some_ruby_code` into your rendered html. Often
  the "code" is simply a variable reference. `<% some_ruby_code %>` (notice no `=`) just runs the code within.
  It doesn't render anything. Why would you want this? It's good for things like looping and conditionals *within*
  your ERB template. So, for example, you could do the following to loop through an array of strings and render
  them in a list:

  ```erb
  <ul>
    <% string_array.each do |str| %>
      <li><%= str %></li>
    <% end %>
  </ul>
  ```

  You could get the same results using raw ruby code:

  ```ruby
  "<ul>" +
    string_array.map { |str| "<li>#{str}</li>" } +
  "</ul>"
  ```

  But when the bulk of code is actually HTML, it's nice to just occasionally hop into Ruby-mode when you need
  it. That's why most of the structure of a website will tend to be done in ERB. Read up on MVC architecture
  to dive deeper into this separation of display and control logic if you're interested, but the above should
  be good enough for most of what you'll want to do here.

  One last question you may have: where do thos useful variables come from? Well, there's a bit of magic going
  on with Sinatra's `erb` helper and the classes in this application play with that a bit further, but bottom
  line is that you're guaranteed to have access to any variables you return in the `data` method of your
  `YourHelperClassName` above. The variables will be named the same as the keys of that hash. The other things
  you should have access to are various "helper" methods. See, for example, *helpers/basic.rb*. You can find
  examples of where some of those methods are used in various ERB templates.

  See the [Sinatra documentation](http://sinatrarb.com/extensions.html) for more extensive information on
  how to writer helpers and add them in.

### Adding to the navigation selector

Ha! You actually shouldn't have to do this. As long as you follow the conventions, your new navigation
style should be added to the list automatically. The parameter name will be the "snake case" version
of your class name and the display name will be the class name itself by default. You can override
either or both of these if necessary.

### Navigation links

Any links that you generate in your navigation HTML should have a `navigation=` parameter that refers
back to your navigation (so that clicking a link doesn't change the navigation style), a parameter
or several parameters that provide a way of finding the object the link refers to (often simply an
ID value to look a graph object up directly), and a `detail=` parameter specifying a compatible
display style that will be able to handle the parameters you've provided.

### Adding a new style of detail display

Adding a different style of detail display is very similar to adding a different style of navigation.
Instead of extending `NavigationHelper`, you extend `DetailHelper`. And instead of putting your ERB
template in *views/navigation*, you put it in *views/detail*. Here's your template for the helper:

```ruby
module Sinatra
  module DetailHelpers
    class YourHelperClassName < DetailHelper
      def data
        # similar code to a NavigationHelper
      end
    end
  end
end
```

There currenly isn't any way of choosing different display styles explicitly (the navigation link tends
to dictate the display style), but in theory, this wouldn't be too hard to add.

### TODO

- We should probably add some way for both navigation and detail displays to specify the parameters they
are compatible with and/or output so that we can give some smart options for mixing and matching them
without explicitly having to code them. This would also help in checking for bad parameters if someone
realizes they can try different (potentially incompatible) methods simply by changing the GET parameters
in their browser.

### CSS, Javascript, and Bootstrap

We're using [Bootstrap](https://getbootstrap.com/docs/3.3/) as a UI framework. It will handle the vast majority
of things you might want to otherwise do in CSS and/or Javascript. See their extensive documentation for good
code snippits you might want to use. As long as you use the right CSS class names and HTML property values,
they often "just work".

We can also access JQuery directly if we need to do something in Javascript that Bootstrap isn't already doing
for us. Finally, we can put any of our own .js and .css files in *public/js* and *public/css* respectively.
They can then be referenced within any ERB HTML code as *js/some_js_file.js* and *css/some_css_file.css*. We
already have a *public/css/layout.css* file started out with some minor tweaks.

## Transformation Scripts

After creating several random scripts to process our data and a few scripts that just grew and grew and grew, we finally have a mini-framework that should help avoid some of the common problems with having a team of people all trying to make tiny improvements to the data at the same time.

Here are the basics: If you create a file with the following code and put it in "scripts/wrangling/transformations", it will run whenever someone runs: `bin/transform`:

```python
class WhateverNameYouLike(TransformBase):
  DESCRIPTION = "A short description of what your transformation does"

  def match(self):
    return ["hello", "world"]

  def transform(self, data):
    for item in data:
      print(item)

    return ["Some description of what happened"]
```

The above will only end up printing the following:

```
hello
world
```

and it's not the *simplest* script that you could have that would run (you don't even really need the `match` or `transform` method, as there are default implementations in `TransformBase` that return `True` and `["Not implemented"]`), but it illustrates a structure you'd usually want to have.

Some key requirements/conventions:

1. `match` should return something "truth-y" *if* you want to go ahead with the transformation, or something "false-y" if you want to skip the transformation.

  - Truth-y values: `True`, a non-empty list (`[1]`), a non-empty string (`"foo"`), a non-zero number
  - False-y values: `False`, `[]`, `""`, `0`

2. In the `transform` function, `data` will be whatever you return in `match`. This allows you to avoid having to query the same data twice (once to see if it hasn't had your transformation applied to it and again to do the actual transformation) if that makes sense. There's nothing requiring that you *use* the data parameter, and in some cases, especially when your entire "transformation" is just a slightly more complicated `neo4j` query, you'll simply ignore it. The idea here is to still remain pretty flexible to the various transformation tasks we might want to do.

3. The `transform` function should return an array of strings. What should those strings be? Simply a description of what was done. There are some helper functions, such as `neo4j_summary`, which take a Neo4J `result` (or array of them), and return a good summary (in this case, separate strings detailing the number of `Labels`, `Relationships`, etc. created/deleted/modified). You could just return `["Did stuff"]`, but try to make it something that helps whoever's running it understand what just got changed about the data.

### Preconditions

There's one more function that you may want to implement in some cases: `preconditions`. It runs *before* `match` and is pretty open ended. You could do necessary setup in here (any variables set on the transformation object will remain accessible in the `match` and `transform` calls), you could set `self.preconditions_met` to `False`, or you could call another function, such as `self.check_file` that will set `preconditions_met` for you conditionally (in this case, if a file doesn't exist).

So say your transformation depends on a CSV file that you're crafting, and it's not quite ready for prime-time (or you want to have it generated/accessed in some other way that may mean it's not there when people run `bin/transform`). You want to check in your code (because not checking in code is BAD!!!), but you don't want to mess everyone else up. You could add a `preconditions` function and run `self.check_file("path-to-your-csv")`. If it doesn't exist, the transformation will be skipped (and the reason why reported out to the person running it).

### Helper functions

There are some commonly used functions and imports that are added automatically to every transformation without you having to explicitly import them. For example, to do a Neo4J query, just do the following in your transformation script:

```python
with neo4j() as tx:
  tx.run("MATCH (n) RETURN COUNT(n)")
```

You also have access to `neo4j_summary` (described above), `neo4j_count` (add a `RETURN COUNT(*)` to an initial match clause and extract the single integer response), the `os.path` module (accessible as `path`), and various project paths via `project_root` (`project_root` gives you "/mnt/hey-cira", `project_root.data` gives you "/mnt/hey-cira/data", and so on).

You can add other helper functions in one of two ways:

1. Add a function to `TransformBase` which will be inherited (and can be overridden) by subclasses, and can also have access to any instance variables.

2. Set `transformation.some_name = function_or_mod_you_want_to_add` to the `init_transformation_mod` function in *scripts/wrangling/transform.py*.

There are advantages and disadvantages to either method. The 1st is really useful when you want to exploit some object orientation to specify general behaviour that can be used across transformations with custom hooks (overridden functions in specific transformations). The 2nd is useful when you just want a function or an existing python module without having to import it.

### The .skip-transforms file

If someone's checked in a transformation that breaks for you and you don't have time to deal with it and/or there's a particular transformation that never gets skipped but takes a long time, you can add the class name of the transformation on a single line of `.skip-transforms` in the project root. This file is ignored by git, so it won't get checked in.

Ideally, you should *not* need this file. Every transformation should have a relatively quick way of figuring out whether it needs to be run (in the `match` function), and once run, it should have transformed all of the results that would have shown up in the `match` function, so that running it again would have `match` returning a "false-y" value.

Why might this occur? Here's an example: Currently the `ImportZipOranizationRelationships` transformation tries to fuzzily match up references to an organization from pieces of the name of files contained in .zip files we've scraped from the CRTC site. We *want* `match` to indicate that the transformation should run if there are any files that match the naming scheme convention that seems to be used within those .zip files. However, due either to the fuzziness or an organization not existing yet in the database, we may not be able to match all of the files that we think we could. In theory, at a later point, that same transformation could be run and match up more files (say if someone else's script has since added some more organizations to match to). However, it does take a long time, which is annoying when you're working on something else and you know you're not going to get any new information from running it again. If you put it in your `.skip-transforms` file, it'll be reported as "skipped", to remind you that you're doing this on purpose, but you can stop having to wait for it to run all the time.

### I just want to change some data. Why do it this way?

Here are the advantages that you get for free when you follow the above conventions:

1. You don't have to say "remember to run this new script when you check out the latest code". If we all simply get into the habit of running `bin/transform` every so often, we'll automatically get the transformations that others are checking in.

2. You'll get fewer merge conflicts than constantly modifying `neo4j-import.py`. It'll also be easier to find your code in its own self-contained file.

3. You don't have to think to much about *where* in the pipeline your script should be run. There are still some places we could step on toes here, but if you use your `match` function to look for the existance of untransformed data *and* the information you need to transform the data, only returning something "truth-y" if that's the case, then the transformation mini-framework will manage figuring out *when* to run it. If another transformation needs to be run to create the data your transformation needs, it'll be run first and yours will be run in the next cycle. `bin/transform` will run up to 20 cycles of transformations. Any transformation will only ever be run once during these cycles, and the script will stop before the 20 cycles are up if *none* of the transformations met the conditions to be run in the previous cycle.

4. You can make the code within your transformation as messy as you want, break it into as many helper functions, etc. without having to worry as much about breaking code in other transformations (within reason, of course!).

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
