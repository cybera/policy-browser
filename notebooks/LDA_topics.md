## LDA Topic modeling across all documents

- Took document content + french translation for french documents.
- Used words that appear more than 50 times
- Dictionary: 4338 terms


#### Maximum gamma per document for 10/30/100 topics
![10topics_gamma](images/10topics_gamma.png)

![30topics_gamma](images/30topics_gamma.png)

![100topics_gamma](images/100topics_gamma.png)

For 100 topics model more documents have gamma (per document per topic probability) closer to 1. It indicates better model.

#### Number of documents(%) per topic for 10 topics
![10topics_freq](images/10topics_freq.png)

`Top 4 most frequent topics + keywords`

Topic| Percent of docs | Keyword1 |Keyword2 | Keyword3 | Keyword4 | Keyword5 | Keyword6 | Keyword7 | Keyword8 | Keyword9 | Keyword10
--- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---
4 | 35.9% | "information"  | “service"   |  "internet"   | "crtc"     |   "mbps"    |    "customers"  |  "wireless"  |  "response"  |  "provide"  |   "data"
9  |  24.4% |  "service"  |   "services"   | "broadband" |   "commission" | "access"   |  "internet" | "basic"   |  “subsidy"  |  "canadians" |  "funding"
3  |  18.6% | "internet"  | ”service" |  "online" |  "costs"  |  "services" | "speed"  |  "access"  | "home"   |  "time"  |   "phone"
8  | 15.6%  | "broadband"  |  "services"  |  "communities"  | ”access"   |   "digital"   |  "community"  | ”service"  |   "internet"  |  "canada"    |  "network"  
Sum  | 94.5%  |   |   |   |   |   |   |   |   |   |  


#### Number of documents(%) per topic for 30 topics
![30topics_freq](images/30topics_freq.png)

`Top 6 most frequent topics + keywords`

Topic| Percent of docs | Keyword1 |Keyword2 | Keyword3 | Keyword4 | Keyword5 | Keyword6 | Keyword7 | Keyword8 | Keyword9 | Keyword10
--- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---
 6  | 13% | "telecommunications" | "crtc" | "commission" |  "telecom" |         "canadian" |  "regulatory" | "consultation"   | "information"  | "notice" |          "canada"            
24  |  12.9% | "internet" | ”speed"  |  "data"  |   "access"  | "rural"  |  "bell"   |  "month"  |  "wireless" | ”home"   |  "xplornet"
15  |  8.5%  | "information"  |  "response"   |  "crtc"    |     "commission"  |  "disclosure"   | "confidential" | "request"   |   "rogers"  |     "confidence"  |  "provided"  
30  | 7.8% | "internet"  |  "customers" | "wireless"  | "mbps"  |   "unlimited"  | ”plan"  |  "data"  |   "average"  | "gb"  |    "wireline"
26  | 7.6%  | "mbps"    |   "internet"  | "speeds"   |  "broadband"  | "upload"   |  "provide"  |  "download"  | ”households" | ”response"  |  "speed"
22  |  6.3%  | "bell"     |     "commission"    |     "canada"    |         "act"      |     "local"         |     "rate"       |        "crtc"        |       "telecommunications" |  "decision"      |     "rates"
Sum  |  56.1% |   |   |   |   |   |   |   |   |   |  




#### Number of documents(%) per topic for 100 topics
![100topics_freq](images/100topics_freq.png)

`Top 6 most frequent topics + keywords`

Topic| Percent of docs| Keyword1 |Keyword2 | Keyword3 | Keyword4 | Keyword5 | Keyword6 | Keyword7 | Keyword8 | Keyword9 | Keyword10
--- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---
65  | 11.6%  | "internet" | "service"  | "access"  |  "rural" |  "cell"  |  "phone"   |  "speed"  |  "live"  |  "services"   |  "provide"
99  | 8.6%  |"internet" | "service"  |  "speed"  |  "data"  |   "pm"   |    "month"  |   "rural"  |   "slow"   |   "bell"       |   "pay"
71  | 5.4%  |  "crtc"    |     "commission" |  "telecom"   |   "regulatory"  | "consultation" | "notice"   |    "canadian"  |   "information"   |  "review"    |   "basic"  
72  | 3.3%  |  "information" | "response"  |   "commission"  |  "crtc"   |      "disclosure"  |  "confidential" | "public"  |     "request"  |   "provided"  |   "rogers"
11  |  2.9% |  "digital"  |    "canadians"  |   "canadian"  |    "canada"  |     "access"   |    "services"  |   "basic"   |     "hearing"    |  "consultation" |  "economy"
60  | 2.9%  |   "customers" |  "service"  |   "call"  |      "wireless"  |  "plan"  |      "voice"   |    "information" | "services"  |  "mobile"  |  "internet"
Sum  | 34.7%  |   |   |   |   |   |   |   |   |   |  
