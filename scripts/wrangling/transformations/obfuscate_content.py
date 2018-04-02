import re

class ObfuscateContent(TransformBase):
  DESCRIPTION = "Do some basic obfuscation"

  def preconditions(self):
    if not hasattr(self, 'existing_names'):
      with neo4j() as tx:
        name_results = tx.run("MATCH (p:Person) RETURN p.name AS name")
        org_results = tx.run("MATCH (o:Organization) RETURN o.name AS name")
      
        name_tuples = [re.split(r"\s+", row['name']) for row in name_results]
        name_words = [w for n in name_tuples for w in n]
        name_words = [w.strip() for w in name_words]
        name_words = [w for w in name_words if re.match(r"[A-Z][a-z]+", w) and len(w) > 3]
        name_words = set(name_words)

        org_tuples = [re.split(r"\s+", row['name']) for row in org_results]
        org_words = [w for o in org_tuples for w in o]
        org_words = [w.strip() for w in org_words]
        org_words = [w for w in org_words if re.match(r"[A-Z][a-z]+", w)]
        org_words = set(org_words)

        # Just a list of random words that seem to have gotten caught up in some of the names and we don't
        # really want to hide.
        whitelist = { "You", "Storm" }

        self.existing_names = (name_words - org_words) - whitelist

        names_joined = "|".join(self.existing_names)

        self.names_regexp = re.compile(f"(^|\s)({names_joined})([^A-Za-z'])")
    
    if not (hasattr(self, 'existing_names') and hasattr(self, 'names_regexp')):
      self.preconditions_met = False
      self.status.append(f"Precondition: At least a few people have to exist in the database")
      

  def match(self):
    with neo4j() as tx:
      results = tx.run("""
        MATCH (n)
        WHERE (n:Document OR n:Segment) AND
              (
                (EXISTS(n.content) AND NOT EXISTS(n.content_obfuscated)) OR
                (EXISTS(n.hlcontent) AND NOT EXISTS(n.hlcontent_obfuscated))
              )
        RETURN ID(n) AS id, n.content AS content, n.hlcontent AS hlcontent, labels(n) AS labels
      """)

    return results

  def transform(self, data):
    tx_results = []

    with neo4j() as tx:
      for row in data:
        nodeid = row['id']
        content = row['content']
        hlcontent = row['hlcontent']
        nodetype = row['labels'][0]

        print(f"obfuscating: {nodetype}(id:{nodeid})")

        if content:
          obfuscated_content = self.obfuscate(content)
          results = tx.run("MATCH (n) WHERE ID(n) = $nodeid SET n.content_obfuscated = $ocontent", 
                           nodeid=nodeid, ocontent=obfuscated_content)
          tx_results.append(results)

        if hlcontent:
          obfuscated_hlcontent = self.obfuscate(hlcontent)
          results = tx.run("MATCH (n) WHERE ID(n) = $nodeid SET n.hlcontent_obfuscated = $ocontent",
                           nodeid=nodeid, ocontent=obfuscated_hlcontent)
          tx_results.append(results)

    return neo4j_summary(tx_results)

  def obfuscate(self, text):
    text = self.obfuscate_content_names(text)
    text = self.obfuscate_content_emails(text)
    text = self.obfuscate_content_phone_number(text)
    text = self.obfuscate_content_postal_code(text)
    return text


  def obfuscate_content_names(self, content, debug_mode=False):
    replacement = "\\1****\\3"
    if debug_mode:
      replacement = "\\1**\\2**\\3"

    return re.sub(self.names_regexp, replacement, content)

  def obfuscate_content_emails(self, content, ):
    emails_regexp = r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b"
    return re.sub(emails_regexp, "******@***.com", content, flags=re.IGNORECASE)

  def obfuscate_content_phone_number(self, content):
    phone_number_regexp = r"(\d\.?|\+\d\.?)?\(?\d{3}(\.| |-|\))\d{3}(\.| |-)\d{4}"
    return re.sub(phone_number_regexp, "*-***-***-****", content)

  def obfuscate_content_postal_code(self, content):
    postal_code_regexp = r"[ABCEGHJKLMNPRSTVXY]{1}\d{1}[A-Z]{1} *\d{1}[A-Z]{1}\d{1}"
    return re.sub(postal_code_regexp, "*** ***", content)
