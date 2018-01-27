#mport subprocess

# This is the stupidest thing I've ever done but it seems to get the job done
# agentdave, you did not see this. Walk away. I have to do this to resent
# random seeds between subprocess calls. 
for i in range(100):
	print("On iteration " , i)
	import subprocess
	subprocess.call(["python3", "topic_analysis.py"])
	print("I AM A SPACE")

file = open("MC_Sentence_indexes.txt", 'r')

indexes = []
from collections import Counter

for lines in file.readlines():
	print(lines.strip())
	indexes.append(lines.strip())

a = Counter(indexes)
print(a)


