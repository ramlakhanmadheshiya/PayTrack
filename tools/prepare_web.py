"""Give the app pack a content-based name so an existing browser loads UI updates."""
from pathlib import Path
import hashlib,json,re,shutil
root=Path(__file__).resolve().parents[1]
folder=root/'build/web'
pack=folder/'index.pck'
html_file=folder/'index.html'
build=hashlib.sha256(pack.read_bytes()).hexdigest()[:12]
name=f'paytrack-{build}.pck'
shutil.copy2(pack,folder/name)
html=html_file.read_text()
match=re.search(r'const GODOT_CONFIG = (\{[^\n]+\});',html)
if not match: raise SystemExit('Godot Web configuration not found; cannot version app pack safely.')
config=json.loads(match.group(1))
old=config.get('mainPack','index.pck')
config['mainPack']=name
size=config['fileSizes'].pop(old,pack.stat().st_size)
config['fileSizes'][name]=size
html=html[:match.start(1)]+json.dumps(config,separators=(',',':'))+html[match.end(1):]
html=re.sub(r'<meta name="paytrack-build" content="[^"]+">','',html)
html=html.replace('</head>',f'<meta name="paytrack-build" content="{build}"></head>')
html_file.write_text(html)
# The build directory keeps one current pack; deploy retains two earlier packs for cached HTML.
for old_pack in folder.glob('paytrack-*.pck'):
    if old_pack.name != name: old_pack.unlink()
print('Web build:',build)
