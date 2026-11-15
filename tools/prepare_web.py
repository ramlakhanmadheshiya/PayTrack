"""After a Web export: give the app pack a content-based name so browsers load
updates instead of a cached old copy, and set the page title."""
from pathlib import Path
import hashlib, json, re, shutil

root = Path(__file__).resolve().parents[1]
folder = root / "build/web"
pack = folder / "index.pck"
html_file = folder / "index.html"
build = hashlib.sha256(pack.read_bytes()).hexdigest()[:12]
name = f"paytrack-{build}.pck"
shutil.copy2(pack, folder / name)
html = html_file.read_text()
m = re.search(r"const GODOT_CONFIG = (\{[^\n]+\});", html)
if not m:
    raise SystemExit("Godot web config not found")
config = json.loads(m.group(1))
old = config.get("mainPack", "index.pck")
config["mainPack"] = name
size = config["fileSizes"].pop(old, pack.stat().st_size)
config["fileSizes"][name] = size
html = html[: m.start(1)] + json.dumps(config, separators=(",", ":")) + html[m.end(1):]
html = re.sub(r"<title>.*?</title>", "<title>PayTrack</title>", html, flags=re.S)
html_file.write_text(html)
for p in folder.glob("paytrack-*.pck"):
    if p.name != name:
        p.unlink()
print("web build", build)
