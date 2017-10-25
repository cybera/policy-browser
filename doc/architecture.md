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