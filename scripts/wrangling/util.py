import hashlib
from neo4j.v1 import GraphDatabase
from contextlib import contextmanager
from os import path
import importlib.util
import inspect

def sha256(path, open_func=open, open_flags='rb'):
  hash_sha256 = hashlib.sha256()
  with open_func(path, open_flags) as f:
    for chunk in iter(lambda: f.read(4096), b""):
      hash_sha256.update(chunk)
  return hash_sha256.hexdigest()

def sha256str(text):
  hash_sha256 = hashlib.sha256()
  hash_sha256.update(text.encode())
  return hash_sha256.hexdigest()

neo4j_uri = "bolt://neo4j:7687"
neo4j_driver = GraphDatabase.driver(neo4j_uri, auth=("neo4j", "password"))

@contextmanager
def neo4jtx():
  with neo4j_driver.session() as session:
    with session.begin_transaction() as tx:
      yield tx

def load_module(module_path, prefix):
  modname = path.splitext(path.basename(module_path))[0]
  spec = importlib.util.spec_from_file_location(f"{prefix}.{modname}", module_path)
  mod = importlib.util.module_from_spec(spec)

  return mod

def init_module(mod):
  mod.__spec__.loader.exec_module(mod)

def add_module_variables(m, **kwargs):
  for key in kwargs:
    setattr(m, key, kwargs[key])

def neo4j_summary(results):
  if not isinstance(results, list):
    results = [results]

  counters = {}
  counter_objs = [r.summary().counters for r in results]

  if any([obj.contains_updates for obj in counter_objs]) :
    counters["Constraints added"] = sum([obj.constraints_added for obj in counter_objs])
    counters["Constraints removed"] = sum([obj.constraints_removed for obj in counter_objs])
    counters["Indexes added"] = sum([obj.indexes_added for obj in counter_objs])
    counters["Indexes removed"] = sum([obj.indexes_removed for obj in counter_objs])
    counters["Labels added"] = sum([obj.labels_added for obj in counter_objs])
    counters["Labels removed"] = sum([obj.labels_removed for obj in counter_objs])
    counters["Nodes created"] = sum([obj.nodes_created for obj in counter_objs])
    counters["Nodes deleted"] = sum([obj.nodes_deleted for obj in counter_objs])
    counters["Properties set"] = sum([obj.properties_set for obj in counter_objs])
    counters["Relationships created"] = sum([obj.relationships_created for obj in counter_objs])
    counters["Relationships deleted"] = sum([obj.relationships_deleted for obj in counter_objs])

    counter_strs = [f"{counters[counter]} {counter}" for counter in counters if counters[counter] > 0]

    return counter_strs
  else:
    return ["No updates"]    

def neo4j_count(match_condition, **kwargs):
  with neo4jtx() as tx:
    results = tx.run(match_condition + " RETURN COUNT(*) AS count", **kwargs)
  return int(results.single()['count'])

def classes(mod, subclassof=None, exclude=[]):
  mod_class_tuples = inspect.getmembers(mod, inspect.isclass)
  mod_classes = [tup[1] for tup in mod_class_tuples if tup[1] not in exclude]
  if subclassof:
    mod_classes = [c for c in mod_classes if issubclass(c, subclassof)]
    mod_classes = [c for c in mod_classes if c != subclassof]
  return mod_classes

def itemize(strlist, prefix):
  prefixed_strs = [f"{prefix}{str}" for str in strlist]
  return "\n".join(prefixed_strs)

class PathBuilder(str):
  def __init__(self, rootpath):
    self.root = rootpath

  def __repr__(self):
    return self.root

  def add(self, *subpaths):
    for subpath in subpaths:
      fullpath = path.join(self.root,subpath)
      setattr(self, subpath, PathBuilder(fullpath))

project_root = PathBuilder("/mnt/hey-cira")
project_root.add("data", "scripts")
project_root.data.add("raw", "processed")
project_root.data.processed.add("hashed", "meta", "raw_text", "sorted")
