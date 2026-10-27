#!/usr/bin/env python3
"""Validate the complete static Pages artifact without external dependencies."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote
import json, re, runpy, sys
ROOT=Path(__file__).resolve().parents[1]; SITE=ROOT/'site'
class Page(HTMLParser):
 def __init__(self): super().__init__(); self.refs=[]; self.ids=[]; self.cards=[]; self.images=[]; self.lang=None; self.direction=None
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if tag=='html': self.lang=a.get('lang');self.direction=a.get('dir')
  if 'id' in a: self.ids.append(a['id'])
  if tag=='article' and 'feature-card' in a.get('class','').split(): self.cards.append(a['id'])
  if tag=='img': self.images.append(a); assert a.get('alt') is not None,'Image is missing alt'
  for k in ('href','src'):
   if k in a: self.refs.append(a[k])
# Run the generator in-process with --check: no subprocess, no shell, and the
# assert inside build-site.py fails this run if the rendered pages are stale.
sys.argv=[str(ROOT/'Scripts/build-site.py'),'--check']
runpy.run_path(sys.argv[0],run_name='__main__')
features=json.loads((SITE/'features.json').read_text()); assert len(features)==39
assert len({f['id'] for f in features})==len(features)
for f in features:
 for k in ('title','title_ar','description','description_ar','note','note_ar'): assert f[k].strip(),(f['id'],k)
 p=SITE/'assets/screenshots'/f"{f['image']}.jpg"; assert p.is_file(),str(p)
 assert p.read_bytes().startswith(b'\xff\xd8'),f'Invalid JPEG: {p}'
pages={}
for p in SITE.glob('*.html'):
 page=Page();page.feed(p.read_text());assert len(page.ids)==len(set(page.ids)),f'Duplicate IDs in {p.name}';pages[p]=page
for p,page in pages.items():
 for ref in page.refs:
  u=urlsplit(ref)
  if u.scheme or u.netloc: continue
  target=(p.parent/unquote(u.path)).resolve() if u.path else p
  assert target.is_relative_to(SITE.resolve()),f'Path outside site: {ref}'
  assert target.exists(),f'Broken asset in {p.name}: {ref}'
  if u.fragment and target in pages: assert unquote(u.fragment) in pages[target].ids,f'Missing anchor: {ref}'
for name,lang,direction in [('index.html','en','ltr'),('ar.html','ar','rtl')]:
 page=pages[SITE/name];assert page.lang==lang and page.direction==direction
 assert page.cards==[f['id'] for f in features],f'Incomplete gallery in {name}'
for ref in re.findall(r'url\([\"\']?([^\)\"\']+)',(SITE/'style.css').read_text()):
 assert (SITE/ref).exists(),f'Broken CSS asset: {ref}'
assert (SITE/'assets/social-preview.png').read_bytes().startswith(b'\x89PNG\r\n\x1a\n')
print(f'Passed: {len(pages)} pages, {len(features)} bilingual features, {len({f["image"] for f in features})} capture references, local assets and anchors.')
