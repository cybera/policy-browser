#!/usr/bin/env python

from os.path import join, splitext, exists as path_exists, basename
from requests import put
from ftfy import fix_encoding
from util import sha256
from glob import glob
from zipfile import ZipFile
import json
import re
from pathlib import Path

def convert_file(inpath, outdir, open_func=open, open_flags='rb', check_existing=False):
  outname = "%s.txt" % sha256(inpath, open_func=open_func, open_flags=open_flags)
  outpath = join(outdir, outname)

  if check_existing and path_exists(outpath):
    return

  with open_func(inpath, open_flags) as indoc:
    response = put("http://tika:9998/tika", indoc)

    if response.status_code == 200:
      txt = fix_encoding(response.content.decode('utf-8'))

      with open(outpath, 'w') as outdoc:
        outdoc.write(txt)

def copy_file(inpath, outdir, open_func=open, open_flags='rb', check_existing=False):
  extension = splitext(inpath)[1]

  outname = "".join([sha256(inpath, open_func=open_func, open_flags=open_flags), extension])
  outpath = join(outdir, outname)

  if check_existing and path_exists(outpath):
    return

  with open(outpath, 'wb') as outdoc:
    with open_func(inpath, open_flags) as indoc:
      for chunk in iter(lambda: indoc.read(4096), b""):
        outdoc.write(chunk)

def extract_basic_filename_info(fname, container_filename=None):
  dtype=fname.rsplit('.', 1)[1]

  if container_filename:
    info_name = container_filename
  else:
    info_name = fname

  the_rest=info_name.rsplit('.', 1)[0]
  [public_process_number,case,dmid,submission_and_orig_filename] = the_rest.split('.', 3)
  submission_name = re.sub(r'\(.*\)','', submission_and_orig_filename)
  
  info = {
    'name': fname,
    'type': dtype,
    'ppn': public_process_number,
    'case': case,
    'dmid': dmid,
    'submission_name': submission_name
  }

  if container_filename:
    info['container_filename'] = container_filename

  return info


def merge_meta(inpath, outdir, container_filename=None, open_func=open, open_flags='rb'):
  outname = "%s.json" % sha256(inpath, open_func=open_func, open_flags=open_flags)
  outpath = join(outdir, outname)
  
  meta = {}
  if path_exists(outpath):
    meta = json.load(open(outpath))

  filename_info = extract_basic_filename_info(basename(inpath), container_filename)

  meta = {**meta, **filename_info}

  with open(outpath, 'w') as f:
     f.write(json.dumps(meta, indent=4))

def process_file(inpath, processed_dir, container_filename=None, open_func=open, open_flags='rb', check_existing=False):
  txtdir = join(processed_dir, "raw_text")
  hashdir = join(processed_dir, "hashed")
  metadir = join(processed_dir, "meta")

  Path(txtdir).mkdir(parents=True, exist_ok=True)
  Path(hashdir).mkdir(parents=True, exist_ok=True)
  Path(metadir).mkdir(parents=True, exist_ok=True)

  copy_file(inpath, hashdir, open_func=open_func, open_flags=open_flags, check_existing=check_existing)
  convert_file(inpath, txtdir, open_func=open_func, open_flags=open_flags, check_existing=check_existing)
  merge_meta(inpath, metadir, container_filename=container_filename, open_func=open_func, open_flags=open_flags)

scrapedir = join("data", "raw")
processed_dir = join("data", "processed")
txtdir = join("data", "processed", "raw_text")
check_existing = True

for inpath in glob("%(scrapedir)s/*" % locals()):
  if inpath.endswith("zip"):
    print("Processing zip: %s" % inpath)
    with ZipFile(inpath) as zfile:
      for archive_file in zfile.filelist:
        print("** %s" % archive_file.filename)
        process_file(archive_file.filename, processed_dir, container_filename=basename(inpath), 
          open_func=zfile.open, open_flags='r', check_existing=check_existing)
  else:
    print("Processing: %s" % inpath)
    process_file(inpath, processed_dir, check_existing=check_existing)
