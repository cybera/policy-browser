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

savefile="Subsity_Question_300.txt"

s_indexes = []
with open("MC_Subsidize_CopyPaste_300_LT.txt", 'r') as file:
    for lines in file.readlines():
        s_indexes.append(int(lines))

file.close()
counted = Counter(s_indexes)
to_base = []

# Indexes of the copy-paste stuff that I don't really
# care about. 
copy_pastes = [1090, 1298, 2034, 1360, 246, 716, 918]
drop_copies = []

# Maybe put these in later, but these are just the copy pastes
# they kind of pollute the data so I've removed them (for now?)
for keys in counted:
    if int(df["DocumentNumber"][keys]) in copy_pastes:
        drop_copies.append(keys)

for drops in drop_copies:
    del counted[drops]
    
for keys in counted:
        to_base.append(keys)

to_base = sorted(to_base)
pd.options.display.max_colwidth = 150

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


def Create_Range(array, space = 3):
    # this creates the ranges for grabbing sentence data. 3 is default again
    # but feel free to change it if you want more things in a row. 

    # TODO: asymmetric sorting 

    sentence_combine = []
    # 2 * space is a little agressive certainly, but it prevents overlap
    # once I've gone and messed up the boundaries to prevent the document
    # mis-match 
    squished_array = list(group_integers(array, gap = 2 * space))
    before = len(squished_array)
    # shouldn't be any duplicates, but this is more of a 'just in case'
    squished_array = [list(x) for x in set(tuple(x) for x in squished_array)]

    for ranges in squished_array:
        start = min(ranges)
        stop = max(ranges) 

        if stop < start:
            print(start, stop, df["DocumentNumber"][start], df["DocumentNumber"][stop])
            

        bottom = space
        # use in range, going to be -1 of end point, so add one for fun
        top = space + 1
        # If we ping the past the last sentence, the program gets unhappy 
        try: 
            df["DocumentNumber"][stop + top]
        except KeyError:
            while True:
            
                try: 
                    top -= 1
                    df["DocumentNumber"][stop + top]
                    break
                except:
                    pass
        # this just prevents us from matching beginnings/endings of documents
        # by accident. Potentially infinite loops because I am lazy. 

        if df["DocumentNumber"][start] != df["DocumentNumber"][stop]:
            while True:
                stop -= 1
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

a = Create_Range(to_base, space=3)

# don't really need to sort, but I did it anyways. 
a = sorted(a)

# gets the counts if things have been squished together. 
counts_ordered = []
for r in a:
    tot_counts = 0
    for pot_key in range(r[0], r[1]+1):
        if pot_key in to_base:
            tot_counts += counted[pot_key]
    counts_ordered.append(tot_counts)


with open(savefile, 'w') as file:
    for i, ranges in enumerate(a):
        block = []
        for j in range(ranges[0], ranges[1]):
            block.append(" ".join([str(df["Sentence"][j])]))
            document = df["Document"][j].split('/')[-1].strip('.txt')
            print(df["Sentence"][j])
                
        firstsent = df["SentenceNumber"][ranges[0]]
        lastsent = df["SentenceNumber"][ranges[1]]

        block = " ".join(block)

        file.write(block)
        file.write(" OBVIOUS_DELIMITER ")
        #print(document)
        file.write(document)
        file.write(" OBVIOUS_DELIMITER ")
        file.write(str(counts_ordered[i]))

        file.write('\n')
        print('\n')
        # this should never happen, so if you see ohno something went wrong
        if lastsent < firstsent:
           print("ohno", firstsent, lastsent, df["DocumentNumber"][ranges[0]], df["DocumentNumber"][ranges[1]])
           # Fixed it. 

total = 0
for ranges in a:
    total += len(range(ranges[0],ranges[1]))

print("Used ", total, " out of ", len(df["Sentence"]))







    

    





