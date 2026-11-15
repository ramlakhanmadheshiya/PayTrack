"""Serve build/web locally: python3 tools/serve.py  → http://127.0.0.1:8766/"""
import functools, http.server, pathlib
root = pathlib.Path(__file__).resolve().parents[1] / "build" / "web"
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(root))
print("http://127.0.0.1:8766/")
http.server.ThreadingHTTPServer(("127.0.0.1", 8766), handler).serve_forever()
