# Project Charter: Towards a Clear Understanding of Canadian Internet Policy Consultations

## Project Background

The CRTC’s regulatory proceedings provide vital evidence of how Canadians are accessing the internet. Materials submitted to the CRTC are made publicly available. However, given the size and structure of the CRTC’s current database, these files are difficult to find, aggregate, and analyze. This makes it difficult to understand the key positions each party is taking, and what their impact is on the regulatory decision. 

These documents represent a potentially rich source of data for Canadians, including researchers and governments. Making it easier to extract high-level analysis of this data will help the public to better understand information presented at public proceedings. This will increase insights into the factors that affect CRTC outcomes, and allow the public to assess the impact of their participation in the policy making processes.

For example, in December 2016, the CRTC ruled that internet is a basic telecommunications service. Using a data science approach, we propose to create a set of open-source scripts and methodologies to report on the positions of respondents during this consultation, and how they interacted with each other. This will help Canadians understand how the decisions affecting internet service delivery are made. 

## Scope & Deliverables
### In-scope
- Analysis of Basic Service Objective 2016 consultation
- Creating interactive visualization(s)
- Blogs and outreach about results of the analysis
- Open sourcing code used for analysis

### Out of scope
- Developing web-scraper compatible with sites other than the CRTC 2016 BSO consultation

### Deliverables outlined in the proposal

High level goal: give Canadians a digestible view of the consultation process.

- publish a report on the 2016 BSO consultation that:   
-- will outline positions taken and how respondents interacted with each other   
-- outline key position changes during the consultation process  
- automate the analysis and open source its code, allowing others to easily reproduce, expand, and apply the same methodology to other public consultations  
- Create interactive visualizations highlighting how the submissions relate and contribute to the consultation  

### Team goals & ideas  
- Perform automated topic analysis on documents submitted  
- Create an explorable (network?) graph ecosystem (universe) around an issue 
-- semantic search 
-- knowledge graph? e.g. [grakn.ai](grakn.ai)
- Data Framework to extract interventions / submissions from a CRTC public consultation  
-- Create a data structure  
-- Ingest data in the appropriate structure / format  
-- Create requirements so that any other dataset can be dropped in  
- Reproducible Visualizations Framework  
-- Positions of contributors  
-- Structure of the consultation  
-- Timelines  
- Interactive online dashboard  
-- allow users to explore the consultation; e.g. enter search terms, see who mentioned them how many times. 
-- would be nice if users could drill down - e.g. see who said a particular thing, click on it to see the paragraph, click again to see the entire doc, etc. 

