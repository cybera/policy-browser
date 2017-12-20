from scrapy.selector import Selector

class HTMLSubmission:
  def __init__(self, text):
    self.doc = Selector(text=text)

  def top_level(self, fieldname):
    element = self.doc.xpath("//div[contains(text(),'%s')]/*" % fieldname)
    text = element.xpath(".//text()").extract_first()
    if text:
     return "".join(text).strip()
    else:
      return None

  def client_info(self, fieldname):
    element = self.doc.xpath("//div[contains(text(),'Client information')]/following::div[contains(text(),'%s')][1]/*" % fieldname)
    text = element.xpath(".//text()").extract()
    if text:
      return "".join(text).strip()
    else:
      return None

  def designated_representative(self, fieldname):
    element = self.doc.xpath("//div[contains(text(),'Designated representative')]/following::div[contains(text(),'%s')][1]/*" % fieldname)
    text = element.xpath(".//text()").extract()
    if text:
      return "".join(text).strip()
    else:
      return None

  def comment(self):
    element = self.doc.xpath("//div[contains(text(),'Comment')]/following::div[1]")
    text = element.xpath(".//text()").extract()
    if text:
      return "".join(text).strip()
    else:
      return None
