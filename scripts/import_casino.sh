#!/bin/sh

./import_csv_file.pl --csv_file casino.csv --user_id casino --comment "Test Casino" --source_id "casino" --source_name "Casino" --source_url "https://www.casino.fr" --define lc=fr --define countries="France"
