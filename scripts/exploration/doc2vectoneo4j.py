'''
This script is used to clean up the ouptut files of the doc2bvec
MC script and then insert those sentence tags into the neoj4 data
base
'''
import pandas as pd 
from collections import Counter
import time
from itertools import groupby, count

df = pd.read_csv("SentenceData2.csv")
df.drop_duplicates('Sentence', inplace=True)
# Purged most of the data, need to reindex
df.reset_index(inplace=True)

s_indexes = []

with open("MC_BasicService_CopyPaste_750.txt", 'r') as file:

    for lines in file.readlines():
        s_indexes.append(int(lines))


file.close()

counted = Counter(s_indexes)
to_base = []
copy_pastes = [1090, 1298, 2034, 1360, 246, 716, 918]
drop_copies = []

# Maybe put these in later, but these are just the copy pastes
# they kind of pollute the data so I've removed them ( for now?)
for keys in counted:
    if int(df["DocumentNumber"][keys]) in copy_pastes:
        drop_copies.append(keys)

for drops in drop_copies:
    del counted[drops]
    

for keys in counted:
  to_base.append(keys)

to_base = sorted(to_base)
pd.options.display.max_colwidth = 150

around = 3



def group_integers(array, gap = 3):
    # This groups sentence integers by whatever you tell it to for printing
    # 3 is default, feel free to go further
    out = []
    last = array[0]
    for x in array:
        if x-last > gap:
            yield out
            out = []
        out.append(x)
        last = x
    yield out 


def Create_Range(array, gap = 3):
    # this creates the ranges for grabbing sentence data. 3 is default again
    # but feel free to change it if you want more things in a row. 

    sentence_combine = []
    squished_array = list(group_integers(array, gap = gap))
    before = len(squished_array)
    # shouldn't be any duplicates, but this is more of a 'just in case'
    squished_array = [list(x) for x in set(tuple(x) for x in squished_array)]
    after = len(squished_array)


    for ranges in squished_array:
        start = min(ranges)
        stop = max(ranges) 

        if stop < start:
            print(start, stop, df["DocumentNumber"][start], df["DocumentNumber"][stop])
            quit()

        bottom = gap
        # use in range, going to be -1 of end point, so add one for fun
        top = gap + 1

        # this just prevents us from matching beginnings/endings of documents
        # by accident. Potentially infinite loops because I am lazy. 

        if df["DocumentNumber"][start] != df["DocumentNumber"][stop]:
            while True:
                stop -= 1
                print("SDFSDFSF", df["DocumentNumber"][start], df["DocumentNumber"][stop])
                if df["DocumentNumber"][start] == df["DocumentNumber"][stop]:
                    break


        if df["DocumentNumber"][start-bottom] != df["DocumentNumber"][int(start)]:
            while True:
                bottom -= 1
                if df["DocumentNumber"][start-bottom] == df["DocumentNumber"][start]:
                    break

        if df["DocumentNumber"][stop + top] != df["DocumentNumber"][stop]:
            while True:
                top -= 1
                if df["DocumentNumber"][stop + top] == df["DocumentNumber"][stop]:
                    break




        sentence_combine.append([start-bottom, stop+top])

    return sentence_combine

a = Create_Range(to_base, gap=3)



for i, ranges in enumerate(a): 
    sentencetoprint = []
    for j in range(ranges[0], ranges[1]):
        sentencetoprint.append(df["Sentence"][j])
        if j in to_base:
            place = to_base.index(j)
           

    for sentence in sentencetoprint:
        print(sentence, df["DocumentNumber"][to_base[place]], ranges, to_base[place])

    print('\n')
     


print(len(a))


with open("Basic_Service_Question.txt", 'w') as file:
    for ranges in a:
        block = []
        for j in range(ranges[0], ranges[1]):
            block.append(" ".join([str(df["Sentence"][j])]))
            document = df["Document"][j].split('/')[-1].strip('.txt')



                
        firstsent = df["SentenceNumber"][ranges[0]]
        lastsent = df["SentenceNumber"][ranges[1]]

        block = " ".join(block)
        
        file.write(block)
        file.write(" OBVIOUS_DELIMITER ")
        #print(document)
        file.write(document)
        file.write('\n')
        
        # this should never it, so if you see ohno something went wrong
        if lastsent < firstsent:
           # MESSED UP NEED TO MAKE SURE DOCUMENTS DON"T MIX
           print("ohno", firstsent, lastsent, df["DocumentNumber"][ranges[0]], df["DocumentNumber"][ranges[1]])
           # Fixed it. 


                    











    

    





