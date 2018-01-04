import hashlib

def sha256(path, open_func=open, open_flags='rb'):
  hash_sha256 = hashlib.sha256()
  with open_func(path, open_flags) as f:
    for chunk in iter(lambda: f.read(4096), b""):
      hash_sha256.update(chunk)
  return hash_sha256.hexdigest()
