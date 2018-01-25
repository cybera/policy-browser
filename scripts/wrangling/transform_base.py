from os import path

class TransformBase:
  def __init__(self):
    self.status = []
    self.preconditions_met = True
    self.completed = False

  def preconditions(self):
    return

  def match(self):
    return True

  def transform(self, data):
    return ["Not implemented"]

  def check_file(self, fpath):
    if not path.exists(fpath):
      self.preconditions_met = False
      self.status.append(f"Precondition: {fpath} needs to exist")

  def process_match(self):
    data_to_transform = self.match()
    if not data_to_transform:
      null_status = "Nothing to transform"
      if null_status not in self.status:
        self.status.append(null_status)

    return data_to_transform

  def process(self, processing_text=None):
    if not self.preconditions_met:
      return False

    if not processing_text:
      processing_text = f"- {self.DESCRIPTION}"

    if not self.completed:
      data_to_transform = self.process_match()
      if data_to_transform:
        print(processing_text)
        transform_status = self.transform(data_to_transform)
        self.status.extend(transform_status)
        self.completed = True

        return True

    return False