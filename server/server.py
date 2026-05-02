"""Minimal image server for kndl-online-screensaver.

Serves a PNG image, optionally resized to match the requesting
device's screen resolution via ?w=WIDTH&h=HEIGHT query parameters.

Usage:
    IMAGE_PATH=/path/to/image.png python server.py
    python server.py  # defaults to testimage.png in the same directory
"""

import hashlib
import io
import os
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

from PIL import Image

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
IMAGE_PATH = os.environ.get("IMAGE_PATH", os.path.join(SCRIPT_DIR, "testimage.png"))
PORT = int(os.environ.get("PORT", "5000"))


class ImageHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path != "/":
            self.send_error(404)
            return

        if not os.path.isfile(IMAGE_PATH):
            self.send_error(503, "Source image not found")
            return

        params = parse_qs(parsed.query)
        w_param = params.get("w")
        h_param = params.get("h")

        # ETag derived from file identity + resize params so we can
        # short-circuit before any image processing.
        stat = os.stat(IMAGE_PATH)
        etag_src = f"{stat.st_mtime}:{stat.st_size}:{w_param}:{h_param}"
        etag = hashlib.md5(etag_src.encode()).hexdigest()

        if self.headers.get("If-None-Match") == etag:
            self.send_response(304)
            self.end_headers()
            return

        try:
            img = Image.open(IMAGE_PATH)
        except Exception:
            self.send_error(500, "Failed to open source image")
            return

        if w_param and h_param:
            try:
                w = int(w_param[0])
                h = int(h_param[0])
            except (ValueError, IndexError):
                self.send_error(400, "Invalid w/h parameters")
                return

            if w <= 0 or h <= 0 or w > 4096 or h > 4096:
                self.send_error(400, "w/h out of range (1-4096)")
                return

            img = _resize_and_convert(img, w, h)

        elif img.mode != "L":
            img = img.convert("L")

        buf = io.BytesIO()
        img.save(buf, format="PNG")
        data = buf.getvalue()

        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("ETag", etag)
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format, *args):
        sys.stderr.write("%s - - %s\n" % (self.address_string(), format % args))


def _resize_and_convert(img, w, h):
    """Resize image to w x h, maintaining aspect ratio with white padding."""
    img = img.convert("L")

    img_ratio = img.width / img.height
    target_ratio = w / h

    if img_ratio > target_ratio:
        new_w = w
        new_h = round(w / img_ratio)
    else:
        new_h = h
        new_w = round(h * img_ratio)

    img = img.resize((new_w, new_h), Image.LANCZOS)

    canvas = Image.new("L", (w, h), 255)
    offset_x = (w - new_w) // 2
    offset_y = (h - new_h) // 2
    canvas.paste(img, (offset_x, offset_y))

    return canvas


def main():
    print(f"Serving {IMAGE_PATH} on port {PORT}")
    server = HTTPServer(("", PORT), ImageHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    server.server_close()


if __name__ == "__main__":
    main()
