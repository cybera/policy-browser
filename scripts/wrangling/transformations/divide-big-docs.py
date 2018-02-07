import re
from nltk import word_tokenize
from wrangling import util
from itertools import chain

class DivideBigDocs(TransformBase):
  DESCRIPTION = "Divide OpenMedia docs that contain multiple individual responses"

  def preconditions(self):
    self.sha256s = {
      "openmedia": [
        "50110e805c7982550d81be640bebe0e2735ce41f3464eae5c9b3b9b12d1855ec",
        "f4942792e166c96b207db1705bce1d85a2a6de1e0ec292cdac625b953df7023b",
        "050e1b6bf143bf62c06fa91678baa9d1fa86d29883753b89e8a44ffb986fe900",
        "34ca3cc90d1612f21d612638a8893dc51734f0e3c2041647e5fd58fdd80420af",
        "0aecca51dcd60af32e8d30330ae235cfdfb0acd4fb77b6d8fc3aba57b4a14bad",
        "7f994edbed82c98a60e89c9d0e221633a6fd49c18c0741b89aa44300bdca39c8",
        "9aed65a3740ee483300d1980a85cd9ff753cb940599e6edfa0ff6687f1385c33",
        "996cdc9c830fc7f76fd8dae382916fd38906e776d092363ac0f5fbcd679a9ad0"
      ]
    }
    self.known_cities = []

  def match(self):
    query = """
      MATCH (d:Document)
      WHERE d.sha256 in $sha256s AND
        NOT (d)<-[:IN_COLLECTION]-(:Document)
      RETURN d.content AS content, d.sha256 AS sha256, d.name AS name
    """
    # Believe it or not, this is one of the simpler ways to flatten an array in
    # python. There's quite the ideological debate over this one...
    sha256list = list(chain.from_iterable(self.sha256s.values()))
    with neo4j() as tx:
      results = tx.run(query, sha256s=sha256list)

    return results

  def transform(self, data):
    tx_results = []

    for doc in data:
      if doc['sha256'] in self.sha256s["openmedia"]:
        tx_results.extend(self.add_openmedia_subdocs(doc))
    
    return tx_results

  def clean_names_and_cities(self, subdocs):
    cities = {}
    for subdoc in subdocs:
      city = subdoc['city'].lower()

      if city not in cities:
        cities[city] = 1
      else:
        cities[city] += 1

    likely_cities = [city for city, count in cities.items() if count > 1]

    for subdoc in subdocs:
      city = subdoc['city']
      name = subdoc['name']

      city_parts = re.split(r"\s+", city)
      name_parts = re.split(r"\s+", name)

      # sometimes there's a weird split of a name, or someone uses a middle name
      if city.lower() not in likely_cities:
        new_city_str = util.proper_noun_fragments_to_str(city_parts[1:])
        if new_city_str.lower() in likely_cities:
          name_parts.append(city_parts[0])
          city = new_city_str
        else:
          city = util.proper_noun_fragments_to_str(city_parts)

      name = util.proper_noun_fragments_to_str(name_parts)
      
      city, province = util.separate_province(city)

      subdoc['name'] = name.title()
      subdoc['city'] = city.title()
      subdoc['province'] = province

    return subdocs
    

  def add_openmedia_subdocs(self, doc):
    # Remove boilerplate header text
    header_re = re.compile(r"First\s+Name\s+Last\s+Name\s+City\s+Postal\s+Code\s+Comment")
    doc_content = header_re.sub(" ", doc['content'])
    
    parsed_subdocs = self.parse_openmedia_subdocs(doc_content)
    parsed_subdocs = self.clean_names_and_cities(parsed_subdocs)

    tx_results = []

    insert_query = """
      MATCH (pdoc:Document { sha256: $pdoc256 })
      MERGE (p:Person { name: $name })
      ON MATCH SET p.location = $location, p.postal = $postal
      ON CREATE SET p.location = $location, p.postal = $postal
      WITH p, pdoc
      MERGE (d:Document { sha256: $sha256, type:'subdoc' })
      ON CREATE SET d.content = $content, d.name = $docname
      WITH p, pdoc, d
      MERGE (d)-[:IN_COLLECTION]->(pdoc)
      MERGE (p)-[:SUBMITTED { method: $method }]->(d)
    """

    with neo4j() as tx:
      for psd in parsed_subdocs:
        sha256 = util.sha256str(psd["content"])
        results = tx.run(insert_query, pdoc256=doc['sha256'], name=psd['name'], 
                         location=psd['city'], postal=psd['postal'], sha256=sha256, 
                         content=psd['content'], method="divide-big-docs", 
                         docname=f"openmedia: {psd['name']}")
        tx_results.append(results)

    return neo4j_summary(tx_results)

  def cleaned_matches(self, match):
    name = match.group('name')
    city = match.group('city')
    postal = match.group('postal')
    salutation = match.group('salutation')
    
    if name:
      name = name.replace("\n", " ").strip()
    if city:
      city = city.replace("\n", " ").strip()
    if postal:
      postal = postal.replace("\n", "").title().strip()
    if salutation:
      salutation = salutation.replace("\n", " ").strip()
    else:
      salutation = ""
    
    return name, city, postal, salutation

  def parse_openmedia_subdocs(self, content):
    parsed_subdocs = []

    subdoc_start_re = re.compile(r"^(?P<name>([A-Za-z]+\s+){2,}?)(?P<city>([A-Za-z]+\s+){1,}?)(?P<postal>([a-zA-Z][0-9][a-zA-Z])\s*([0-9][a-zA-Z][0-9])?)\s+(?P<salutation>Dear Commissioners)?", flags=re.MULTILINE)
    scanner = subdoc_start_re.scanner(content)
    
    match = scanner.search()
    last_start, last_end = match.span()
    last_name, last_city, last_postal, last_salutation = self.cleaned_matches(match)

    while match:
      match = scanner.search()

      if match:
        next_start, next_end = match.span()
        sdcontent = content[last_end:next_start]
        last_start, last_end = next_start, next_end
        parsed_subdocs.append({ 
          "name": last_name, 
          "city": last_city, 
          "postal": last_postal, 
          "content": last_salutation + sdcontent
        })

        # get the name, city, and postal code that will be used for the next section
        last_name, last_city, last_postal, last_salutation = self.cleaned_matches(match)

    sdcontent = content[last_start:]
    parsed_subdocs.append({ 
      "name": last_name, 
      "city": last_city, 
      "postal": last_postal, 
      "content": last_salutation + sdcontent 
    })

    return parsed_subdocs
    

  def make_slices(self, lines, break_threshold=3):
    slices = []
    current_slice = []
    breaks = []

    for line in lines:
      if line != "":
        if len(breaks) >= break_threshold:
          slices.append(current_slice)
          current_slice = []

        breaks = []
        current_slice.append(line)
      else:
        breaks.append(line)
    
    return slices

  def postal_index(self, tokens):
    for i,t in enumerate(tokens):
      if re.match(r"^[a-zA-Z][0-9][a-zA-Z].*", t):
        return i
    return None

  def clip_openmedia_subdoc_header(self, content):
    postal_code_match = re.search("[a-zA-Z][0-9][a-zA-Z]\s*([0-9][a-zA-Z][0-9])?", content)
    if postal_code_match:
      _, pc_end = postal_code_match.span()
      return content[pc_end:]

    dear_commissioner_match = re.search("Dear Commissioners")
    if dear_commissioner_match:
      dc_start, _ = dear_commissioner_match.span()
      return content[dc_start:]

      return content