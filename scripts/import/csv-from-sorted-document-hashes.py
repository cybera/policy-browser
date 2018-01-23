#!/usr/bin/env python

import os
from glob import glob
from os.path import join as path_join, basename, splitext

project_dir = "/mnt/hey-cira"
data_dir = path_join(project_dir, "data")
sorted_dir = path_join(data_dir, "processed", "sorted")

org_paths = glob(path_join(sorted_dir, "*"))

output_file = path_join(data_dir, "processed", "sorted-document-organizations.csv")

with open(output_file, 'w') as csvfile:
  csvfile.write("\"sha256\",\"organization\"\n")
  for org_path in org_paths:
    org_name = basename(org_path)
    file_paths = glob(path_join(org_path, "*.*"))
    for file_path in file_paths:
      sha256 = splitext(basename(file_path))[0]
      csvfile.write(f"\"{sha256}\",\"{org_name}\"\n")
