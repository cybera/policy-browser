import gensim 
import pandas as pd
from nltk.stem.porter import PorterStemmer
from nltk.tokenize import RegexpTokenizer
from stop_words import get_stop_words
import random
import time
from datetime import datetime
import numpy as np



def MC_Doc2Vec(sentence, network, num_return, N, negative=None):
    ''' 
    Monte carlo of doc2vec. need your search sentence "sentence"
    your trained network "network"
    it will return the top num_return matches and do N 
    MC iterations

    If you use negative it removes things semantically similar to what 
    you supply it. Well not relly, but we toss it in as a negative vector.
   
    i.e the vector you search for is: 

    search_vector = thing_you_want - thing_you_dont


    I'm not convinced it works that well so use it at your own risk. 
    '''

    model = gensim.models.Doc2Vec.load(network)
    tokenizer = RegexpTokenizer(r'\w+')
    Stemmer = PorterStemmer()

    try:
        EnglishStopWords = get_stop_words('en')
        remove = EnglishStopWords.index("not")
        del EnglishStopWords[remove]
    except:
        pass

    tokens = tokenizer.tokenize(sentence.lower())
    stopped_tokens =  [sentence for sentence in tokens if sentence not in EnglishStopWords]
    stemmed_tokens = [Stemmer.stem(sentence) for sentence in stopped_tokens]
    infer_vector = model.infer_vector(stemmed_tokens, steps=20, alpha=0.025)
   
    # I'm not convinced this works well. Use at own risk.
    if negative:
        if isinstance(negative, list):
            negative  =[Stemmer.stem(word) for word in negative]
            vecs = []
            iv = np.zeros(len(infer_vector))
            for word in negative:
                vecs.append(model[word])
            for vec in vecs:
                iv += vec
        else:
            stopped_tokens2 = [sentence for sentence in tokens2 if sentence not in EnglishStopWords]
        
    indexes = []
  
    for i in range(N):
        start = time.time()
        model.random.seed(random.seed(datetime.now()))

        infer_vector = model.infer_vector(stemmed_tokens, steps=20, alpha=0.025)#
        if negative:
            if isinstance(negative, list) == False:
                iv = model.infer_vector(stopped_tokens2, steps=20, alpha=0.025)
                infer_vector = infer_vector - iv

            similars = model.docvecs.most_similar(positive=[infer_vector-iv], topn=num_return)

        else:
            similars = model.docvecs.most_similar(positive=[infer_vector], topn=num_return)

        for locations in similars:
            
            index = int(locations[0])
            indexes.append(index)
        end = time.time()
        print("Iteration ", i, "took ", end-start, " seconds   ", sep = ' ', end='\r')


    return indexes

# Size 300 net
netname = "DBOW300"

MyFiles = ["MC_BasicService_CopyPaste_300_LT.txt",
            "MC_Affordability_300_LT", 
            "MC_marketforces_300_LT.txt",
            "MC_Subsidize_CopyPaste_300_LT.txt"
           ]

MyQuestions = [
               "broadband internet services should be considered a basic telecommunications service",
                "Affordability of broadband internet access",
               "Can market forces and government funding be relied on to ensure that all Canadians have access to basic telecommunications services",
               "Should some or all services that are considered to be basic telecommunications services be subsidized"
                ]


if __name__ == '__main__'
    for i, questions in enumerate(MyQuestions):
        begin = time.time()
        print("Answering Question ", questions, '\n')

        index = MC_Doc2Vec(questions, 
                        network=netname, 
                        num_return=30,
                        N = 50000,
                        negative=None#["price", "affordability", "speed", "cost", "subsidy"]
                        )

        with open(MyFiles[i], 'w') as file:
            for indexes in index:
                file.write(str(indexes))
                file.write('\n')

           
        ending = time.time()
        print("\n Answering question took" , (ending-begin)/60, " minutes")
        print("Saved to file", file.name)
        












