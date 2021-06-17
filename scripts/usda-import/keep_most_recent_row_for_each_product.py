import pandas as pd
import sys

if  (len(sys.argv) != 2):
    sys.stderr.write("Usage: python keep_most_recent_row_for_ech_product.pl [input CSV file] > [output CSV file]\n")
    sys.exit()

input_csv_file = sys.argv[1]

sys.stderr.write("Reading CSV file " + input_csv_file + "\n")

# Make sure numbers are kept as strings and not converted
df = pd.read_csv(input_csv_file, sep='\t', dtype=str)

# This assumes that the input file is sorted by date
# In practice, it is sorted by fdc_id, which seems to be a sequence ordered by date
df.drop_duplicates(subset=['code'], keep='last', inplace=True)

df.to_csv(sys.stdout, sep='\t', quoting=None, index=False)