# Doc2Vec Analysis of CIRA Data

## Introduction

NOTE: if you want the math equations to display in a non-latex way, the only way I could get them to work online was to install this chrome extension:
https://chrome.google.com/webstore/detail/github-with-mathjax/ioemnmodlmafdkllaclgeombjnmnbima/related

  For this analysis we decided to train a doc2vec model of the
documents submitted to CIRA from all organizations and individuals.
In this case, the network was trained on all documents, with
duplicate sentences, numbers, and sentences shorter than 15 characters
removed. As well, a stemmer was applied to the data set for training
which applies a mapping to for similar words conjugated differently.
For example, `application` and `apply` would both go to the 'root' word.
of `appli` while training the word vectors. Using `gensim`'s doc2vec
python library, a neural network can be trained using the following
python snippet:

```python
model = gensim.models.Doc2Vec(tagged,
                                dm = 0,
                                alpha=0.025,
                                size= 1500,
                                min_alpha=0.0001,
                                min_count = 10,
                                sample = 1e-4,
                                workers = 8,
                                dbow_words=1,
                                iter = 20,
                                window = 15,
                                hs = 0)
```
where `tagged` are the tokenized and labeled word vectors that were cleaned from the raw text documents, `dm` is the word model. In this case, `dm=0` implies the distributed bag of words model. `alpha` is the standard initial learning rate, `size` is the size of the word vector and the hidden layer of neurons. `min_alpha` is the smallest training rate. `sample` down-samples frequently used words, `workers` is the number of cores to use, `dbow_words` tells `doc2vec` to also train word vectors as well as document vectors. However, this does tend to slow down training, but I found it worked a little better for shorter search terms. `iter` is how many training epochs to go through, were typical values reported in the literature are between 10 and 20, `window` is how many words apart to calculate word probabilities for each token and finally `hs=0` tells `doc2vec` to use negative sampling instead of hierarchical softmax for training.

Once the model is trained, you can ask `doc2vec` to return to you 'semantically similar' statements to a statement you provide yourself. To do this, we envoke the `infer_vector` and `most_similar` methods as follows
```python
infer_vector = model.infer_vector(stemmed_tokens, steps=20, alpha=0.025)
similars = model.docvecs.most_similar(positive=[infer_vector], topn=num_return)
```
where here `stemmed_tokens` is the stemmed and tokenized sentence you're looking for (cleaned in the same way as the documents), and `steps` is how many training steps to do on your custom search. In this case, `doc2vec` will find the most similar sentences or documents to the one you provided based on the cosine similarity of the vectors you trained on as compared to the one you provided. In more mathematical terms, we're simply looking for the largest inner product

$$ s = \max (\vec{V^+} \cdot \{\vec{V_i}\}|_{i \epsilon C}) $$

Where $s$ is the similar sentences in the corpus, $\vec{V^+}$ is your custom
"search" term (or new vector), and $\{\vec{V_i}\}|_{i \epsilon C}$ is the set of all word vectors in your corpus $C$. In this way, it is possible to find the most semantically similar statements in your set of documents to one you provide yourself. Additionally, the method `most_similar` finds the `topn` most similar sentences based the inferred vector.

## Why Monte Carlo?

In order to initialize the new corpus of the words you provide in
the `infer_vector` method, the weights in the neural network of that vector are randomly applied. This means that if you search for the same sentence/document twice (on a different random seed) you many find different sentences are the "most similar" between runs. In the spirit of viewing this as a feature and not a bug, this is the perfect application for Monte Carlo. In essence, we'll ask the neural network to find similar sentences to the same sentence many times, and once we have a collection of the sentences that appear more often, we can be (unquantifiably) more certain that the "top hitters" are more relevant to our search rather than relying on a single query.

### Use as a Test fo Over training

For `doc2vec` the result of overtraining can cause the network to "memorize" a set of documents, and perform poorly on searches that aren't already contained within your corpus. This (maybe, I have no non-emperical proof) evident with a Monte Carlo histogram. An example of overtraining can be seen below for the basic service quesion.


![Alt Text](images/MC_bad.png)


From the first figure we can see that the `doc2vec` network (here trained through 50 epochs) is getting hung up on the same ~200 sentences. These 200 sentences are not necessarily interesting as we're actually interested in _all_ the sentences that may be interesting. Not to mention the CDF is kind of "chunky" indicating multi-modal behavior, which is typically a bad sign unless there's a good reason for it. Comparing these results to those of a network trained through only 20 epochs below

![Alt text](images/MC_good.png)

Where now we see that the network is frequently finding approximately 500 (hopefully highly relevant) sentences, as well as a long tail of "one hitters" or sentences that only appear once. Typically the one hitters are often noise, but sometimes there's a "diamond in the rough" where it answers the question, but in a highly idiosyncratic (and often angry) fashion from the the individual submissions. As well, the CDF of this function indicates that this histogram is unimodal, if you can consider a exponential curve to be unimodal.

I should note I have no real test to claim that the results of the second histogram are inherently better than the first, but the second network doesn't seem to get as hung up and finds more sentences. I'd be interested in any critiques of using Monte Carlo that you may have.

## Neo4j
The `doc2vec` tagged sentences as well as 3 sentences above and 3 sentences below (more if there were tagged sentences in close proximity) were all added into the `Neo4j` data base using the following
```Cypher
MATCH (doc:Document {sha256: $doc256})
MATCH (Q:Question {ref: $qref})
MERGE (Qe:Query {str: $query})
MERGE (s:Segment {sha256: $seg256})
MERGE (Q)<-[:ABOUT {method: $method}]-(Qe)
MERGE (Qe) <-[:MATCHES]- (s)
MERGE (s) -[:SEGMENT_OF] -> (doc)
SET s.frequency = $counts
SET s.content = $content
```
Here all segments are being matched to pre-existing documents within the data base, as well as whatever question the `infer_vector` method was most similar to. The sentence that was passed into `infer_vector` is noted as the `Query` node, and in the future there may be multiple queries about the same question from `doc2vec`. Here `method` is `doc2vec-MonteCarlo` and the text is stored on a new `Segment` node under the content property. The amount of times these sentences appeared in the Monte Carlo run are stored under the `frequency` property. In this case, if you order returned segments by frequency, you should find the most relevant sentences.


## Sentiment Analysis

Once the segments were merged into the database, it was possible to perform sentiment analysis for both the affordability and basic service questions for each respondent group. This was done in `R` with the following snipped of code.

```R
QuerySentiment <- function(query,graph, sentiment_library)
{
    data_raw <- cypher(graph, query)
    results <- dplyr::mutate(data_raw, id=as.integer(rownames(data_raw)))
    tibbled_data <- as_tibble(results)

    # CHECK IF YOU NEED THE END BIT
    cleaned_text <- tibbled_data  %>%
        filter(str_detect(Segment, "^[^>]+[A-Za-z\\d]") | Segment == "",
        !str_detect(Segment, "writes(:|\\.\\.\\.)$"),
        !str_detect(Segment, "^In article <"))

    use_words <- cleaned_text %>%
         unnest_tokens(word, Segment) %>%
         filter(str_detect(word, "[a-z']$"),
         !word %in% stop_words$word)

    words_by_org <- use_words %>%
        count(Organization, word, sort = TRUE) %>%
        ungroup()

    afinn <- sentiments %>%
         filter(lexicon == 'AFINN')%>%
         select(word, afinn = score)

    pre_scored <- words_by_org %>%
        left_join(afinn, by = 'word')

    scored <- pre_scored%>%
        group_by(Organization)%>%
        summarise(
            afinn_score = list(afinn),
            mean_afinn=mean(afinn,na.rm=T),
            sd_afinn=sd(afinn,na.rm=T)
            )

    return(scored)
}
```

Here the data is pulled form the data base using a provided Query and pre-defined `Neo4j` graph. The data is then cleaned of odd symbols and stop words, before being run through and scored word-by-word using the `AFINN` sentiment library which scores words in the range $[-5,5]$, where the more positive the score, the more positive the sentiment of the word. The segments are then passed and scored on a word-by-word by however they're grouped, i.e. this function groups them by however the query returns the `Organization` clause. Unfortunately I don't know how to pass a variable argument into this to generalize this appropriately, but if someone knows please let me know. But regardless, this will return a tibbled data frame grouped by `Organization` (whatever that may be in your case) and returns the sentiment as a list within the table. I note that `ggplot` doesn't like this, and it's subject to change once I get more comfortable with `tidyr`. I also note that this function within `senties.R` (which will eventually be committed, sooner if there's interest) also returns sentiment for the other sentiment libraries not shown here, but for the purpose of this particular sentiment analysis, I found their scoring too binary for meaningful plots. However, with some restructuring using the `NRC` library, it might be interesting to get the emotional sentiment out of some of the respondents. I do however note that interesting $\neq$ answers.

NOTE: I have rescaled all positive sentiments by subtracting 0.5 and all negative sentiments by adding 0.5 to the `AFINN` library. This gets rid of the "hole" at 0. I know it's a tedious point but it was bothering me and the plots look a lot nicer now. Essentially I did the following:
```R
positive_sentiment <- positive_sentiment - 0.5
negative_sentiment <- negative_sentiment + 0.5
```
for all values of sentiment.

### Sentiment of Affordability Question

See below for a dump of sentiment pdfs for each subset of groups. My next step will be to display the number of words counted in the sentiment analysis, but so far I haven't found an easy way to do that. However, the ones that have very few tend to be the ones where the mean or the 68% confidence region is out of the box. I think I'll implement a filter so we don't display results with very few sentiment words. I note that I tried violin plots, but they didn't really add anything that the mean and quantile confidence region didn't do more simply. A word of caution however: quartiles are calculated by sorting the data, and because we have identical integer data these also aren't that informative. However these bars are calculated exactly the same as they would be in a violin plot. I might try a bean plot shortly, but I still don't know how great those would be.


I note however that each of these were made with a `Neo4j` query that looked similar to the following
```cypher
MATCH (Q:Question)<-[r:ABOUT]-(Qe:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
WHERE r.method = 'doc2vec-MonteCarlo'
AND Q.ref = 'Q1'
RETURN distinct s.content AS Segment, o.category as Organization
```
This search returns approximately 2173 segments from the database, all with an unknown quality. Which is exciting.

#### All Organizations
![Alt Text](images/AllOrgsAfford2.png)

|Organization                         |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:------------------------------------|:--------------|:------------|:----------------|
|Advocacy organizations               |-0.17          |1.58         |794              |
|Consumer advocacy organizations      |0.8            |1.19         |43               |
|Government                           |0.13           |1.38         |293              |
|Network operator - Cable companies   |0.31           |1.28         |178              |
|Network operator: other              |0.36           |1.33         |271              |
|Network operator: Telecom Incumbents |-0.1           |1.42         |272              |
|Other                                |0.22           |1.42         |241              |
|Small incumbents                     |0.17           |1.28         |95               |
|NA                                   |0.25           |1.32         |73               |
#### "Other Network" Category
![Alt Text](images/OtherNetworkOpAfford2.png)

|Organization                               |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:------------------------------------------|:--------------|:------------|:----------------|
|Axia                                       |0.5            |0            |2                |
|BC Broadband Association                   |1.5            |NA           |1                |
|Bragg Communications Inc.                  |0.62           |1.13         |8                |
|Canadian Network Operators Consortium      |0.6            |1.14         |21               |
|Canadian Network Operators Consortium Inc. |0.37           |1.03         |39               |
|CanWISP                                    |0.56           |1.05         |47               |
|Chebucto Community Net Society             |1              |0.9          |12               |
|Distributel                                |-0.5           |0            |2                |
|Eastlink                                   |0.29           |1.41         |42               |
|Harewaves Wireless                         |-0.3           |1.1          |5                |
|Iristel                                    |0.4            |1.2          |10               |
|National Capital FreeNet                   |2              |0.71         |2                |
|OneWeb                                     |0.58           |1.05         |38               |
|Primus Telecommunications Canada           |-0.5           |1            |3                |
|SSi                                        |0.55           |1.28         |149              |
|TekSavvy                                   |0.39           |1.1          |19               |
|TekSavvy Solutions Inc.                    |0.86           |1.03         |11               |
|Telesat                                    |0.25           |1.04         |8                |
|WIND Mobile Corp.                          |0.7            |0.79         |10               |
|Xplornet                                   |0.34           |1.27         |117              |
|Yak Communications                         |0.27           |1.01         |13               |

#### Government Category
![Alt Text](images/GovernmentAfford2.png)

||Organization                                                |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-----------------------------------------------------------|:--------------|:------------|:----------------|
|Cree Nation Government                                      |0.26           |1.15         |78               |
|Federation of Canadian Municipalities                       |0.45           |1.07         |21               |
|Government of British Columbia                              |0.82           |1            |53               |
|Government of the Northwest Territories                     |0.33           |1.11         |54               |
|Government of Yukon                                         |0.75           |1.07         |20               |
|Kativik Regional Government                                 |0.58           |0.95         |13               |
|Manitoba Keewatinowi Okimakinak                             |0.3            |1.12         |70               |
|Milton Councillor,  Ward 3 (Nassagaweya)                    |-0.14          |1.54         |121              |
|Northwest Territories Finance                               |0.28           |1.21         |40               |
|Powell River Regional District                              |0.26           |1.3          |29               |
|Province of British Columbia                                |0.61           |0.9          |35               |
|Rimouski-Neigette--Témiscouata--Les Basques                 |-0.25          |1.5          |4                |
|The Alberta Association of Municipal Districts and Counties |0.54           |1.21         |25               |
|Yukon Economic Development                                  |0.71           |0.94         |29               |
|Yukon Government                                            |0.75           |1.07         |20               |



#### Advocacy organizations
![Alt Text](images/AdvocacyOrgsAfford2.png)

|Organization                                                      |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-----------------------------------------------------------------|:--------------|:------------|:----------------|
|ACORN Canada                                                      |-0.1           |1.56         |158              |
|ACORN Members Testimonials                                        |-0.1           |1.56         |158              |
|BC Broadband Association (BCBA)                                   |0.8            |1.19         |43               |
|Canadian Association of the Deaf-Association des Sourds du Canada |-0.16          |1.23         |29               |
|CCSA                                                              |0.17           |1.26         |66               |
|CNIB                                                              |0.17           |1.19         |18               |
|Cybera                                                            |0.37           |1.26         |276              |
|Deaf Wireless Canada Committee                                    |0.26           |1.35         |119              |
|First Mile Connectivity Consortium                                |0.44           |1.22         |199              |
|FRPC                                                              |0.56           |1.24         |88               |
|i-CANADA                                                          |1              |0.79         |18               |
|Manitoba Keewatinowi Okimakinak Inc.                              |0.53           |1.18         |74               |
|Media Access Canada                                               |0.42           |1.07         |40               |
|Media Access Canada / Access 2020                                 |0.5            |1.03         |16               |
|MediaSmarts                                                       |0.73           |1.09         |13               |
|Nunavut Broadband Development Corporation                         |0.61           |1.09         |83               |
|Open Media                                                        |0.36           |1.24         |112              |
|Public Interest Advocacy Centre                                   |0.25           |1.33         |147              |
|Public Interest Law Centre                                        |0.5            |0            |2                |
|The Affordable Access Coalition                                   |0.33           |1.3          |206              |
|Union des consommateurs                                           |0.5            |1.41         |4                |
|Union des Consommateurs                                           |0.5            |0.94         |10               |
|Unknown                                                           |-0.26          |1.62         |708              |
|Vaxination Informatique                                           |0.16           |1.23         |32               |



#### "Other" Category
![Alt Text](images/OtherAfford2.png)


|Organization                                                                          |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-------------------------------------------------------------------------------------|:--------------|:------------|:----------------|
|664947 AB LTD                                                                         |-0.67          |1.17         |6                |
|ADISQ                                                                                 |1.75           |0.5          |4                |
|Allstream Inc. and MTS Inc.                                                           |0.96           |1.14         |24               |
|Canadian Federation of Agriculture                                                    |-0.03          |1.47         |86               |
|Canadian Media Concentration Research Project                                         |0.37           |1.23         |62               |
|CAV-ACS                                                                               |1.17           |0.58         |3                |
|CPC                                                                                   |0.39           |1.27         |9                |
|Eastern Ontario Wardens Caucus (EOWC) and the Eastern Ontario Regional Network (EORN) |0.31           |1.03         |21               |
|Elementary Teachers' Federation of Ontario (ETFO)                                     |-0.17          |1.21         |6                |
|Forum for Research and Policy in Communications                                       |0.43           |1.25         |45               |
|Gerry Curry Photography                                                               |-0.5           |1            |3                |
|NERA Economic Consulting                                                              |0.61           |0.88         |28               |
|NWT Association of Communities                                                        |1.25           |0.46         |8                |
|OneWeb, Ltd.                                                                          |0.53           |1.09         |34               |
|Palliser Regional Park                                                                |-0.7           |1.3          |5                |
|private citizen                                                                       |-0.83          |2.08         |3                |
|Roslyn Layton                                                                         |0.4            |1.21         |30               |
|Second Flux Information Services                                                      |0.26           |1.3          |29               |
|Skipping Rock Communication Arts                                                      |-0.3           |1.79         |5                |
|Unifor                                                                                |0.17           |1.53         |3                |
|Wehlend Consulting Inc.                                                               |0              |1.79         |18               |
|Yellow Pages Limited                                                                  |0.91           |0.71         |17               |


#### Cable Companies
![Alt Text](images/CableAfford2.png)

|Organization             |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:------------------------|:--------------|:------------|:----------------|
|Cogeco                   |0.64           |1.11         |44               |
|Cogeco Cable Inc.        |0.55           |1.28         |20               |
|Rogers                   |0.35           |1.23         |99               |
|Shaw Cablesystems G.P.   |0.5            |NA           |1                |
|Shaw Communications      |0.31           |1.21         |116              |
|Shaw Communications Inc. |0.5            |NA           |1                |
|Videotron                |-2.5           |NA           |1                |


#### Telecoms
![Alt Text](images/TelecomAfford2.png)

|Organization                              |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-----------------------------------------|:--------------|:------------|:----------------|
|Bell                                      |-0.32          |1.47         |113              |
|NorthwesTel                               |0.75           |1.13         |16               |
|Saskatchewan Telecommunications (SaskTel) |-0.26          |1.37         |70               |
|SaskTel                                   |0.23           |1.75         |15               |
|Telus Communications                      |0.16           |1.36         |189              |
|TELUS Communications Company              |0.56           |1.1          |50               |



#### Small Incumbents

![Alt Text](images/SmallIncAfford2.png)

|Organization     |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:----------------|:--------------|:------------|:----------------|
|ACTQ             |0.34           |1.03         |49               |
|CITC-JTF         |0.34           |1.29         |73               |
|Joint Task Force |-0.08          |1.25         |36               |
|tbaytel          |1.5            |0            |2                |


However on closer inspection there might be a few interesting things here. We see  that on the whole, most categories of organizations are predominantly neutral when it comes to affordability, with the exception of advocacy organizations which are slightly negative. Saying anything further about the individual named organizations may be difficult until I get the number of words used pasted on these graphs as well. But regardless, everyone is pretty neutral until you get into the "other" groups category.

With the addition of the summary tables I'm a lot more confident with some of the data now that the sentiment mean, standard deviations, and words used are immediately obvious. However, the standard deviations are _very_ large in most cases. So large that basically all the sentiment scores can be considered to be overlapping (or indistinguishable depending on how much of a stickler for statistics you are). However, I'm still not convinced that a standard deviation is the best metric on clustered integer data like this, but I'm not aware of anything better besides fitting a function to a histogram. And even then, I'm not sure how effective that will be. But if it's interesting It's something I could do fairly easily.




### Sentiment of Basic Service Question
Below are box plots summarizing the sentiment of filtered organizations and groups using a `Neo4j` query similar to the following
```neo4j
MATCH (Qu:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
WHERE ID(Qu) = 140612
AND s.frequency > 0
RETURN s.content AS Segment, o.category as Organization
```
where that returns all organizations, if you need subsets an additional `AND o.category = 'Desired Category'` is applied. The figures are below, and a summary table is provided below each box plot of the mean, standard deviation, and number of points used to calculate sentiments. This returns 2448 segments of text from the database.

#### All Orgs
![Alt Text](images/AllOrgsBTS2.png)

|Organization                         |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:------------------------------------|:--------------|:------------|:----------------|
|Advocacy organizations               |-0.24          |1.57         |815              |
|Consumer advocacy organizations      |0.81           |1.08         |49               |
|Government                           |0.16           |1.4          |316              |
|Network operator - Cable companies   |0.29           |1.27         |218              |
|Network operator: other              |0.31           |1.32         |303              |
|Network operator: Telecom Incumbents |-0.05          |1.42         |302              |
|Other                                |0.21           |1.42         |275              |
|Small incumbents                     |0.37           |1.27         |131              |
|NA                                   |0.22           |1.44         |61               |

#### "Other Network" Category
![Alt Text](images/OtherNetworkBTS2.png)


|Organization                               |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:------------------------------------------|:--------------|:------------|:----------------|
|Axia                                       |1.25           |0.87         |12               |
|Axia NetMedia Corp.                        |0.5            |NA           |1                |
|BC Broadband Association                   |1.5            |NA           |1                |
|Bragg Communications Inc.                  |0.54           |1.12         |55               |
|Canadian Network Operators Consortium      |0.36           |1.15         |36               |
|Canadian Network Operators Consortium Inc. |0.43           |1.06         |60               |
|CanWISP                                    |0.56           |1            |48               |
|Distributel                                |0.33           |1.33         |6                |
|Eastlink                                   |0.41           |1.23         |88               |
|Harewaves Wireless                         |-0.3           |1.1          |5                |
|Harewaves Wireless Inc.                    |1.17           |0.58         |3                |
|Iristel                                    |1.5            |NA           |1                |
|National Capital FreeNet                   |0.59           |1.38         |11               |
|OneWeb                                     |0.47           |1.11         |34               |
|Primus Telecommunications Canada           |-0.5           |1            |3                |
|SSi                                        |0.53           |1.3          |153              |
|TekSavvy                                   |0.15           |1.27         |17               |
|TekSavvy Solutions Inc.                    |0.21           |1.18         |28               |
|Telesat                                    |0.3            |1.03         |10               |
|WIND Mobile Corp.                          |0.74           |0.75         |17               |
|Xplornet                                   |0.33           |1.19         |153              |
|Yak Communications                         |0.3            |1.08         |15               |

#### Government category

![Alt Text](images/GovernmentBTS2.png)

|Organization                                                |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-----------------------------------------------------------|:--------------|:------------|:----------------|
|Cree Nation Government                                      |0.29           |1.12         |86               |
|Federation of Canadian Municipalities                       |0.31           |1.2          |26               |
|Government of British Columbia                              |0.71           |0.92         |63               |
|Government of Nunavut                                       |-0.25          |1.5          |4                |
|Government of the Northwest Territories                     |0.36           |1.16         |63               |
|Government of Yukon                                         |0.71           |1.06         |24               |
|Kativik Regional Government                                 |0.91           |1            |17               |
|Manitoba Keewatinowi Okimakinak                             |0.42           |1.07         |72               |
|Milton Councillor,  Ward 3 (Nassagaweya)                    |-0.08          |1.57         |131              |
|Northwest Territories Finance                               |0.33           |1.19         |54               |
|Powell River Regional District                              |0.48           |1.44         |42               |
|Province of British Columbia                                |0.63           |0.97         |47               |
|Rimouski-Neigette--Témiscouata--Les Basques                 |-0.5           |1.73         |3                |
|The Alberta Association of Municipal Districts and Counties |0.7            |1.03         |30               |
|Yukon Economic Development                                  |0.78           |1.03         |36               |
|Yukon Government                                            |0.71           |1.06         |24               |

#### Advocacy Organizations
![Alt Text](images/AdvocacyOrgsBTS2.png)


|Organization                                                      |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-----------------------------------------------------------------|:--------------|:------------|:----------------|
|ACORN Canada                                                      |-0.1           |1.56         |158              |
|ACORN Members Testimonials                                        |-0.1           |1.56         |158              |
|BC Broadband Association (BCBA)                                   |0.81           |1.08         |49               |
|Canadian Association of the Deaf-Association des Sourds du Canada |-0.16          |1.23         |29               |
|CCSA                                                              |0.17           |1.26         |66               |
|CNIB                                                              |0.17           |1.19         |18               |
|Cybera                                                            |0.37           |1.26         |276              |
|Deaf Wireless Canada Committee                                    |0.26           |1.35         |119              |
|First Mile Connectivity Consortium                                |0.44           |1.22         |199              |
|FRPC                                                              |0.56           |1.24         |88               |
|i-CANADA                                                          |1              |0.79         |18               |
|Manitoba Keewatinowi Okimakinak Inc.                              |0.53           |1.18         |74               |
|Media Access Canada                                               |0.42           |1.07         |40               |
|Media Access Canada / Access 2020                                 |0.5            |1.03         |16               |
|MediaSmarts                                                       |0.73           |1.09         |13               |
|Nunavut Broadband Development Corporation                         |0.61           |1.09         |83               |
|Open Media                                                        |0.36           |1.24         |112              |
|Public Interest Advocacy Centre                                   |0.25           |1.33         |147              |
|Public Interest Law Centre                                        |0.5            |0            |2                |
|The Affordable Access Coalition                                   |0.33           |1.3          |206              |
|Union des consommateurs                                           |0.5            |1.41         |4                |
|Union des Consommateurs                                           |0.5            |0.94         |10               |
|Unknown                                                           |-0.26          |1.62         |708              |
|Vaxination Informatique                                           |0.16           |1.23         |32               |

#### "Other" Category
![Alt Text](images/OtherBTS2.png)


|Organization                                                                          |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-------------------------------------------------------------------------------------|:--------------|:------------|:----------------|
|664947 AB LTD                                                                         |-0.67          |1.17         |6                |
|ADISQ                                                                                 |1.83           |0.58         |3                |
|Ajungi Arctic Consulting                                                              |0              |1.41         |8                |
|Allstream Inc. and MTS Inc.                                                           |0.59           |1.07         |35               |
|Benjamin Klass and Marc Nanni                                                         |1.5            |NA           |1                |
|Canadian Federation of Agriculture                                                    |0.04           |1.5          |80               |
|Canadian Media Concentration Research Project                                         |0.17           |1.23         |51               |
|CAV-ACS                                                                               |0.62           |1.46         |8                |
|Cisco Systems                                                                         |0.33           |1.17         |6                |
|CPC                                                                                   |0.5            |1.18         |11               |
|Eastern Ontario Wardens Caucus (EOWC) and the Eastern Ontario Regional Network (EORN) |0.46           |1.11         |23               |
|Forum for Research and Policy in Communications                                       |0.42           |1.27         |61               |
|Gerry Curry Photography                                                               |-0.5           |1            |3                |
|NERA Economic Consulting                                                              |0.58           |0.99         |48               |
|NWT Association of Communities                                                        |1.39           |0.93         |9                |
|OneWeb, Ltd.                                                                          |0.4            |1.16         |30               |
|Palliser Regional Park                                                                |-0.7           |1.3          |5                |
|private citizen                                                                       |-0.83          |2.08         |3                |
|Roslyn Layton                                                                         |0.3            |1.07         |46               |
|Second Flux Information Services                                                      |0.48           |1.44         |42               |
|Seenov Inc.                                                                           |0.5            |1.41         |4                |
|Skipping Rock Communication Arts                                                      |-0.3           |1.48         |10               |
|Thetis Island Resident's Association                                                  |-0.5           |1.41         |4                |
|Unifor                                                                                |0.5            |0.94         |10               |
|Ward's Hydraulic                                                                      |-1.5           |0            |2                |
|Wehlend Consulting Inc.                                                               |0              |1.79         |18               |
|Yellow Pages Limited                                                                  |0.8            |0.75         |30               |
####Cable companies
![Alt Text](images/CableBTS2.png)

|Organization        |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-------------------|:--------------|:------------|:----------------|
|Cogeco              |0.54           |1.13         |57               |
|Cogeco Cable Inc.   |0.58           |0.86         |25               |
|Rogers              |0.28           |1.31         |116              |
|Shaw Communications |0.39           |1.21         |142              |
|Videotron           |-1.83          |0.58         |3                |

#### Telecoms
![Alt Text](images/TelecomBTS2.png)

|Organization                              |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-----------------------------------------|:--------------|:------------|:----------------|
|Bell                                      |-0.12          |1.41         |80               |
|NorthwesTel                               |0.59           |1.15         |22               |
|Saskatchewan Telecommunications (SaskTel) |-0.16          |1.38         |90               |
|SaskTel                                   |0.26           |1.68         |17               |
|Telus Communications                      |0.08           |1.38         |239              |
|TELUS Communications Company              |0.61           |1.1          |70               |



These plots are a little more interesting than the affordability question in the sense that there seems to be slightly more positive sentiment in the language used in segments pulled around the basic service question. Interestingly though, Advocacy organizations, a group which you'd expect to use very positive language around the basic service question are still slightly negative leaning. However, that could be related to the sentences chosen in each segment. Perhaps a symmetric segment of 3 sentences above and 3 sentences below the `doc2vec` tagged sentence is a poor choice?








## Potential Issues
### Irrelevance/Noise
With `doc2vec` there's no way to be sure that the document fragments recovered are relevant to the inferred vector. In which case, the above analysis may contain sentiment from sentence fragments that are not at all relevant to either question which could lead us to misleading results. There are a few possible solutions:
1.  (Make someone else) read all of the sentences to be sure.
2. Compare with `solr` to see if the sentiment is the similar.
3. Only use high frequency fragments from the Monte Carlo. This does hold the risk that we may only use a few hundred sentences from the entire dataset. However, from manual reading, this is likely a 'High quality' few hundred sentences.

This is also related to noise, as 'sentences' of random strings of characters that only appear once sometimes get heavily weighted, and top fragments may be nothing but a collection of tildes, square brackets, and email addresses. On the plus side, things like this are either filtered or ignored in the sentiment analysis as they rely on pre-defined scoring dictionaries.

### Ambiguity
As many of the questions we're setting out to answer may have ambiguous or vague answers, there may not be one 'universal' search that find all the answers, with the exception of a `solr` search for the actual CRTC question. As well, I don't think sentiment or topic analysis will give us concrete answers, simply common terms and language used in sentence fragments. In terms of possible solutions, I'm not sure if there's an automated approach. We can probably narrow down relevant sections from documents for the telecoms using `Neo4j`.

## Coming Soon: Topic Analysis?
I haven't done this yet but that might be the plan for this week.
