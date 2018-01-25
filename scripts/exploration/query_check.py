import gensim 
import pandas as pd
from nltk.stem.porter import PorterStemmer
from nltk.tokenize import RegexpTokenizer
from stop_words import get_stop_words
df = pd.read_csv("SentenceData2.csv")


# same as training, need to make sure we have the same indexes to print the actual data
df.drop_duplicates('Sentence', inplace=True)
# Purged most of the data, need to reindex
df.reset_index(inplace=True)
pd.options.display.max_colwidth = 150

#load the trained network
netname = "DBOW1500"
model = gensim.models.Doc2Vec.load(netname)

# need to do the same pre-processing to our custom sentences in order to avoid 
# 'not in dictionary' errors. 
tokenizer = RegexpTokenizer(r'\w+')
EnglishStopWords = get_stop_words('en')
remove = EnglishStopWords.index("not")
del EnglishStopWords[remove]
Stemmer = PorterStemmer()

# define the sentence you want to look for
sentence = "define the internet as a basic service".lower()
tokens = tokenizer.tokenize(sentence)
stopped_tokens =  [sentence for sentence in tokens if sentence not in EnglishStopWords]


infer_vector = model.infer_vector(stopped_tokens, steps=20)#, alpha=0.025)
#infer_vector2 = model2.infer_vector(MyDesire)#, alpha=0.025)


#similars2 = model2.docvecs.most_similar(positive=[infer_vector2], topn=30)
similars = model.docvecs.most_similar(positive=[infer_vector], topn=30)

print("2000 Neurons")
for locations in similars:
    middle = int(locations[0])
    print( df["Sentence"][middle-2:middle+2], '\n', "Document: ",
          df["DocumentNumber"][int(locations[0])], "Inner Product: ", locations[1], '\n')

#print("__________________________________________________________________________________-")
#print()
#print("1500 Neurons")
#for locations in similars2:
#   print( df["Sentence"][int(locations[0])], '\n', "Document: ",
 #         df["DocumentNumber"][int(locations[0])], "Inner Product: ", locations[1], '\n')

