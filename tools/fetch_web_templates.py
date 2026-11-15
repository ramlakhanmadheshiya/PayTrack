"""Fetch only the Web export templates from the official Godot release, using
HTTP byte ranges (the full template archive is ~1 GB). Saved to .tools/templates/."""
import io, pathlib, time, urllib.request, zipfile

VERSION = "4.7.2-stable"
URL = f"https://github.com/godotengine/godot/releases/download/{VERSION}/Godot_v{VERSION}_export_templates.tpz"
WANT = ["web_nothreads_release.zip", "web_nothreads_debug.zip"]
CHUNK = 1 << 20


def get(url, headers=None):
    for attempt in range(6):
        try:
            req = urllib.request.Request(url, headers=headers or {})
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.status, dict(r.headers), r.read(), r.url
        except Exception as e:  # network hiccup: retry
            print("retry", attempt + 1, e, flush=True)
            time.sleep(2 * (attempt + 1))
    raise SystemExit("download failed")


class Remote(io.RawIOBase):
    def __init__(self):
        req = urllib.request.Request(URL, method="HEAD")
        with urllib.request.urlopen(req, timeout=30) as r:
            self.url, self.length = r.url, int(r.headers["Content-Length"])
        self.pos = 0

    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos

    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else self.pos + offset if whence == 1 else self.length + offset
        return self.pos

    def readinto(self, b):
        data = self.read(len(b))
        b[:len(data)] = data
        return len(data)

    def read(self, size=-1):
        if size < 0: size = self.length - self.pos
        size = max(0, min(size, self.length - self.pos))
        out = bytearray()
        while size > 0:
            n = min(size, CHUNK)
            status, _, data, _ = get(self.url, {"Range": f"bytes={self.pos}-{self.pos + n - 1}"})
            if status != 206: raise SystemExit("server ignored byte range")
            out += data
            self.pos += len(data)
            size -= len(data)
            if not data: break
        return bytes(out)


root = pathlib.Path(".tools/templates")
root.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(io.BufferedReader(Remote(), buffer_size=CHUNK)) as z:
    for item in z.infolist():
        name = pathlib.PurePosixPath(item.filename).name
        if name in WANT and not (root / name).exists():
            print("downloading", name, item.compress_size, flush=True)
            (root / name).write_bytes(z.read(item))
print("Web templates ready in", root)
