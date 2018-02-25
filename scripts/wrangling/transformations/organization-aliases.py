class OrganizationAliases(TransformBase):
  DESCRIPTION = "Create aliases to group misspellings and different spellings of the same organizations"

  ALIASES = {
    "ACORN": [ "ACORN Canada", "ACORN Members Testimonials" ],
    "Bell": [ "Bell Canada" ],
    "Axia": [ "Axia NetMedia Corp." ],
    "BC Broadband Association": [ "BC Broadband Association (BCBA)" ],
    "Blake, Cassels & Graydon LLP": [ "Blake, Cassels & Graydon LLP? ?"],
    "Canadian Network Operators Consortium": [ "Canadian Network Operators Consortium Inc." ],
    "Cisco Systems": [ "Cisco Systems Inc." ],
    "Cogeco": [ "Cogeco Cable Inc." ],
    "Cree Nation Government": [ "Cree Nation Government and Eeyou Communications Network" ],
    "Federation of Canadian Municipalities": [ "Federation of Canadian Municipalities (FCM)" ],
    "Harewaves Wireless": [ "Harewaves Wireless Inc." ],
    "Manitoba Keewatinowi Okimakinak": [ "Manitoba Keewatinowi Okimakinak Inc.", "MKO" ],
    "Media Access Canada": [ "Media Access Canada / Access 2020" ],
    "Open Media": [ "OpenMedia" ],
    "OneWeb": [ "OneWeb, Ltd." ],
    "Province of British Columbia": [ "Province of BC" ],
    "Rogers": [ "Rogers Communications" ],
    "SANNY Internet Services": [ "SANNY Internet Service" ],
    "SSi": [ "SSi Group of Companies" ],
    "SaskTel": [ "Saskatchewan Telecommunications (SaskTel)" ],
    "Shaw": [ "Shaw Cablesystems G.P.", "Shaw Communications", "Shaw Communications Inc." ],
    "TekSavvy": [ "TekSavvy Solutions Inc." ],
    "Telus": [ "TELUS Communications Company", "Telus Communications" ],
    "Thetis Island Resident's Association": [ "Thetis Island Residents Assoc" ],
    "Union des Consommateurs": [ "Union des consommateurs" ],
    "Xplornet": [ "Xplornet Communications Inc." ],
    "Yak Communications": [ "Yak Communications (Canada) Corp." ]
  }

  def match(self):
    alias_to_org = {}
    for root_name, alias_names in self.ALIASES.items():
      for alias_name in alias_names:
        alias_to_org[alias_name] = root_name
    
    with neo4j() as tx:
      results = tx.run("""
        MATCH (o:Organization)
        WHERE o.name IN $aliases AND
          NOT (o)-[:ALIAS_OF]->(:Organization)
        RETURN ID(o) AS id, o.name AS name
      """, aliases=list(alias_to_org.keys()))

    create_aliases = {}

    # reshape into an easy to digest form in the transform function
    for r in results:
      root_name = alias_to_org[r['name']]
      if root_name not in create_aliases:
        create_aliases[root_name] = []
      create_aliases[root_name].append(r['id'])
    
    return create_aliases

  def transform(self, data):
    tx_results = []
    with neo4j() as tx:
      for root_name, alias_ids in data.items():
        results = tx.run("""
          MATCH (alias:Organization)
          WHERE ID(alias) IN $alias_ids
          MERGE (o:Organization { name: $root_name })
          MERGE (alias)-[:ALIAS_OF]->(o)
        """, root_name=root_name, alias_ids=alias_ids)
        tx_results.append(results)
      # Use a category from the original organizations if one doesn't exist on the root organization
      # they are now aliases of
      results = tx.run("""
        MATCH (o:Organization)-[:ALIAS_OF]->(rootorg:Organization)
        WHERE NOT EXISTS(rootorg.category) AND
        EXISTS(o.category)
        SET rootorg.category = o.category
      """)
      tx_results.append(results)
    return neo4j_summary(tx_results)
