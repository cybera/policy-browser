# Introduction

The problem, in a nutshell: We have a large number of documents, some of them more structured than others. At minimum, we can easily organize these documents into Public Processes and specific submissions to those public processes (Interventions). These Interventions come from individuals, companies, and other organizations. There may be follow ups to earlier ones in the same Public Process. Some may be responses to questions asked in other Interventions. A particular individual, company, or organization may make Interventions in several Public Processes because the processes themselves occupy a certain policy area and/or the intervener has interest in several policy areas.

Certain interveners may share common approaches and/or interests. Their opinions and/or arguments may change over time. The overall sentiment, expressed by all of the interveners may change over time as well.

All of these (and likely more) pieces of knowledge can give important context to the understanding of any single document and the overall debate around a particular policy. Unfortunately, that knowledge can also require close reading through many separate documents. We want to make it easier for anyone to understand this material without detailed knowledge of the processes and the history of a particular issue/intervener.

# Components

We'll be working on 3 major pieces to get from the current set of documents to a more accessible public process browser.

## Metadata Database

Assuming we can extract various pieces of reliable metadata from these documents, we'll need a way to store and retrieve that data without always having to go back to parsing through individual files. We can then either query the database directly or generate intermediate datasets for explorations and visualizations.

We're starting out with an SQLite database, but we'll likely want to move to a more heavy duty centralized one at some point. Since we're not entirely sure what information we'll be able to find at this point, we won't be creating individual columns/tables for specific metadata (at least, not yet). We'll start with storing values based on a document (or segment) identifier, and a key. We'll likely need to also record the source and version of the metadata. See the data refining section below for why.

## Visualization

There are probably 2 major areas where we'll be visualizing the data. One is the obvious end user interface, where we hope to present the data from the documents in an interesting way that increases an average citizen's understanding of CRTC processes and emerging policy. At the most basic level, we'd like it to be largely dynamically generated from the data, so that it might be used more generally beyond what we're looking at now. But ideally, it would also be interactive, so that every citizen could explore the dataset in their own way and ask their own questions.

The second major area where visualizations will likely be useful (but also where they can be a bit more utilitarian) would be in helping us sort through and refine the metadata. We may be able to do a lot through clever scripts, but there may be areas where we need to put a "human in the loop". A task that might be very difficult to do via machine learning alone or take a very long time for a human to do, might be able to be done quite quickly with a decent interface to help a human interact with machine-generated suggestions.

One very simple example would be in selecting from competing versions of metadata that we get through different sources/methods. Right now, our "visualization" for that is a simple script that shows us how many cases a particular piece of metadata from a particular source can be found in. That can alert us to which sources are more reliable than others for getting a particular piece of metadata.

## Data refining

This is where the real dirty work gets done. While it would be nice to call a single master script every time we improve some aspect of scraping or data wrangling, we will likely not want to continue building everything from scratch due to the time that would take. We will also likely be refining data throughout the project, not just as a first step. As we gain better understanding of what's there through exploration/visualization, we'll likely get better ideas about how to get higher quality information. Some parts of this process will depend on earlier data refinement, which means (a) we won't always have to regenerate everything and (b) when we do have to regenerate data that is depended on by later data refinement scripts, we'll want to regenerate that later data as well, even if the scripts to generate it have not changed.

We'll also likely run into imperfect situations where we have, say, one way of getting a highly reliable version of a particular piece of metadata, but one that doesn't work for every document, and another way of getting a less reliable version of that metadata for more (or all) documents. We may have no reliable single source for a piece of metadata, but there may be a way to look at multiple sources to extract a more reliable version. For a more concrete example, consider missing information in an address field of the HTML forms filled out during a submission, but where the document itself contains that information, which may be extractable via "named entity" analysis.

If we do end up using machine learning techniques, they'll likely be focused in this area to get more high quality metadata.

# TODO: Story ideas

## Systems

Story: As hey-cira makers, we'd like to not have to always think about rebuilding the database whenever there's a change or addition to data refinement scripts.
Tasks:
  - Set up a server in RAC that can run our Docker containers
  - Set it to build a new version of the docs.db when changes are made to "wrangling" scripts
  - When finished, push a new version of the docs.db to our hey-cira Swift container

Story: As hey-cira makers, we're worried that continually crawling the CRTC website and downloading fresh documents all the time might get us blocked by their network folks, so it would be nice to only do that when we absolutely have to. Even though we're less likely to get into trouble rebuilding the database from already downloaded documents, we want those rebuilds to be as quick as possible.
Tasks:
  - Review scraping script to ensure that it won't download documents that are already downloaded
  - Consider using versioning (experimentally being used in the "wrangling" scripts) to help avoid even having to scrape certain sections at all (if they've already been scraped with the latest "version" of the scraper)
  - Use existing versioning to smartly avoid re-generating metadata when the scripts that produced it haven't changed. Make sure to also cover the case where the script has already been run, but a document has been added. Can we run the entire processing pipeline and have it just pick up those new documents?
  - Use existing versioning (and/or perhaps other mechanisms) to smartly re-generate metadata that's dependent on other metadata when that earlier metadata is regenerated

Story: As hey-cira makers, it would really be nice to have a more centralized source of truth for a lot of this stuff. When do we graduate from SQLite?
Tasks:
  - Before diving in, review whether we're really at the point of needing to do this.
  - Create a real database!
  - Put some really simple backup system in place (or decide that we're okay with regenerating everything if necessary)
  - Give us a secure way of querying it from our laptops!
  - Add a simple web-server (either on the same RAC server or a different one) for internal use
  - Add our metadata_summary results to display on a simple webpage and/or any other information that might exist when this story is looked at that we think will be helpful to easily look at in a web browser.

## Tools

Story: As hey-cira makers, occasionally we just want a quick notebook to be able to play around with some ideas.
Tasks:
  - Create a "bin" script that uses the "cybera/hey-cira/python" docker container (which has the Anaconda distro) to fire up a Jupyter notebook session
  - Create a notebooks folder in our project and point the jupyter notebook to that initially (but leave the Docker container pointing at the project root) for easy saving/opening of existing notebooks
  - Figure out how to set any default paths, etc. that make it easier to try out an idea quickly.

## Exploration

Story: As someone interested in what these documents are all about, what can we do right now with the metadata that we have?
Tasks:
  - Take a day to explore the currently derived metadata in R (or platform of choice)
  - If it's a new platform, identify any tooling that may make it easier for people to do the same type of exploration and/or reproduce results
  - If you're refining any of the metadata further in your scripts, make note of that. If there's an easy way to add that to a more general refinement script, do that before wrapping the story up, or create new stories to add that refinement to the scripts. Don't let this distract from the exploration. It can be done after, and we're really only interested in data that we think might be more generally useful.

## Machine Learning / Data Science Techniques

Story: As hip, bleeding edge Cyberans, we're keen to try out the latest and greatest ML techniques, especially if they can help sort through this data. We should keep an ideas list and review it from time to time.
Tasks:
  - Create list of ideas for data refinement, to review in standups, adhoc meetings, and/or backlog grooming
  - Decide on some basic decisions/information we'd want to get before trying out an idea or to decide which ones to prioritize (i.e. Have we used the technique before? How quickly do we think we'd be able to test it out? Would it help refine metadata we're actually interested in? Are there other easier ways to get that refined metadata?)

Story: Our named entity extraction is pretty generic. As people interested in the CRTC policy domain, we'd like something that is a bit smarter about what entities might look like in an Intervention document.
Tasks:
  - Investigate ways of training an existing named entity classifier
  - Investigate other methods of getting what we're really interested in (potentially names of companies, people, places, dates, etc.)
  - If it's simple (1-2 days), hack out a prototype. Otherwise, create some more specific stories.

Story: As a person interested in CRTC policy, dividing intervention sumissions into groups would probably be helpful. But what would that even look like?
Tasks:
  - Use the quickest and dirtiest available approach to doing all or one of LDA, Word2Vec, or [LDA2Vec](http://multithreaded.stitchfix.com/blog/2016/05/27/lda2vec/#topic=38&lambda=1&term=) to divide our current submissions into topics
  - Consider that we already have a very good way of dividing the submissions by the particular public process they're related to (i.e. the public process number), and see if there are ways of dividing information within the same public process and/or finding other groupings across public processes that would be helpful
  - Consider using this as the basis for a "human in the loop" tool. Could it be useful for helping a human to organize documents even if it can't fully organize them itself?
  - Write up recommendations for building system components either as stories or other documentation and share with the group.
  
## Interface

Story: As an average citizen, I'm not going to be interested in any of this unless I can load it up and look at it in my web browser. We may not have the killer app yet, but let's get *something* up that we can iterate on.
Tasks:
  - Set up a RAC server w/ Apache and a simple web framework (we'll have to fight out which one, but we may want this to be a little more familiar/flexible/efficient than R's shiny - RoR or Django would be some obvious contenders)
  - Set up a simple document browsing interface: Click a link, see the text of a submission
  - Any other bells and whistles for a first cut? Things that we could get done in 1-3 days?