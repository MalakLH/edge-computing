'''

This script copies your website from src/ into site/ and gives assets names containing a content hash, 
such as app.a1b2c3d4.css. When CSS changes, its filename changes too, 
helping browsers and CloudFront avoid serving stale cached assets.
CloudFront can then cache each version for a long time without confusing an old copy with the new one. 
This is called cache busting through asset fingerprinting.

'''

import hashlib, pathlib, shutil

SRC, OUT = pathlib.Path("src"), pathlib.Path("site") # getting the source and the output dir
shutil.rmtree(OUT, ignore_errors=True) # removing the site folder if it exists
shutil.copytree(SRC, OUT) # copies everything in src to sites
mapping = {}

for f in (OUT / "assets").iterdir(): # this is looping through the assets

    h = hashlib.sha256(f.read_bytes()).hexdigest()[:8] # calculates the hash of each file
    new = f.with_name(f"{f.stem}.{h}{f.suffix}") # renames the new asset
    f.rename(new) # actually renames on disk
    mapping[f"/assets/{f.name}"] = f"/assets/{new.name}" # records the results in the mapping doc

for page in OUT.rglob("*.html"): 

    t = page.read_text() # reads the html file as a string

    for old, new in mapping.items(): 
        t = t.replace(old, new) # replaces the old imports with the new ones in the html file 

    page.write_text(t) # writes the updated html code back to the file