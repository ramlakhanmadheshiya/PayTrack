"""Publish build/web to theramlakhan.com/paytrack (folder public/paytrack of the
portfolio repo) and the download page theramlakhan.com/testsapp (public/testsapp).
Only those two folders are ever changed. With PUBLISH_APK=1 the Android APK in
build/android/paytrack.apk is also put on the download page.
CI runs this after every build (PORTFOLIO_DIR = a checkout made with the deploy key).
By hand:  python3 tools/prepare_web.py && python3 tools/deploy.py
"""
from pathlib import Path
import datetime, json, os, shutil, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
SITE = "ramlakhanmadheshiya/ramlakhanmadheshiya.github.io"
DEST = "public/paytrack"
APPS = "public/testsapp"
WORK = Path(os.environ.get("PORTFOLIO_DIR", ROOT / ".tools" / "portfolio"))
VERSION = os.environ.get("PAYTRACK_VERSION", "local")


def run(*args, cwd=ROOT):
    return subprocess.check_output(args, cwd=cwd, text=True).strip()


src = ROOT / "build" / "web"
if not (src / "index.html").is_file():
    sys.exit("Export Web and run tools/prepare_web.py first.")
if not WORK.exists():
    run("gh", "repo", "clone", SITE, str(WORK), "--", "--depth", "1")
if run("git", "status", "--porcelain", cwd=WORK):
    sys.exit(f"{WORK} has local changes; review them first.")
run("git", "pull", "--ff-only", cwd=WORK)
target = WORK / DEST
if target.exists():
    shutil.rmtree(target)
target.mkdir(parents=True)
for p in src.iterdir():
    if p.is_file() and not p.name.endswith(".import"):
        shutil.copy2(p, target / p.name)
# Download page.
apps = WORK / APPS
(apps / "paytrack").mkdir(parents=True, exist_ok=True)
shutil.copy2(ROOT / "web/testsapp/index.html", apps / "index.html")
shutil.copy2(ROOT / "assets/web/icon-180.png", apps / "paytrack/icon.png")
apk = ROOT / "build/android/paytrack.apk"
if os.environ.get("PUBLISH_APK") == "1":
    if not apk.is_file():
        sys.exit("PUBLISH_APK=1 but no APK at " + str(apk))
    shutil.copy2(apk, apps / "paytrack/PayTrack.apk")
    (apps / "paytrack/version.json").write_text(json.dumps({
        "version": VERSION,
        "size_mb": round(apk.stat().st_size / 1e6, 1),
        "date": datetime.date.today().strftime("%-d %b %Y"),
    }))
    print("APK published:", VERSION)
run("git", "add", "-A", "--", DEST, APPS, cwd=WORK)
changed = run("git", "diff", "--cached", "--name-only", cwd=WORK).splitlines()
if not changed:
    print("Nothing changed.")
    sys.exit(0)
if any(not (c.startswith(DEST + "/") or c.startswith(APPS + "/")) for c in changed):
    sys.exit("Refusing: changes outside " + DEST + " and " + APPS)
print("\n".join(changed))
run("git", "commit", "-m", f"Publish PayTrack web app {VERSION}", cwd=WORK)
run("git", "push", "origin", "HEAD:main", cwd=WORK)
print("Published. Live after the portfolio's Pages workflow: https://theramlakhan.com/paytrack/")
