import re
from nltk import word_tokenize
from wrangling import util

class DivideBigDocs(TransformBase):
  DESCRIPTION = "Divide OpenMedia docs that contain multiple individual responses"

  def preconditions(self):
    self.sha256 = "9aed65a3740ee483300d1980a85cd9ff753cb940599e6edfa0ff6687f1385c33"

  def match(self):
    query = """
      MATCH (d:Document { sha256: $sha256 })
      WHERE NOT (d)<-[:IN_COLLECTION]-(:Document)
      RETURN d.content AS content
    """
    with neo4j() as tx:
      results = tx.run(query, sha256=self.sha256)

    return [r['content'] for r in results]

  def transform(self, data):
    lines = [l.strip() for l in data[0].split("\n")]
    lines = lines[7:]
    subdocs = self.make_slices(lines)

    parsed_subdocs, problem_subdocs = self.parse_subdocs(subdocs)

    tx_results = []

    with neo4j() as tx:
      for psd in parsed_subdocs:
        sha256 = util.sha256str(psd["content"])
        results = tx.run("""
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
        """, pdoc256=self.sha256, name=psd['name'], location=psd['city'], postal=psd['postal'], 
        sha256=sha256, content=psd['content'], method="divide-big-docs", docname=f"openmedia: {psd['name']}")
        tx_results.append(results)

    return neo4j_summary(tx_results)

  def parse_subdocs(self, subdocs):
    problem_subdocs = []

    subdoc_first_words = [word_tokenize(f"{sd[0]} {sd[1]} {sd[2]}") for sd in subdocs]
    postal_indices = [self.postal_index(sfw) for sfw in subdoc_first_words]
    parsed_subdocs = []

    for i, sdfw in enumerate(subdoc_first_words):
      pcidx = postal_indices[i]
      locidx = 2
      if not pcidx or locidx > pcidx:
        problem_subdocs.append(f"[{i}]: {sdfw}")
      else:
        name = " ".join(sdfw[0:locidx]).title()
        city = " ".join(sdfw[locidx:pcidx]).title()
        if len(sdfw[pcidx]) > 3:
          pcode = sdfw[pcidx].title()
        else:
          pcode = " ".join(sdfw[pcidx:pcidx+2]).title()
        content = "\n".join(subdocs[i])
        parsed_subdocs.append({ "name": name, "city": city, "postal": pcode, "content": content })

    return parsed_subdocs, problem_subdocs

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