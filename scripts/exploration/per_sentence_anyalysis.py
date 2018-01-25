import pandas as pd 
import gensim
import os
import re
from nltk.tokenize import RegexpTokenizer
from stop_words import get_stop_words
from nltk.stem.porter import PorterStemmer
from gensim.models.doc2vec import TaggedDocument
import multiprocessing
import time
import random

# grab data with made with build_sentence_data.py
df = pd.read_csv("SentenceData2.csv")

# turf duplicates. this gets rid of everyone being polite in the documents (amond other things)
# which was getting annoying. If people were unpredictably rude this would be a simpler analysis
df.drop_duplicates('Sentence', inplace=True)
# Purged most of the data, need to reindex
df.reset_index(inplace=True)

# So I can read the sentences without them getting cut off. 
pd.options.display.max_colwidth = 100

def TagSentences(sentences, random_array = None):
    # random array is to keep track of indexing 
    # if you're training on a random subset of 
    # the data instead of all the data or the first N sentences
    
    tokenizer = RegexpTokenizer(r'\w+')
    EnglishStopWords = get_stop_words('en')
    # keep the word not as it is important to us
    remove = EnglishStopWords.index("not")
    del EnglishStopWords[remove]
    print(EnglishStopWords)
    Stemmer = PorterStemmer()
    


    TaggedSentences = []
    TaggedSentences = ["OBVIOUS FAILURE IN TEXT"] * len(sentences)
    
    print("Making the data pretty....") 

    for i, sentence in enumerate(sentences):
        # use only lower case and clean up sentences
        raw = str(sentence).lower()
        # needs to be tokenized
        tokens = tokenizer.tokenize(raw)
        #remove stop tokens
        stopped_tokens =  [sentence for sentence in tokens if sentence not in EnglishStopWords]
        # remove numbers (maybe don't do this)
        number_tokens = [re.sub(r'[\d]',' ', sentence) for sentence in stopped_tokens]
        number_tokens = ' '.join(number_tokens).split()
 
        # stem the tokens, this also slows down the processing considerably (~6x)
        stemmed_tokens = [Stemmer.stem(sentence) for sentence in number_tokens]
        # also note the tag is an array. Without that the tags reset from 1-10 making finding data impossible.
        # it's annoying and took forever to find that mistake. Which could have been prevented
        # if I read the documentation more closely. 

        # This is for training small subsets if you want to do that.
        if random_array:
            ts = TaggedDocument(gensim.utils.to_unicode(str.encode(' '.join(stemmed_tokens))).split(), [str(random_array[i])])
        else:
            ts = TaggedDocument(gensim.utils.to_unicode(str.encode(' '.join(stemmed_tokens))).split(), [str(i)])
        
        TaggedSentences[i] = ts

    return TaggedSentences



start = time.time()

# randomsentences = random.sample(range(0,len(df["Sentence"])), len(df["Sentence"]))
tagged = TagSentences(df["Sentence"])
end = time.time()

print("Total time ", end-start)

print("Training....")
start = time.time()

# this trains and sets up neural net for the doc2vec stuff.
# here dm is the model, set to zero uses the continuous bag of words
# alpha is the learning rate, size is how many neurons in the hidden layer
# min_count rejects words that have a count less than that in the corpus
# sample down samples high frequency words
# workers is how many cores to use while training
# dbow_words = 1 tells the net to also train word vectors, if you set it to 0 
# it's faster, but the word vectors do not get trained 
# iter is how many epochs to train
# hs sets the algorithm to hierarchical softmax

# NOTE: with these settings it took ~30 min to train. 
model = gensim.models.Doc2Vec(tagged, 
                                dm = 0, 
                                alpha=0.025, 
                                size= 750, 
                                min_alpha=0.0001, 
                                min_count = 5,
                                sample = 1e-4,
                                workers = 8,
                                dbow_words=1,
                                iter = 50,
                                hs=1)

end = time.time()
print("Total training time: ", end-start, '\n')

# this saves your trained neural network

netname = "DBOW1500"
model.save(netname)

print("Networked ", netname, " trained")






