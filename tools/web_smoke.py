"""Opens the web build in a headless browser and checks PayTrack starts.

    python3 tools/web_smoke.py build/web

The app sets window.ptReady = true when its first screen is up. Fails (exit 1)
if that does not happen within 120 s, or if the engine prints a script error.
"""
import functools
import http.server
import sys
import threading

from playwright.sync_api import sync_playwright

folder = sys.argv[1] if len(sys.argv) > 1 else "build/web"
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=folder)
handler.log_message = lambda *a: None
server = http.server.ThreadingHTTPServer(("127.0.0.1", 8765), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()

errors = []
log = []
bad_requests = []
with sync_playwright() as p:
    browser = p.chromium.launch(args=["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
    page = browser.new_page(viewport={"width": 390, "height": 844})
    page.on("console", lambda m: (log.append(m.type + ": " + m.text), errors.append(m.text) if ("SCRIPT ERROR" in m.text or "Parse Error" in m.text) else None))
    page.on("response", lambda r: bad_requests.append("%d %s" % (r.status, r.url)) if r.status >= 400 else None)
    page.on("pageerror", lambda e: errors.append(str(e)))
    page.goto("http://127.0.0.1:8765/index.html")
    ok = True
    try:
        page.wait_for_function("window.ptReady === true", timeout=120000)
    except Exception as e:
        ok = False
        errors.append("app did not start: " + str(e).splitlines()[0])
    browser.close()
server.shutdown()

if errors or not ok:
    print("WEB SMOKE TEST FAILED")
    for e in errors[:20]:
        print("  ", e)
    for b in bad_requests[:20]:
        print("   request failed:", b)
    print("   last browser messages:")
    for line in log[-25:]:
        print("     ", line[:300])
    sys.exit(1)
print("web smoke test: app started")
