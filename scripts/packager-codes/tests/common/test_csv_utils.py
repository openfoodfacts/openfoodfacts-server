import pytest
from unittest.mock import MagicMock
from common import config
from common.csv_utils import normalize_text, get_data_rows


# tests for normalize_text function

def test_normalize_text_full(monkeypatch):
    monkeypatch.setattr(
        config,
        "load_text_replacements",
        lambda country: {
            r"\bsv\.": "sveti",
            r"Dugoplje": "Dugopolje",
            r"\s*\([^)]*\)": ""
        }
    )
    text = "sv. Ante Dugoplje (test) kod something"
    expected = "sveti Ante Dugopolje"
    assert normalize_text(text, "hr") == expected


def test_normalize_text_empty_string():
    assert normalize_text("", "hr") == ""


def test_normalize_text_none():
    assert normalize_text(None, "hr") is None


def test_normalize_text_caching(monkeypatch):
    # Reimport csv_utils to patch the load_text_replacements function
    # actually used by normalize_text. Otherwise, normalize_text keeps
    # the local reference imported earlier and the mock won't be called.
    from common import csv_utils
    
    mock_loader = MagicMock(return_value={"sv\\.": "sveti"})
    monkeypatch.setattr(csv_utils, "load_text_replacements", mock_loader)

    # Clear previous cache
    cache_key = "_replacements_hr"
    if hasattr(csv_utils.normalize_text, cache_key):
        delattr(csv_utils.normalize_text, cache_key)

    csv_utils.normalize_text("sv. Ivan", "hr")
    csv_utils.normalize_text("sv. Marko", "hr")

    assert mock_loader.call_count == 1



# tests for get_data_rows function

def test_get_data_rows_no_keywords():
    rows = [["A", "B"], ["1", "2"]]
    assert get_data_rows(rows) == (rows, 2)


def test_get_data_rows_header_found():
    rows = [
        ["ID", "Broj odobrenja", "Naziv"],
        ["1", "HR 123", "X"]
    ]
    assert get_data_rows(rows, ["broj", "naziv"]) == (
        [["1", "HR 123", "X"]],
        3
    )


def test_get_data_rows_header_not_found():
    rows = [["A", "B"], ["1", "2"]]
    with pytest.raises(ValueError):
        get_data_rows(rows, ["missing"])
