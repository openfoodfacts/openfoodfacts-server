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
