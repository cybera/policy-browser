### Question1:
 What positions on affordability are being taken by different types of intervenors?

### Solr queries:

- bin/segment 'content:"internet, expensive"~10 OR content:"broadband, expensive"~10 OR content:"services, expensive"~10 OR content:"service, expensive"~10' --add --rows=156 --OMexclude"
- bin/segment 'content:"internet, cheap"~10 OR content:"broadband, cheap"~10 OR content:"services, cheap"~10 OR content:"service, cheap"~10' --add --rows=8 --OMexclude"  
- bin/segment 'content:"internet, affordable"~10 OR content:"broadband, affordable"~10 OR  content:"services, affordable"~10 OR content:"service, affordable"~10'  --rows=428 --add --OMexclude")
- bin/segment 'content:"internet, affordability"~10 OR content:"broadband, affordability"~10 OR content:"services, affordability"~10 OR content:"service, affordability"~10' --add --rows=246 --OMexclude"  
- bin/segment 'content:"internet, cost"~10 OR content:"broadband, cost"~10 OR content:"services, cost"~10 OR content:"service, cost"~10' --add --rows=566 --OMexclude"  
- bin/segment 'content:"internet, price"~10 OR content:"broadband, price"~10 OR content:"services, price"~10 OR content:"service, price"~10' --rows=458 --add --OMexclude"`

### Doc2vec queries:

Affordability of broadband internet access

### Summary stats:
Note: Numbers may be variable depending on what version of the application you're currently using.


Category| Number of docs in database | Number of docs covered by solr search results | Number of docs covered by  doc2vec results|
--- | --- | --- | --- |
Advocacy organizations |  264 | 107 | 95
Chamber of commerce/economic dev agency |    4 | 0 | 0
Government  | 111 | 46 | 38
Network operator - Cable companies | 125 | 47 | 45
Network operator: other | 208 | 81 | 68
Network operator: Telecom Incumbents | 342 | 107| 85
Other | 90 | 29 | 24
Small incumbents  | 11  | 5  | 2
None  | 1322 | 439  | 297


#### Top 10 most  common words:

Advocacy organizations  | Government | Network operator - Cable companies |  Network operator: other|  Network operator: Telecom Incumbents  | None   | Other  | Small incumbents
--- | --- | --- | --- | --- | --- | --- | ---
 service   1.5%    |        service   2.9%    |  service   2.6%   |  service   2.7%   |   service   2%      |      service   2.1%   |        service   2.6%  |  service   2.9%
 services   1.3%    |       internet   1.9%       |                services   2%      |     services   1.9%    |                   services   1.8%     |     internet   1.4%       |      services   2.2%    |    services   2.2%
 broadband   1.3%    |       services   1.5%         |            internet   1.8%   |       broadband   1.8%    |                 broadband   1.6%   |        broadband   1.3%       |    internet   2%  | jtf   1.6%
  access   1%     |     broadband   1.2%          |          broadband   1.4%    |      internet   1.2%        |                  telus   1.5%      |           services   1.3% | telecommunications   1.5%   |    access   1.5%
  internet   0.8%  | speed   1%    |                     rogers   1.1%      |       access   1.1%             |          internet   1.2%     |      ay   1.1%     |     broadband   1.1% | broadband   1.4%
telecommunications   0.6%       |      access   0.9%       |                  access   0.9%      |   cost   0.8%              |         bell   1.1%    |        access   0.9%      |       access   1.4% | wireline   1.2%
 canadians   0.6%         |     telecommunications   0.8%           |        information   0.8 %    |          commission   0.8%                |        access   0.9%          |       cost   0.7%           |   basic   1.1%    | customers   1.2%
 basic   0.6%        |      basic   0.7%        |                 mbps   0.8% | telecommunications   0.8%               |             commission   0.8%          |  hw   0.7%              |   pm   0.8%    |   internet   1.2%
canada   0.5%    |        cost   0.7%     |                   telecommunications   0.8%     |     canadians   0.7%     |                      mbps   0.7% | highway   0.7%   |       canada   0.8%   |    wireless   1.2%
 basic   0.6%     |    subsidy   0.6%         |                commission   0.7%        |        basic   0.7%       |      cost   0.7%     |   telecommunications   0.6%     |        canadians   0.8%    |   price   1.1%


#### Top 10 most  common trigrams:

Advocacy organizations    |                                 Government      |      Network operator - Cable companies    |                   Network operator: other     |     Network operator: Telecom Incumbents |                                     None              |                           Other                |           Small incumbents
 --- | ---| --- | --- | --- | --- | --- | ---
  email   medical   research   0.4 %   | eeyou   communications   network   0.5 %  | basic   telecommunications   services   0.6 %  | basic   telecommunications   services   0.6 %  |    telus   communications   company   1 % |  highway   highway   highway   1.7 % | basic   telecommunications   services   0.9 %      |    citc   jtf   page   2.6 %
  homework   email   medical   0.3 %   |   cree   nation   government   0.5 %      |     broadband   internet   service   0.6 %       |    basic   service   objective   0.5 %    |    communications   company   tnc   0.7 %  | hig   hw   ay   1.1 %     |    broadband   internet   access   0.5 %  | basic   service   objective   0.9 %
   basic   telecommunications   services   0.3 %  |         basic   telecommunications   services   0.4 %     |   tnc   2015   134   0.4 %    |    national   broadband   strategy   0.4 %  | tnc   2015   134   0.5 % |  ay   hig   hw   1.1 %        |       affordability   funding   mechanism   0.3 %           |     1   mbps   upload   0.7 %
affordable   access   coalition   0.3 %    |        powell   river   regional   0.3 %    |      basic   service   objective   0.4 %    |     crtc   2015   134   0.3 %          |             basic   telecommunications   services   0.4 % | hw   ay   hig   1 %     |    basic   service   obligation   0.3 %       |      broadband   internet   access   0.7 %
  affordability   funding   mechanism   0.2 %   |        river   regional   district   0.3 %     |     internet   access   services   0.4 %    |   basic   telecommunications   service   0.3 %     |         dec   dec   dec   0.3 % | ay   highw   ay   0.9 %     |    communications   frpc   basic   0.3 % |      providing   service   i.e   0.7 %
 broadband   deployment   funding   0.2 %    |     speed   internet   service   0.2 %    |     canadian   radio   television   0.3 %   |    affordable   access   coalition   0.3 %   |  mbps   target   speed   0.3 % | highw   ay   highw   0.7 %      |     frpc   basic   service   0.3 %   |   wireline   broadband   services   0.7 %
 deployment   funding   mechanism   0.2 %    |      local   service   subsidy   0.2 %   |    entry   level   broadband   0.3 %  | broadband   internet   service   0.3 %         |            5   1   mbps   0.3 % | broadband   internet   access   0.3 %     |    residential   telephone   service   0.3 %       |      5   mbps   download   0.5 %
  basic   service   package   0.2 %      |       local   service   subsidy   0.2 %        |     affordability   funding   mechanism   0.3 %     |    canadian   radio   television   0.2 %      |          company   tnc   2015   0.2 % | broadband   internet   access   0.2 %   |            tnoc   2015   134   0.3 %     |  additional   monthly   charges   0.5 %
crtc   2015   134   0.2 %   | basic   service   objectives   0.2 %      |   denotes   information   filed   0.2 %     |    internet   service   providers   0.2 %        |        basic   telecommunications   service   0.2 % |  basic   telecommunications   services   0.2 %   |         telephone   service   survey   0.3 %     |    affordable   wireline   telephony   0.5 %
 consultation   crtc   2015   0.1 %   |     affordable   telecommunications   services   0.2 %   |       broadband   internet   services   0.2 %   |   sbroadband   internet   access   0.2 %      |   connecting   canadians   program   0.2 % |  ig   hw   ay   0.2 %    |      basic   service   obligations   0.3 % | basic   telecommunications   services   0.5 %


#### Top sentiment words by category:

![top_sent](images/top_sent.png)
