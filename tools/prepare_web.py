"""After a Web export: set the page title and check the installable-app files
(manifest + service worker) are present. The service worker caches the app so it
opens without internet, and picks up each new build automatically."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
folder = root / "build/web"
html_file = folder / "index.html"
html = html_file.read_text()
html = re.sub(r"<title>.*?</title>", "<title>PayTrack</title>", html, flags=re.S)
html_file.write_text(html)
need = ["index.html", "index.js", "index.wasm", "index.pck", "index.manifest.json", "index.service.worker.js"]
missing = [n for n in need if not (folder / n).exists()]
if missing:
    raise SystemExit("missing web files: " + ", ".join(missing))
print("web build ready:", sorted(p.name for p in folder.iterdir()))
