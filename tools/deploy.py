"""Publish build/web to theramlakhan.com/paytrack (folder public/paytrack of the
portfolio repo). Only that folder is ever changed. Run after a Web export:
    python3 tools/prepare_web.py && python3 tools/deploy.py
"""
from pathlib import Path
import shutil, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
SITE = "ramlakhanmadheshiya/ramlakhanmadheshiya.github.io"
DEST = "public/paytrack"
WORK = ROOT / ".tools" / "portfolio"


def run(*args, cwd=ROOT):
    return subprocess.check_output(args, cwd=cwd, text=True).strip()


src = ROOT / "build" / "web"
if not (src / "index.html").is_file() or not list(src.glob("paytrack-*.pck")):
    sys.exit("Export Web and run tools/prepare_web.py first.")
if not WORK.exists():
    run("gh", "repo", "clone", SITE, str(WORK), "--", "--depth", "1")
if run("git", "status", "--porcelain", cwd=WORK):
    sys.exit(f"{WORK} has local changes; review them first.")
run("git", "pull", "--ff-only", cwd=WORK)
target = WORK / DEST
# Keep the two newest older packs for browsers that still have the old page cached.
keep = []
if target.exists():
    olds = sorted(target.glob("paytrack-*.pck"), key=lambda p: p.stat().st_mtime, reverse=True)[:2]
    keep = [(p.name, p.read_bytes()) for p in olds]
    shutil.rmtree(target)
target.mkdir(parents=True)
for p in src.iterdir():
    if p.is_file() and p.suffix in (".html", ".js", ".wasm", ".pck", ".png", ".svg") and p.name != "index.pck":
        shutil.copy2(p, target / p.name)
for name, data in keep:
    if not (target / name).exists():
        (target / name).write_bytes(data)
run("git", "add", "-A", "--", DEST, cwd=WORK)
changed = run("git", "diff", "--cached", "--name-only", cwd=WORK).splitlines()
if not changed:
    sys.exit("Nothing changed.")
if any(not c.startswith(DEST + "/") for c in changed):
    sys.exit("Refusing: changes outside " + DEST)
print("\n".join(changed))
run("git", "commit", "-m", "Publish PayTrack web app", cwd=WORK)
run("git", "push", "origin", "HEAD:main", cwd=WORK)
print("Published. The site updates after the portfolio's Pages workflow finishes: https://theramlakhan.com/paytrack/")
