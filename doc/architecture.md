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
Why?: Generic NE chunkers give some promising results. You can see those in the docentities table. However, there are also a lot of misfires, probably due to the NLTK chunker being a bit too generic and also the fact that we're dealing with more highly specialized documents.

Story: Once we have our own named entity chunker, we can start thinking about how to continually train it to be better. Up to this point, we've always approached training as a one-time thing. We come up with the best process we can, do one last training run, and that's it. But what about introducing "human in the loop" style training, where we allow corrections to mistakes the algorithm makes, and we use those corrections to generate better training data for perhaps an overnight process?  
Tasks:
  - Requires the above story to be finished, where we already have our own NE chunker.
  - Identify a piece of metadata where the custom chunker is making a mistake.
  - Figure out how we would correct that data via a database record change, making it obvious that it's a deviation from the generated version, without completely getting rid of the generated version (so that we can compare things later).
  - Figure out how to use the corrected data as the basis of an addition to the training set for the chunker.
  - Set up a training process that can be run manually to regenerate the chunker model (we know that something like this could easily be made into a cron task)
  - Figure out an interface to allow an end user (or admin) to make those changes
  - Consider for future stories how we might modify the interface to allow less skilled/trusted users to help out (i.e. some sort of consensus system where, if 3 different people correct the same piece of data, we make it an "official" correction)
Why?: I think this could be at the root of developing some really useful metadata. Turns out I'm [far](https://www.computerworld.com/article/3004013/robotics/why-human-in-the-loop-computing-is-the-future-of-machine-learning.html) from [the](https://blog.algorithmia.com/machine-learning-with-human-in-the-loop/) only [one](https://medium.com/kaizen-data/machine-learning-with-humans-in-the-loop-lessons-from-stitchfix-300672904f80) thinking [this](http://www.kritikalsolutions.com/blog/human-in-the-loop-crucial-for-machine-learning/). Going through this process on an NE chunker will get us thinking about how to do it in other areas of the project and perhaps other data science projects. It's an aspect of practical machine learning that we haven't really explored much.

# Top stories:

I'm thinking these could be some of the most useful "next up" stories:

- Interface: Simple document browser *done*
- Interface: Provide timeline view of when documents were submitted
- Exploration: What can we determine using the metadata as it currently sits
- Interface: Provide view of when documents according to which company/intervenor they were submitted by
- Machine Learning: Using _some_ algorithm to split documents into topics
- Our own NE chunker (possibly requiring our own Part-of-speech tagger)
- A simple human-in-the-loop system to correct NE chunker misfires

# Machine Learnin' Problem Formulations

Let's use this as a place to sketch out ideas of where we might apply machine learning and what problems we may have to solve to do so. Before we actually try one of these ideas, we should have:
1. The problem boiled down to a typical machine learning problem formulation, where we have a bunch of examples with some number of features and we're using them to make a single prediction.
2. We should have an idea of how much data we'd need and how hard it would be to get it. Would there be any creative ways of obtaining it? Or could we deploy it imperfectly and have human-in-the-loop style modification/addition to the data set? Could we bootstrap off of a more comprehensive dataset and just specialize at the last step?
3. We should have a good idea of what that information might be useful for in serving our larger goal of making these documents easier to browse and digest. How do we use the predictions once we have them?
4. What sort of machine learning approach do we think would give the most chance of success? For example, if we have a really small data set, maybe we want to consider just a simple linear or logistic regression over some really deep model?

- predict whether a case (or segment within a case) is a response to a previous case
  - high usefulness in organizing segments: even if we don't know *which* segment it is responding to, we could use the information to show segments that haven't yet been linked to the things they're responding to but are probably responses to *something*. This would allow a human to make these linkages without having to sort through the vast majority of segments that aren't responses.
  - small amount of data (and we would have to label all of it ourselves)
  - probably a very simple machine learning algorithm that wouldn't need lots of data and could run quickly
- topic extraction as a tool to help other labelling?
  - show segments that seem to be related and ask
    - are they related?
    - how are they related?
- any way we could turn it into a crowd-sourcing thing?
  - i.e. someone organizing their own information could help others and speed up labelling
  - how to know how much that would help speed things up?

# Continaul Process for Generating New Stories

With this project in particular, we can probably figure out a lot of where we want to go with it by just trying to browse/organize documents with it and trying to make that experience better. Here's a simple sketch for something we could be doing at regular (possibly daily?) intervals:

- Start organizing something by hand
- Note the pain points
- Think about how a ML process and/or user interface addition/change might aid that