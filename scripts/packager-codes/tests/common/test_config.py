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

ACTUAL_CONFIG_FILE = os.path.join(os.path.dirname(__file__), '../../packager_sources_config.json')
CONFIG_SCHEMA_FILE = os.path.join(os.path.dirname(__file__), '../../tests/packager_sources_config_schema.json')


def test_save_config():
    with tempfile.NamedTemporaryFile(mode='w+', delete=False, suffix=".json", encoding='utf-8') as temp_file:
        test_data = {
            "hr": {
                "country_name": "Croatia",
                "sources": [
                    {
                        "url": "http://example.com/hr",
                        "files": [
                            {
                                "type": "excel",
                                "keyword": "test",
                                "last_filename": "03-11-2025. svi odobreni objekti.xls"
                            }
                        ]
                    }
                ]
            }
        }
        json.dump(test_data, temp_file)
        temp_file.flush()
        temp_file_path = temp_file.name

    try:
        config.CONFIG_FILE = temp_file_path

        cfg = config.load_config()
        cfg["hr"]["sources"][0]["files"][0]["last_filename"] = "NEW-FILE.xls"
        config.save_config(cfg)

        with open(temp_file_path, 'r', encoding='utf-8') as f:
            loaded = json.load(f)
        assert loaded["hr"]["sources"][0]["files"][0]["last_filename"] == "NEW-FILE.xls"
    
    finally:
        os.remove(temp_file_path)


def test_load_text_replacements(monkeypatch, tmp_path):
    """Test that load_text_replacements correctly builds regex patterns from config."""
    test_config = {
        "test": {
            "abbreviations": {"sv.": "sveti "},
            "typos": {"Dugoplje": "Dugopolje"},
            "cleanup_patterns": {"remove_parens": r"\s*\([^)]*\)"}
        }
    }
    
    test_file = tmp_path / "test_replacements.json"
    test_file.write_text(json.dumps(test_config))
    monkeypatch.setattr(config, "TEXT_REPLACEMENTS_FILE", str(test_file))

    result = config.load_text_replacements("test")
    
    assert result == {
        r'\bsv\.\s*': "sveti ",
        r'\bDugoplje\b': "Dugopolje",
        r'\s*\([^)]*\)': ""
    }


@pytest.mark.skipif(not HAS_JSONSCHEMA, reason="jsonschema package not installed")
def test_validate_config_with_schema():
    """Validate production config against JSON Schema."""
    with open(CONFIG_SCHEMA_FILE, 'r', encoding='utf-8') as f:
        schema = json.load(f)
    
    with open(ACTUAL_CONFIG_FILE, 'r', encoding='utf-8') as f:
        cfg = json.load(f)
    
    try:
        validate(instance=cfg, schema=schema)
    except ValidationError as e:
        pytest.fail(f"Config validation failed: {e.message}\nPath: {list(e.path)}")


