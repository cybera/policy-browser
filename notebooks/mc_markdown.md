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

UPDATE: I have removed quartiles as they're misleading with tightly packed integer-spaced data in favor of jitter. Now it's a lot easier to judge if the box had enough data at a simple glance, and how that data is distributed.


I note however that each of these were made with a `Neo4j` query that looked similar to the following
```
cypher
MATCH (Qu:Query) <-[:MATCHES]-(s:Segment)-[:SEGMENT_OF]->(d:Document)<-[:SUBMITTED]-(o:Organization)
WHERE ID(Qu) = 144132
AND s.frequency > 0
AND o.category = 'Network operator: other'
RETURN s.content AS Segment, o.name as Organization
```
This search returns approximately 5365 segments from the database, all with an unknown quality. Which is exciting.

#### All Organizations
![Alt Text](images/AllOrgsAfford2.png)

||Organization                         |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:------------------------------------|:--------------|:------------|:----------------|
|Advocacy organizations               |-0.2           |1.58         |789              |
|Consumer advocacy organizations      |0.76           |1            |38               |
|Government                           |0.19           |1.39         |278              |
|Network operator - Cable companies   |0.26           |1.26         |195              |
|Network operator: other              |0.37           |1.3          |276              |
|Network operator: Telecom Incumbents |0.04           |1.38         |299              |
|Other                                |0.17           |1.41         |269              |
|Small incumbents                     |0.23           |1.28         |116              |
|NA                                   |0.52           |1.21         |44               |

#### "Other Network" Category
![Alt Text](images/OtherNetworkOpAfford2.png)

|Organization                               |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:------------------------------------------|:--------------|:------------|:----------------|
|Axia                                       |0.41           |0.83         |11               |
|BC Broadband Association                   |1.1            |1.14         |5                |
|Bragg Communications Inc.                  |0.74           |1.2          |25               |
|Canadian Network Operators Consortium      |0.64           |1.01         |21               |
|Canadian Network Operators Consortium Inc. |0.56           |1.13         |50               |
|CanWISP                                    |0.63           |0.99         |54               |
|Chebucto Community Net Society             |1.5            |NA           |1                |
|Distributel                                |-0.5           |0            |2                |
|Eastlink                                   |0.58           |1.28         |51               |
|Harewaves Wireless                         |0.17           |1.15         |3                |
|Ice Wireless                               |0.3            |0.84         |5                |
|Iristel                                    |0.62           |1.25         |8                |
|National Capital FreeNet                   |0.67           |1.33         |6                |
|OneWeb                                     |0.44           |1.21         |18               |
|Primus Telecommunications Canada           |-0.33          |1.17         |6                |
|Ruralwave                                  |2.5            |NA           |1                |
|SANNY Internet Service                     |0.83           |0.58         |3                |
|SANNY Internet Services                    |0.5            |NA           |1                |
|SSi                                        |0.56           |1.23         |147              |
|SSi Group of Companies                     |0.44           |1.2          |17               |
|TekSavvy                                   |0.69           |0.98         |21               |
|TekSavvy Solutions Inc.                    |0.67           |1            |29               |
|Telesat                                    |0.5            |1.15         |13               |
|WIND Mobile Corp.                          |1.03           |0.94         |17               |
|Xplornet                                   |0.26           |1.26         |137              |
|Xplornet Communications Inc.               |0.21           |1.05         |17               |
|Yak Communications                         |0.4            |0.99         |10               |

#### Government Category
![Alt Text](images/GovernmentAfford2.png)

|Organization                                                            |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-----------------------------------------------------------------------|:--------------|:------------|:----------------|
|Cree Nation Government                                                  |0.41           |1.11         |77               |
|Cree Nation Government and Eeyou Communications Network                 |1.5            |1            |3                |
|Federation of Canadian Municipalities                                   |0.4            |1.09         |30               |
|Federation of Canadian Municipalities (FCM)                             |0.4            |1.45         |10               |
|Government of British Columbia                                          |0.84           |1.01         |61               |
|Government of the Northwest Territories                                 |0.54           |1.21         |54               |
|Government of Yukon                                                     |0.5            |1.27         |37               |
|Kativik Regional Government                                             |0.6            |1.2          |10               |
|Manitoba Keewatinowi Okimakinak                                         |0.41           |1.11         |78               |
|Milton Councillor,  Ward 3 (Nassagaweya)                                |-0.35          |1.53         |99               |
|Ministère de la Culture et des Communications, Gouvernement du Québec   |1.5            |NA           |1                |
|Northwest Territories Finance                                           |0.52           |1.27         |45               |
|Ontario Ministry of Economic Development, Employment and Infrastructure |0              |1.29         |4                |
|Powell River Regional District                                          |0.33           |1.36         |29               |
|Province of BC                                                          |1.02           |1.08         |23               |
|Province of British Columbia                                            |0.73           |0.91         |44               |
|Region of Queens Municipality                                           |NaN            |NA           |0                |
|Rimouski-Neigette--Témiscouata--Les Basques                             |-0.83          |1.15         |3                |
|The Alberta Association of Municipal Districts and Counties             |0.62           |0.95         |24               |
|Yukon Economic Development                                              |0.86           |0.91         |25               |
|Yukon Government                                                        |0.27           |1.27         |26               |


#### Advocacy organizations
![Alt Text](images/AdvocacyOrgsAfford2.png)

|Organization                                                      |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-----------------------------------------------------------------|:--------------|:------------|:----------------|
|ACORN Canada                                                      |-0.03          |1.53         |123              |
|ACORN Members Testimonials                                        |-0.03          |1.53         |123              |
|Canadian Association of the Deaf-Association des Sourds du Canada |-0.08          |1.17         |19               |
|CCSA                                                              |0.26           |1.23         |37               |
|CNIB                                                              |0.5            |1.41         |2                |
|Cybera                                                            |0.41           |1.25         |222              |
|Deaf Wireless Canada Committee                                    |0.46           |1.25         |78               |
|First Mile Connectivity Consortium                                |0.5            |1.14         |172              |
|FRPC                                                              |0.23           |1.41         |77               |
|i-CANADA                                                          |0.78           |1.33         |32               |
|Manitoba Keewatinowi Okimakinak Inc.                              |0.5            |1.11         |56               |
|Media Access Canada                                               |0.5            |1.18         |37               |
|Media Access Canada / Access 2020                                 |0.58           |1.08         |12               |
|MediaSmarts                                                       |0.7            |1.23         |10               |
|MKO                                                               |-0.33          |0.98         |6                |
|Nunavut Broadband Development Corporation                         |0.5            |1.13         |40               |
|Open Media                                                        |0.42           |1.2          |76               |
|OpenMedia                                                         |0.57           |1.13         |29               |
|Public Interest Advocacy Centre                                   |0.27           |1.3          |105              |
|Public Interest Law Centre                                        |0.83           |0.58         |3                |
|The Affordable Access Coalition                                   |0.39           |1.33         |210              |
|Union des consommateurs                                           |-0.3           |1.79         |5                |
|Union des Consommateurs                                           |-0.17          |1.63         |6                |
|Unknown                                                           |-0.3           |1.59         |600              |
|Vaxination Informatique                                           |0.68           |0.87         |34               |



#### "Other" Category
![Alt Text](images/OtherAfford2.png)


|Organization                                                                          |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-------------------------------------------------------------------------------------|:--------------|:------------|:----------------|
|664947 AB LTD                                                                         |-0.5           |1.22         |5                |
|ADISQ                                                                                 |0.5            |1.87         |5                |
|Ajungi Arctic Consulting                                                              |-0.5           |1.58         |5                |
|Allstream Inc. and MTS Inc.                                                           |0.86           |0.95         |25               |
|Benjamin Klass and Marc Nanni                                                         |0.5            |1.41         |2                |
|BizSkits Inc.                                                                         |1.5            |NA           |1                |
|Canadian Federation of Agriculture                                                    |-0.05          |1.43         |87               |
|Canadian Media Concentration Research Project                                         |0.14           |1.21         |45               |
|CAV-ACS                                                                               |0.5            |1.41         |2                |
|Cisco Systems                                                                         |0.33           |1.17         |6                |
|Cisco Systems Inc.                                                                    |0.28           |1.2          |9                |
|CPC                                                                                   |0.4            |1.2          |10               |
|Eastern Ontario Wardens Caucus (EOWC) and the Eastern Ontario Regional Network (EORN) |0.45           |1.12         |21               |
|Forum for Research and Policy in Communications                                       |0.2            |1.39         |66               |
|Gerry Curry Photography                                                               |-1             |0.71         |2                |
|Lobo Iberico Restaraunt                                                               |0.7            |0.84         |5                |
|NERA Economic Consulting                                                              |0.66           |0.89         |38               |
|NWT Association of Communities                                                        |1.28           |0.44         |9                |
|OneWeb, Ltd.                                                                          |0.44           |1.21         |18               |
|Palliser Regional Park                                                                |-0.7           |1.3          |5                |
|private citizen                                                                       |-0.83          |2.08         |3                |
|Roslyn Layton                                                                         |0.3            |1.1          |45               |
|Second Flux Information Services                                                      |0.33           |1.36         |29               |
|Seenov Inc.                                                                           |0.5            |1.41         |4                |
|Smartstuff Enterprises                                                                |0.5            |NA           |1                |
|Unifor                                                                                |0.4            |0.99         |10               |
|Wehlend Consulting Inc.                                                               |-0.21          |1.86         |14               |
|West Beg Services Ltd.                                                                |1.5            |NA           |1                |
|Yellow Pages Limited                                                                  |0.8            |0.92         |33               |

#### Cable Companies
![Alt Text](images/CableAfford2.png)

|Organization                         |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:------------------------------------|:--------------|:------------|:----------------|
|Canadian Cable Systems Alliance Inc. |1              |0.71         |2                |
|Cogeco                               |0.61           |1.07         |45               |
|Cogeco Cable Inc.                    |0.67           |0.87         |24               |
|Québecor Média inc.                  |1.5            |NA           |1                |
|Rogers                               |0.35           |1.14         |78               |
|Rogers Communications                |0.33           |1.2          |41               |
|Shaw Cablesystems G.P.               |0.64           |0.79         |21               |
|Shaw Communications                  |0.23           |1.25         |129              |
|Shaw Communications Inc.             |1.17           |0.58         |3                |
|Videotron                            |-2.5           |NA           |1                |


#### Telecoms
![Alt Text](images/TelecomAfford2.png)

|Organization                              |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-----------------------------------------|:--------------|:------------|:----------------|
|Bell                                      |-0.05          |1.38         |87               |
|Bell Canada                               |0.42           |1.24         |84               |
|NorthwesTel                               |0.46           |1.4          |26               |
|Saskatchewan Telecommunications (SaskTel) |-0.11          |1.36         |92               |
|SaskTel                                   |0.29           |1.85         |14               |
|Telus Communications                      |0.18           |1.35         |208              |
|TELUS Communications Company              |0.47           |1.23         |86               |


#### Consumer Advocacy

![Alt Text](images/ConsumerAdvAfford2.png)

|Organization                    |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-------------------------------|:--------------|:------------|:----------------|
|BC Broadband Association (BCBA) |0.76           |1            |38               |

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
where that returns all organizations, if you need subsets an additional `AND o.category = 'Desired Category'` is applied. The figures are below, and a summary table is provided below each box plot of the mean, standard deviation, and number of points used to calculate sentiments. This returns 4239 segments of text from the database.

#### All Orgs
![Alt Text](images/AllOrgsBTS2.png)

|Organization                         |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:------------------------------------|:--------------|:------------|:----------------|
|Advocacy organizations               |-0.2           |1.55         |665              |
|Consumer advocacy organizations      |0.81           |1.09         |36               |
|Government                           |0.35           |1.25         |229              |
|Network operator - Cable companies   |0.37           |1.2          |178              |
|Network operator: other              |0.37           |1.32         |247              |
|Network operator: Telecom Incumbents |0.03           |1.42         |303              |
|Other                                |0.34           |1.32         |216              |
|Small incumbents                     |0.33           |1.25         |121              |
|NA                                   |0.58           |1.27         |36               |

#### "Other Network" Category
![Alt Text](images/OtherNetworkBTS2.png)

|Organization                               |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:------------------------------------------|:--------------|:------------|:----------------|
|Axia                                       |1              |0.58         |4                |
|BC Broadband Association                   |1.17           |1.03         |6                |
|Bragg Communications Inc.                  |0.71           |1.06         |39               |
|Canadian Network Operators Consortium      |0.5            |1.29         |19               |
|Canadian Network Operators Consortium Inc. |0.54           |1.13         |57               |
|CanWISP                                    |0.69           |0.88         |37               |
|Distributel                                |-0.5           |0            |2                |
|Eastlink                                   |0.66           |1.18         |62               |
|Harewaves Wireless                         |0.17           |1.15         |3                |
|Harewaves Wireless Inc.                    |0.5            |NA           |1                |
|Ice Wireless                               |NaN            |NA           |0                |
|Iristel                                    |0.1            |1.67         |5                |
|National Capital FreeNet                   |0.67           |1.33         |6                |
|OneWeb                                     |0.37           |1.18         |23               |
|Primus Telecommunications Canada           |-0.5           |1            |3                |
|Ruralwave                                  |2.5            |NA           |1                |
|SANNY Internet Services                    |NaN            |NA           |0                |
|SSi                                        |0.67           |1.23         |129              |
|SSi Group of Companies                     |0.44           |1.24         |16               |
|TekSavvy                                   |0.57           |0.92         |14               |
|TekSavvy Solutions Inc.                    |0.15           |1.09         |20               |
|Telesat                                    |0              |0.71         |2                |
|WIND Mobile Corp.                          |0.9            |0.97         |10               |
|Xplornet                                   |0.21           |1.3          |119              |
|Xplornet Communications Inc.               |0.13           |1.21         |19               |
|Yak Communications                         |0.19           |1.11         |13               |

#### Government category

![Alt Text](images/GovernmentBTS2.png)

|Organization                                                            |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-----------------------------------------------------------------------|:--------------|:------------|:----------------|
|Cree Nation Government                                                  |0.46           |1.04         |81               |
|Cree Nation Government and Eeyou Communications Network                 |1.5            |NA           |1                |
|Federation of Canadian Municipalities                                   |0.67           |0.89         |23               |
|Federation of Canadian Municipalities (FCM)                             |0.83           |0.58         |3                |
|Government of British Columbia                                          |0.74           |0.91         |63               |
|Government of Nunavut                                                   |1.5            |NA           |1                |
|Government of the Northwest Territories                                 |0.4            |1.17         |51               |
|Government of Yukon                                                     |0.88           |1.02         |34               |
|Kativik Regional Government                                             |1.21           |0.76         |7                |
|Manitoba Keewatinowi Okimakinak                                         |0.44           |1.05         |63               |
|Milton Councillor,  Ward 3 (Nassagaweya)                                |-0.09          |1.43         |58               |
|Ministère de la Culture et des Communications, Gouvernement du Québec   |1.5            |NA           |1                |
|Northwest Territories Finance                                           |0.5            |1.23         |46               |
|Ontario Ministry of Economic Development, Employment and Infrastructure |1.5            |NA           |1                |
|Powell River Regional District                                          |0.62           |1.2          |16               |
|Province of BC                                                          |0.86           |0.79         |22               |
|Province of British Columbia                                            |0.67           |0.93         |46               |
|Region of Queens Municipality                                           |NaN            |NA           |0                |
|Rimouski-Neigette--Témiscouata--Les Basques                             |NaN            |NA           |0                |
|The Alberta Association of Municipal Districts and Counties             |0.87           |1.01         |19               |
|Yukon Economic Development                                              |1.02           |0.89         |27               |
|Yukon Government                                                        |0.64           |0.94         |22               |

#### Advocacy Organizations
![Alt Text](images/AdvocacyOrgsBTS2.png)

|Organization                                                      |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-----------------------------------------------------------------|:--------------|:------------|:----------------|
|ACORN Canada                                                      |0.08           |1.53         |90               |
|ACORN Members Testimonials                                        |0.08           |1.53         |90               |
|Canadian Association of the Deaf-Association des Sourds du Canada |-0.26          |1.09         |17               |
|CCSA                                                              |0.36           |1.18         |28               |
|CNIB                                                              |0.5            |0.71         |5                |
|Cybera                                                            |0.38           |1.22         |178              |
|Deaf Wireless Canada Committee                                    |0.4            |1.36         |63               |
|First Mile Connectivity Consortium                                |0.41           |1.15         |138              |
|FRPC                                                              |0.41           |1.31         |80               |
|i-CANADA                                                          |0.83           |1.18         |15               |
|Manitoba Keewatinowi Okimakinak Inc.                              |0.56           |1.08         |48               |
|Media Access Canada                                               |0.5            |0.97         |20               |
|Media Access Canada / Access 2020                                 |0.5            |0.98         |30               |
|MediaSmarts                                                       |0.3            |1.64         |5                |
|MKO                                                               |-0.5           |1            |5                |
|Nunavut Broadband Development Corporation                         |0.59           |1.06         |32               |
|Open Media                                                        |0.43           |1.17         |70               |
|OpenMedia                                                         |0.38           |1.2          |34               |
|Public Interest Advocacy Centre                                   |0.26           |1.38         |113              |
|The Affordable Access Coalition                                   |0.3            |1.32         |219              |
|Union des consommateurs                                           |-1.5           |NA           |1                |
|Union des Consommateurs                                           |-0.5           |1.41         |2                |
|Unknown                                                           |-0.33          |1.57         |452              |
|Vaxination Informatique                                           |0.73           |0.81         |35               |

#### "Other" Category
![Alt Text](images/OtherBTS2.png)

|Organization                                                                          |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-------------------------------------------------------------------------------------|:--------------|:------------|:----------------|
|ADISQ                                                                                 |2              |0.71         |2                |
|Allstream Inc. and MTS Inc.                                                           |0.72           |1.05         |27               |
|Benjamin Klass and Marc Nanni                                                         |0.5            |1.41         |2                |
|Canadian Federation of Agriculture                                                    |0.21           |1.38         |52               |
|Canadian Media Concentration Research Project                                         |0.09           |1.23         |44               |
|CAV-ACS                                                                               |0.21           |1.5          |7                |
|Cisco Systems                                                                         |0.33           |1.17         |6                |
|Cisco Systems Inc.                                                                    |0.21           |1.38         |7                |
|CPC                                                                                   |0.5            |1.11         |14               |
|Eastern Ontario Wardens Caucus (EOWC) and the Eastern Ontario Regional Network (EORN) |0.5            |1.08         |13               |
|Forum for Research and Policy in Communications                                       |0.48           |1.26         |60               |
|Gerry Curry Photography                                                               |-1             |0.71         |2                |
|NERA Economic Consulting                                                              |0.81           |0.75         |36               |
|NWT Association of Communities                                                        |1.1            |0.55         |5                |
|OneWeb, Ltd.                                                                          |0.37           |1.18         |23               |
|private citizen                                                                       |-0.83          |2.08         |3                |
|Roslyn Layton                                                                         |0.46           |1.2          |28               |
|Second Flux Information Services                                                      |0.62           |1.2          |16               |
|Seenov Inc.                                                                           |0.83           |1.53         |3                |
|Unifor                                                                                |0.4            |0.88         |10               |
|Wehlend Consulting Inc.                                                               |0.79           |1.5          |7                |
|Yellow Pages Limited                                                                  |0.7            |0.85         |30               |

####Cable companies
![Alt Text](images/CableBTS2.png)

|Organization             |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:------------------------|:--------------|:------------|:----------------|
|Cogeco                   |0.52           |1.1          |56               |
|Cogeco Cable Inc.        |0.42           |0.89         |26               |
|Québecor Média inc.      |1.5            |0            |2                |
|Rogers                   |0.41           |1.16         |77               |
|Rogers Communications    |0.06           |1.19         |32               |
|Shaw Cablesystems G.P.   |0.67           |0.83         |12               |
|Shaw Communications      |0.5            |1.17         |120              |
|Shaw Communications Inc. |0.5            |NA           |1                |

#### Telecoms
![Alt Text](images/TelecomBTS2.png)

|Organization                              |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-----------------------------------------|:--------------|:------------|:----------------|
|Bell                                      |-0.05          |1.43         |83               |
|Bell Canada                               |0.43           |1.25         |72               |
|NorthwesTel                               |0.5            |1.25         |10               |
|Saskatchewan Telecommunications (SaskTel) |-0.14          |1.35         |75               |
|SaskTel                                   |0.42           |1.93         |12               |
|Telus Communications                      |0.18           |1.36         |231              |
|TELUS Communications Company              |0.47           |1.15         |98               |
#### Consumer Advocacy
![Alt Text](images/ConsumerAdvBTS2.png)

|Organization                    |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:-------------------------------|:--------------|:------------|:----------------|
|BC Broadband Association (BCBA) |0.81           |1.09         |36               |

#### Small Incumbents
![Alt Text](images/SmallIncBTS2.png)

|Organization     |Sentiment_Mean |Sentiment_SD |Number_of_points |
|:----------------|:--------------|:------------|:----------------|
|ACTQ             |0.44           |0.98         |52               |
|CITC-JTF         |0.43           |1.24         |83               |
|Joint Task Force |0.08           |1.29         |31               |
|tbaytel          |1.5            |0            |2                |




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
