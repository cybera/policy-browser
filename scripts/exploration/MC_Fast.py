import gensim 
import pandas as pd
from nltk.stem.porter import PorterStemmer
from nltk.tokenize import RegexpTokenizer
from stop_words import get_stop_words
import random
import time
from datetime import datetime



def MC_Doc2Vec(sentence, network, num_return, N):
    ''' 
    Monte carlo of doc2vec. neesd your search sentence sentence
    your trained network network
    it will return the top num_return matches and do N 
    MC iterations
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


    indexes = []
  
    for i in range(N):
        start = time.time()
        model.random.seed(random.seed(datetime.now()))

        infer_vector = model.infer_vector(stopped_tokens, steps=50, alpha=0.025)#
        similars = model.docvecs.most_similar(positive=[infer_vector], topn=num_return)

        for locations in similars:
            
            index = int(locations[0])
            indexes.append(index)
        end = time.time()
        print("Iteration ", i, "took ", end-start, " seconds", sep = ' ', end='\r')


    return indexes




netname = "DBOW1500_actual"








MyFiles = ["MC_BasicService_CopyPaste.txt", 
            "MC_marketforces.txt",
            "MC_Subsidize_CopyPaste.txt"]

MyQuestions = [
               "Should broadband Internet service be defined as a basic telecommunications service (BTS)?",
               "Can market forces and government funding be relied on to ensure that all Canadians have access to basic telecommunications services",
               "Should some or all services that are considered to be basic telecommunications services be subsidized"
                ]

for i, questions in enumerate(MyQuestions):
    begin = time.time()
    print("Answering Question ", questions, '\n')

    index = MC_Doc2Vec(questions, 
                    network=netname, 
                    num_return=300, 
                    N = 10000
                    )


    with open(MyFiles[i], 'w') as file:
        for i, indexes in enumerate(index):
            file.write(str(indexes))
            file.write('\n')
       
    ending = time.time()
    print("\n Answering question took" , (ending-begin)/60, " minutes")
    print("Saved to file", file.name)
    file.close()



