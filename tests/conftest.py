"""Shared fixtures for server tests."""

import io
import os
import sys
import threading
import tempfile

import pytest
from PIL import Image

# Add server directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "server"))


@pytest.fixture
def source_image(tmp_path):
    """Create a temporary 758x1024 8-bit grayscale PNG."""
    img = Image.new("L", (758, 1024), 128)
    path = tmp_path / "source.png"
    img.save(str(path), format="PNG")
    return str(path)


@pytest.fixture
def test_server(source_image):
    """Start the image server in a background thread."""
    import server as srv

    srv.IMAGE_PATH = source_image

    httpd = srv.HTTPServer(("127.0.0.1", 0), srv.ImageHandler)
    port = httpd.server_address[1]

    thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    thread.start()

    yield f"http://127.0.0.1:{port}"

    httpd.shutdown()


@pytest.fixture
def missing_image_server(tmp_path):
    """Start the server pointing to a non-existent image."""
    import server as srv

    srv.IMAGE_PATH = str(tmp_path / "nonexistent.png")

    httpd = srv.HTTPServer(("127.0.0.1", 0), srv.ImageHandler)
    port = httpd.server_address[1]

    thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    thread.start()

    yield f"http://127.0.0.1:{port}"

    httpd.shutdown()
