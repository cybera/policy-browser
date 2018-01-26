file = open("MC_Sentence_indexes.txt", 'r')
import pandas as pd
import re
indexes = []
docs = []
import matplotlib.pyplot as plt

from collections import Counter
import collections

for lines in file.readlines():
	lines = lines.split()
	indexes.append(lines[0].strip())
	docs.append(lines[1].strip())

a = Counter(indexes)
#print(a)

myframe = pd.read_csv("SentenceData2.csv")
myframe.drop_duplicates('Sentence', inplace=True)
    # Purged most of the data, need to reindex
myframe.reset_index(inplace=True)

index = 58909
print(a)
pd.options.display.max_colwidth = 1000
response = myframe["Sentence"][index-5:index+5].to_string()
response = re.sub("\s\s+", " ", response)
response = ''.join(i for i in response if not i.isdigit())


file = open("TopResponses.txt",'w')
count = 0
for key in a:
	if a[key] > 70:
		count += 1
		print(key, a[key])
		index = int(key)
		response = myframe["Sentence"][index-5:index+5].to_string(index=False)
		response = re.sub("\s\s+", " ", response)

		file.write(response)
		file.write(" ".join(["\n", "Document Hash :", str(myframe["Document"][index]).split("/")[-1], "\n","Hits in MC: ", str(a[key]), "\n", "\n"]))
		
print(count)
file.close()


#print("".join(myframe["Sentence"][index-5:index+5].to_string().split(), '\n', myframe["DocumentNumber"][index])

# values = []
# labels = []

# a = a.values()
# a = sorted(a)
# plt.bar(range(len(a)), a, align='center')
# plt.xlabel("Sentence (number irrelevant)")
# plt.ylabel("Count out of 100")
# plt.title("Monte-Carlo results of doc2vec")

# plt.show()





