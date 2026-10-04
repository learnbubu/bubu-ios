"""Serves the sound lab locally (lab_dist/) and accepts rendered sounds: POST /save/<name>.wav
writes the body to render/<name>.wav. Local only (127.0.0.1)."""
import os
import re
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "render")
os.makedirs(OUT, exist_ok=True)


class H(SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=os.path.join(HERE, "lab_dist"), **k)

    def do_POST(self):
        m = re.fullmatch(r"/save/([a-z]+)\.wav", self.path)
        if not m:
            self.send_error(404)
            return
        n = int(self.headers.get("Content-Length", 0))
        if n <= 0 or n > 20_000_000:
            self.send_error(400)
            return
        with open(os.path.join(OUT, m.group(1) + ".wav"), "wb") as f:
            f.write(self.rfile.read(n))
        self.send_response(204)
        self.end_headers()


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 8765), H).serve_forever()
