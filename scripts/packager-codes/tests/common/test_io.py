from common import io
import pytest

# test for generate_file_identifier function

@pytest.mark.parametrize(
    "keyword, last_filename, expected",
    [
        ("svi odobreni objekti", None, "svi_odobreni_objekti"),
        ("keyword/with\\chars", None, "keyword_with_chars"),
        (None, "03-11-2025. svi odobreni objekti.xls", "03_11_2025__svi_odobreni_objek"),
        (None, None, "unknown"),
    ]
)
def test_generate_file_identifier(keyword, last_filename, expected):
    assert io.generate_file_identifier(keyword, last_filename) == expected

# test for write_csv function

def test_write_csv(tmp_path):
    output_file = tmp_path / "output.csv"
    rows = [["col1", "col2"], ["val1", "val2"]]

    # Should write CSV without errors
    io.write_csv("Testland", str(output_file), rows)

    # Check that file exists and content is correct
    assert output_file.exists()
    content = output_file.read_text(encoding="utf-8")
    assert content == "col1;col2\nval1;val2\n"


def test_write_csv_exception(monkeypatch, tmp_path):
    # Patch open to raise exception
    def mock_open(*args, **kwargs):
        raise IOError("Cannot open file")

    monkeypatch.setattr("builtins.open", mock_open)

    with pytest.raises(RuntimeError, match="Failed to write output file"):
        io.write_csv("Testland", str(tmp_path / "output.csv"), [["a", "b"]])

# test for move_output_to_packager_codes function

def test_move_output_to_packager_codes(tmp_path, monkeypatch):
    # Create fake file
    target_file = tmp_path / "file.csv"
    target_file.write_text("data", encoding="utf-8")

    packager_dir = tmp_path / "packager-codes"
    monkeypatch.setattr(io, "PACKAGER_CODES_DIR", packager_dir)

    io.move_output_to_packager_codes("Testland", "tl", str(target_file))

    final_file = packager_dir / "TL-merge-UTF-8.csv"
    assert final_file.exists()
    assert not target_file.exists()
    assert final_file.read_text() == "data"


def test_move_output_file_missing(tmp_path, monkeypatch):
    missing_file = tmp_path / "missing.csv"
    monkeypatch.setattr(io, "PACKAGER_CODES_DIR", str(tmp_path / "packager-codes"))

    with pytest.raises(FileNotFoundError, match="Output file .* not found"):
        io.move_output_to_packager_codes("Testland", "tl", str(missing_file))

# test for cleanup_temp_files function

def test_cleanup_temp_files(tmp_path):
    temp_file1 = tmp_path / "tmp1.txt"
    temp_file2 = tmp_path / "tmp2.txt"
    temp_file1.write_text("1")
    temp_file2.write_text("2")

    io.cleanup_temp_files("Testland", [str(temp_file1), str(temp_file2)])

    assert not temp_file1.exists()
    assert not temp_file2.exists()


def test_cleanup_temp_files_missing(tmp_path):
    # Should not raise error even if file does not exist
    missing_file = tmp_path / "missing.txt"
    io.cleanup_temp_files("Testland", [str(missing_file)])
    assert not missing_file.exists()
