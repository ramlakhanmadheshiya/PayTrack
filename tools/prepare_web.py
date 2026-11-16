"""After a Web export: set the page title, check the installable-app files
(manifest + service worker) are present, and make repeat visits fast.

The engine (index.js + index.wasm, ~7 MB to download) almost never changes between
PayTrack versions; only index.pck (the app, ~2 MB) does. Godot's service
worker throws its whole cache away on every new version, so every update
downloaded the engine again. Here:
  * the engine files are renamed engine-<hash>.* (same content = same name), and
  * the service worker keeps an already-downloaded engine-<hash> file when a
    new version is installed.
So after the first visit, an update downloads only the app.

    python3 tools/prepare_web.py [folder]      (default build/web)
"""
from pathlib import Path
import hashlib
import json
import re
import sys

root = Path(__file__).resolve().parents[1]
folder = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "build/web"

need = ["index.html", "index.js", "index.wasm", "index.pck", "index.manifest.json", "index.service.worker.js"]
missing = [n for n in need if not (folder / n).exists()]
if missing:
    raise SystemExit("missing web files: " + ", ".join(missing))

html_file = folder / "index.html"
html = html_file.read_text()
html = re.sub(r"<title>.*?</title>", "<title>PayTrack</title>", html, flags=re.S)

# --- Engine files named by their content --------------------------------------
h = hashlib.sha256()
for name in ["index.js", "index.wasm", "index.audio.worklet.js", "index.audio.position.worklet.js"]:
    if (folder / name).exists():
        h.update((folder / name).read_bytes())
engine = "engine-" + h.hexdigest()[:10]
renamed = {}
for p in sorted(folder.iterdir()):
    # index.js must always match index.wasm exactly; browsers and Cloudflare
    # keep .js for hours, so it is renamed by content too.
    if p.name.startswith("index.") and (p.name in ("index.wasm", "index.js") or p.name.endswith(".worklet.js")):
        new = engine + p.name[len("index"):]
        p.rename(folder / new)
        renamed[p.name] = new

m = re.search(r"GODOT_CONFIG = (\{.*?\});", html, flags=re.S)
if not m:
    raise SystemExit("GODOT_CONFIG not found in index.html")
cfg = json.loads(m.group(1))
cfg["executable"] = engine            # the engine loads <executable>.wasm and its worklets
cfg["mainPack"] = "index.pck"         # …and would look for <executable>.pck without this
sizes = cfg.get("fileSizes", {})
cfg["fileSizes"] = {renamed.get(k, k): v for k, v in sizes.items()}
html = html[:m.start(1)] + json.dumps(cfg, separators=(",", ":")) + html[m.end(1):]
if '<script src="index.js"></script>' not in html:
    raise SystemExit("index.js script tag not found in index.html")
html = html.replace('<script src="index.js"></script>', '<script src="' + renamed["index.js"] + '"></script>')
html_file.write_text(html)

# --- Service worker: new names, and keep the engine across versions ----------
sw_file = folder / "index.service.worker.js"
sw = sw_file.read_text()
for old, new in renamed.items():
    sw = sw.replace('"' + old + '"', '"' + new + '"')
old_activate = "caches.keys().then(\n\t\tfunction (keys) {\n\t\t\t// Remove old caches."
if old_activate not in sw:
    raise SystemExit("service worker changed in this Godot version: update tools/prepare_web.py")
sw = sw.replace(old_activate, "caches.keys().then(\n\t\tasync function (keys) {\n\t\t\tawait ptKeepEngine(keys);\n\t\t\t// Remove old caches.", 1)
sw += """

// PayTrack: before old caches are removed, keep the engine files that this
// version uses too (same engine-<hash> name = same content), so an update
// downloads only the app.
async function ptKeepEngine(keys) {
	try {
		const cache = await caches.open(CACHE_NAME);
		for (const key of keys) {
			if (!key.startsWith(CACHE_PREFIX) || key === CACHE_NAME) {
				continue;
			}
			const old = await caches.open(key);
			for (const req of await old.keys()) {
				const name = req.url.slice(req.url.lastIndexOf('/') + 1);
				if (name.startsWith('engine-') && FULL_CACHE.includes(name) && !(await cache.match(req))) {
					const res = await old.match(req);
					if (res) {
						await cache.put(req, res);
					}
				}
			}
		}
	} catch (e) {
		console.warn('PayTrack: could not keep the engine cache', e); // eslint-disable-line no-console
	}
}
"""
sw_file.write_text(sw)

print("engine:", engine, "renamed:", renamed)
print("web build ready:", sorted(p.name for p in folder.iterdir()))
