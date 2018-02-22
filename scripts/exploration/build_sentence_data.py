import pandas as pd
from nltk import tokenize
import glob
from string import digits
# This removes names and other personal information. I'm not sure if it helps anything
# so it's commented out for the sentence extraction. 
import scrubadub

# this is used to make a pandas dataframe of all the sentences from each document. 

datadir = 'your data directory'

# here Sentence Number is the TOTAL sentence number. Cumulative over all documents.


total_sentences = 0
count = 0
AllSentences = []
AllSentenceNumbers = []
AllDocuments = []
AllDocumentNumbers =[]
for i, files in enumerate(glob.glob(datadir + "*.txt")):
    print("Processing file number " , i)
    text = open(files, 'r').read()

    # break text into individual sentences 
    sentences = tokenize.sent_tokenize(text)
    
    for sentence in sentences:
        sentence = sentence.replace('\n',' ')
        # numbers are making things not unique look unique so get rid of them
        # willy-nilly and aggressively
        remove_digits = str.maketrans('','',digits)
        sentence = sentence.translate(remove_digits)
        
        #Arbitrarily remove short irrelevant sentences.
        if len(sentence) < 15:
            #print(sentence)
            pass
        else:
            # Note that this scrubadub really slows things down, so if it's not required
            # probably don't do it. 
            # sentence = scrubadub.clean(sentence)
            AllSentences.append(sentence)
            AllDocuments.append(files)
            AllDocumentNumbers.append(i)
            total_sentences += 1 

    

AllData = []
AllData.append(AllSentences)
AllData.append(range(0, len(AllSentences)))
AllData.append(AllDocuments)
AllData.append(AllDocumentNumbers)

#Transpose into columns
AllData = list(map(list, zip(*AllData)))

df = pd.DataFrame(AllData, columns=["Sentence", "SentenceNumber", "Document", "DocumentNumber"])

df.to_csv("SentenceData2.csv")




       




       


    



