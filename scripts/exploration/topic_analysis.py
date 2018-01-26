# this will be used to do topic analysis on a set of pulled data
# from the doc2vec network. 

import gensim 
import pandas as pd
from nltk.stem.porter import PorterStemmer
from nltk.tokenize import RegexpTokenizer
from stop_words import get_stop_words


def Ask_Doc2Vec(sentence, network, num_sen, num_return, sentence_data, width=200, frame = None):
    # This requires a trained network network. Given that network and
    # a sentence to look for, it will find a number num_results of sentences
    # and print num_return sentences around it. Note: recommend odd numbers 
    # as then the sentence the networks finds will be in the middle of the
    # surrounding sentences. Needs a sentence_data csv which contains the 
    # raw text of your samples. 

    # TODO: Ensure that sentences all come from the same docmument. Current approach
    # is willy-nilly.
    if frame is None:
        df = frame
    else:
        df = pd.read_csv(sentence_data)
        df.drop_duplicates('Sentence', inplace=True)
    # Purged most of the data, need to reindex
        df.reset_index(inplace=True)
   


    
    pd.options.display.max_colwidth = width

    model = gensim.models.Doc2Vec.load(network)

    tokenizer = RegexpTokenizer(r'\w+')
    try:
        EnglishStopWords = get_stop_words('en')
        remove = EnglishStopWords.index("not")
        del EnglishStopWords[remove]
    except:
        pass
    Stemmer = PorterStemmer()

    tokens = tokenizer.tokenize(sentence.lower())
    stopped_tokens =  [sentence for sentence in tokens if sentence not in EnglishStopWords]

    infer_vector = model.infer_vector(stopped_tokens, steps=20)#
    similars = model.docvecs.most_similar(positive=[infer_vector], topn=num_return)

    # Potentiall relevant sentences
    PRS = []
    Docs = []


    indexes = []
    for locations in similars:

        if num_sen == 0:
            index = int(locations[0])
            save = df["Sentence"][index].lstrip()
        else:
            index = int(locations[0])
            save = df["Sentence"][index-num_sen:index+num_sen].to_string()
        
        docnumber = df["DocumentNumber"][int(index)]

        PRS.append(save)
        Docs.append(docnumber)
        indexes.append(index)


    return PRS, Docs,indexes



search = "should the internet be defined as a basic service"
netname = "DBOW1500"


myframe = pd.read_csv("SentenceData2.csv")
myframe.drop_duplicates('Sentence', inplace=True)
    # Purged most of the data, need to reindex
myframe.reset_index(inplace=True)




Documents, numbers, index = Ask_Doc2Vec(search, 
                                        network=netname, 
                                        num_return=100, 
                                        num_sen=0, 
                                        sentence_data="SentenceData2.csv", 
                                        width=150,
                                        frame = myframe )


with open("MC_Sentence_indexes_big.txt", 'a') as file:
    for i, indexes in enumerate(index):
    
        file.write(str(indexes))
        file.write(" ")
        file.write(str(numbers[i]))
        file.write('\n')
        print(indexes)

































