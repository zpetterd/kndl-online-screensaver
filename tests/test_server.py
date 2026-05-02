"""Tests for the kndl-online-screensaver image server."""

import io
from urllib.request import urlopen, Request
from urllib.error import HTTPError

from PIL import Image
import pytest


def test_get_root_returns_png(test_server):
    resp = urlopen(f"{test_server}/")
    assert resp.status == 200
    assert resp.headers["Content-Type"] == "image/png"

    img = Image.open(io.BytesIO(resp.read()))
    assert img.format == "PNG"


def test_get_root_returns_grayscale(test_server):
    resp = urlopen(f"{test_server}/")
    img = Image.open(io.BytesIO(resp.read()))
    assert img.mode == "L"


def test_get_root_returns_original_size(test_server):
    resp = urlopen(f"{test_server}/")
    img = Image.open(io.BytesIO(resp.read()))
    assert img.size == (758, 1024)


def test_resize_to_600x800(test_server):
    resp = urlopen(f"{test_server}/?w=600&h=800")
    img = Image.open(io.BytesIO(resp.read()))
    assert img.size == (600, 800)
    assert img.mode == "L"


def test_resize_to_1072x1448(test_server):
    resp = urlopen(f"{test_server}/?w=1072&h=1448")
    img = Image.open(io.BytesIO(resp.read()))
    assert img.size == (1072, 1448)
    assert img.mode == "L"


def test_resize_to_1264x1680(test_server):
    resp = urlopen(f"{test_server}/?w=1264&h=1680")
    img = Image.open(io.BytesIO(resp.read()))
    assert img.size == (1264, 1680)
    assert img.mode == "L"


def test_missing_source_returns_503(missing_image_server):
    with pytest.raises(HTTPError) as exc_info:
        urlopen(f"{missing_image_server}/")
    assert exc_info.value.code == 503


def test_invalid_path_returns_404(test_server):
    with pytest.raises(HTTPError) as exc_info:
        urlopen(f"{test_server}/nonexistent")
    assert exc_info.value.code == 404


def test_invalid_w_param_returns_400(test_server):
    with pytest.raises(HTTPError) as exc_info:
        urlopen(f"{test_server}/?w=abc&h=800")
    assert exc_info.value.code == 400


def test_negative_dimensions_returns_400(test_server):
    with pytest.raises(HTTPError) as exc_info:
        urlopen(f"{test_server}/?w=-1&h=800")
    assert exc_info.value.code == 400


def test_oversized_dimensions_returns_400(test_server):
    with pytest.raises(HTTPError) as exc_info:
        urlopen(f"{test_server}/?w=5000&h=5000")
    assert exc_info.value.code == 400


def test_response_includes_etag(test_server):
    resp = urlopen(f"{test_server}/")
    etag = resp.headers["ETag"]
    assert etag is not None
    assert len(etag) > 0


def test_matching_etag_returns_304(test_server):
    resp = urlopen(f"{test_server}/")
    etag = resp.headers["ETag"]

    req = Request(f"{test_server}/", headers={"If-None-Match": etag})
    with pytest.raises(HTTPError) as exc_info:
        urlopen(req)
    assert exc_info.value.code == 304


def test_mismatched_etag_returns_200(test_server):
    req = Request(f"{test_server}/", headers={"If-None-Match": "bogus"})
    resp = urlopen(req)
    assert resp.status == 200


def test_different_resize_params_produce_different_etags(test_server):
    resp1 = urlopen(f"{test_server}/")
    resp2 = urlopen(f"{test_server}/?w=600&h=800")
    assert resp1.headers["ETag"] != resp2.headers["ETag"]
