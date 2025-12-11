import os
import pandas as pd
from common import convert

# Go up one level from tests/common/ to tests/, then into test_files/
TEST_EXCEL_FILE = os.path.join(os.path.dirname(__file__), "..", "test_files", "test_excel.xlsx")

def test_convert_excel_to_csv():
    country_name = "Testland"
    csv_file = "test_output.csv"

    original_data = [
        ["ID", "Approval Code", "Name", "Street", "City"],
        ["1", "HR 123 EU", "Test Name", "Test Street", "Test City"],
        ["2", "HR 456 EU", "Another Name", "Another Street", "Another City"]
    ]
    df_original = pd.DataFrame(original_data)

    try:
        convert.convert_excel_to_csv(country_name, TEST_EXCEL_FILE, csv_file)

        assert os.path.exists(csv_file)

        df_csv = pd.read_csv(csv_file, header=None)
        pd.testing.assert_frame_equal(df_csv, df_original)

    finally:
        if os.path.exists(csv_file):
            os.remove(csv_file)


def test_merge_csv_files(tmp_path):
    """Test merging multiple CSV files with deduplication and sorting"""
    country_name = "Testland"
    
    # Create test CSV files
    csv1 = tmp_path / "test1.csv"
    csv2 = tmp_path / "test2.csv"
    csv3 = tmp_path / "test3.csv"
    output = tmp_path / "merged.csv"
    
    # Write test data with duplicates and unsorted codes
    csv1.write_text("code;name;city\nZZ-003;Name3;City3\nAA-001;Name1;City1\n", encoding='utf-8')
    csv2.write_text("code;name;city\nMM-002;Name2;City2\n", encoding='utf-8')
    csv3.write_text("code;name;city\nAA-001;Name1;City1\n", encoding='utf-8')  # Duplicate
    
    # Merge files
    convert.merge_csv_files(country_name, [str(csv1), str(csv2), str(csv3)], str(output), skip_headers=True)
    
    # Read and verify
    assert output.exists()
    content = output.read_text(encoding='utf-8')
    lines = content.strip().split('\n')
    
    # Should have header + 3 unique rows (duplicate removed)
    assert len(lines) == 4
    assert lines[0] == "code;name;city"
    
    # Verify sorted order (case-insensitive alphabetical by code)
    codes = [line.split(';')[0] for line in lines[1:]]
    assert codes == ["AA-001", "MM-002", "ZZ-003"]
