"""Fetch only matching Web templates using HTTP byte ranges from official release ZIP."""
import io, urllib.request, zipfile, pathlib
URL = 'https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
class Remote(io.RawIOBase):
    def __init__(self):
        req = urllib.request.Request(URL, method='HEAD')
        with urllib.request.urlopen(req) as response:
            self.url = response.url
            self.length = int(response.headers['Content-Length'])
        self.pos = 0
    def seekable(self): return True
    def tell(self): return self.pos
    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else self.pos + offset if whence == 1 else self.length + offset
        return self.pos
    def read(self, size=-1):
        if size < 0: size = self.length - self.pos
        if size == 0: return b''
        req = urllib.request.Request(self.url, headers={'Range': f'bytes={self.pos}-{self.pos+size-1}'})
        with urllib.request.urlopen(req) as response:
            if response.status != 206: raise RuntimeError('Server did not honor byte range')
            result = response.read()
        self.pos += len(result)
        return result
root = pathlib.Path('.tools/templates')
root.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(Remote()) as archive:
    for item in archive.infolist():
        if pathlib.PurePosixPath(item.filename).name in ['web_nothreads_release.zip', 'web_nothreads_debug.zip']:
            print('Downloading', item.filename, item.compress_size, flush=True)
            (root / pathlib.PurePosixPath(item.filename).name).write_bytes(archive.read(item))
print('Web templates ready')
