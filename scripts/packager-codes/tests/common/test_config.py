from common import config
import json
import os
import tempfile
import pytest

try:
    from jsonschema import validate, ValidationError
    HAS_JSONSCHEMA = True
except ImportError:
    HAS_JSONSCHEMA = False

CONFIG_TEST_FILE = os.path.join(os.path.dirname(__file__), '../test_files/packager_sources_config_test.json')
TEXT_REPLACEMENTS_TEST_FILE = os.path.join(os.path.dirname(__file__), '../test_files/packager_text_replacements_test.json')
ACTUAL_CONFIG_FILE = 'packager_sources_config.json'
CONFIG_SCHEMA_FILE = os.path.join(os.path.dirname(__file__), '../packager_sources_config_schema.json')

def test_load_config(monkeypatch):
    monkeypatch.setattr(config, "CONFIG_FILE", CONFIG_TEST_FILE)
    cfg = config.load_config()
    assert "hr" in cfg
    assert cfg["hr"]["country_name"] == "Croatia"


def test_save_config():
    with tempfile.NamedTemporaryFile(mode='w+', delete=False, suffix=".json", encoding='utf-8') as temp_file:
        test_data = {
            "hr": {
                "country_name": "Croatia",
                "sources": [],
                "last_filename": "03-11-2025. svi odobreni objekti.xls"
            }
        }
        json.dump(test_data, temp_file)
        temp_file.flush()
        temp_file_path = temp_file.name

    try:
        config.CONFIG_FILE = temp_file_path

        cfg = config.load_config()
        cfg["hr"]["last_filename"] = "NEW-FILE.xls"
        config.save_config(cfg)

        with open(temp_file_path, 'r', encoding='utf-8') as f:
            loaded = json.load(f)
        assert loaded["hr"]["last_filename"] == "NEW-FILE.xls"
    
    finally:
        os.remove(temp_file_path)


def test_load_text_replacements(monkeypatch):
    monkeypatch.setattr(config, "TEXT_REPLACEMENTS_FILE", TEXT_REPLACEMENTS_TEST_FILE)

    expected = {
        r'\bsv\.\s*': "sveti",
        r'\bn/m\s*': "na moru",
        r'\bDugoplje\b': "Dugopolje",
        r'\bBelejske\b': "Belajske",
        r'\s*\([^)]*\)': "",
        r'\s+kod\s+.*': ""
    }

    replacements = config.load_text_replacements("hr")
    assert replacements == expected


@pytest.mark.skipif(not HAS_JSONSCHEMA, reason="jsonschema package not installed")
def test_validate_config_with_schema():
    """Validate config against JSON Schema."""
    if not os.path.exists(ACTUAL_CONFIG_FILE):
        pytest.skip(f"Config file {ACTUAL_CONFIG_FILE} not found")
    
    if not os.path.exists(CONFIG_SCHEMA_FILE):
        pytest.skip(f"Schema file {CONFIG_SCHEMA_FILE} not found")
    
    with open(CONFIG_SCHEMA_FILE, 'r', encoding='utf-8') as f:
        schema = json.load(f)
    
    with open(ACTUAL_CONFIG_FILE, 'r', encoding='utf-8') as f:
        cfg = json.load(f)
    
    try:
        validate(instance=cfg, schema=schema)
    except ValidationError as e:
        pytest.fail(f"Config validation failed: {e.message}\nPath: {list(e.path)}")


def test_validate_config_json_syntax():
    """Ensure the actual config file is valid JSON."""
    if not os.path.exists(ACTUAL_CONFIG_FILE):
        pytest.skip(f"Config file {ACTUAL_CONFIG_FILE} not found")
    
    try:
        with open(ACTUAL_CONFIG_FILE, 'r', encoding='utf-8') as f:
            json.load(f)
    except json.JSONDecodeError as e:
        pytest.fail(f"Invalid JSON in {ACTUAL_CONFIG_FILE}: {e}")
