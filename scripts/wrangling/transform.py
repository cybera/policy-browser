#!/usr/bin/env python

from glob import glob
from os import path
import util
import transform_base
import inspect


def init_transformation_mod(transformation):
  transformation.TransformBase = transform_base.TransformBase
  transformation.requirements = {}
  transformation.neo4j = util.neo4jtx
  transformation.neo4j_summary = util.neo4j_summary
  transformation.neo4j_count = util.neo4j_count
  transformation.path = path
  transformation.project_root = util.project_root

transforms_path = path.join("scripts", "wrangling", "transformations")
transform_module_paths = glob(path.join(transforms_path, "*.py"))
transformation_mods = [util.load_module(transform_module_path, "transforms") for transform_module_path in transform_module_paths]

transformation_status = {}
transformations = []

# Set up the modules
for tmod in transformation_mods:
  init_transformation_mod(tmod)
  util.init_module(tmod)
  transform_classes = util.classes(tmod, subclassof=transform_base.TransformBase)
  transform_objs = [t() for t in transform_classes]
  transformations.extend(transform_objs)

# Run through any preconditions
for tobj in transformations:
  tobj.preconditions()

# Read transformations being explicitly skipped
force_skip_transforms = []
with open(path.join(util.project_root, ".skip-transforms")) as skipfile:
  transform_names = [line.strip() for line in skipfile.readlines()]
  force_skip_transforms = [t for t in transformations if type(t).__name__ in transform_names]
for t in force_skip_transforms:
  t.status.append("Entry in .skip-transforms file")

cycles = 0
max_cycles = 20
completed_transformations = []
skipped_transformations = []

print("\n")
print("Running transformations:")
print("========================\n")

while cycles < max_cycles:
  transform_count = 0

  for t in transformations:
    if t not in force_skip_transforms and t.process():
      transform_count = transform_count + 1
      completed_transformations.append(t)
  
  if transform_count == 0:
    break

  cycles = cycles + 1

skipped_transformations = [t for t in transformations if t not in completed_transformations]

print("\n")

print("Completed transformations:")
print("==========================\n")

step = 1
for t in completed_transformations:
  print(f"[{'%03d' % step}] {t.DESCRIPTION}:")
  print(util.itemize(t.status, prefix="      - "))
  print("")
  step = step + 1

print("Skipped transformations:")
print("========================\n")

for t in skipped_transformations:
  print(f"{t.DESCRIPTION}:")
  print(util.itemize(t.status, prefix="  - "))
  print("")

print(f"\n(Transformation cycles: {cycles})")
