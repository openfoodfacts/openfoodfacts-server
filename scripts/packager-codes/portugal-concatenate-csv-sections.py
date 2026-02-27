# This program allows you to create a new file with all merged csv.
# If there is a preexisting file it will append to it (rewritting the column labels once)
import os
import csv
print("Program starting")
# Lines with 3 ### might need adaptation to your need
# PATH of the csv where you will agregate everything
MAIN_CSV = 'Portugal_concatenated-UTF.csv'
folder_path = 'sources'  # SET to your folder with all csv

# Just check if we are creating the file or not
is_header = os.path.isfile(MAIN_CSV)

# 'a' to append and not overwrite
main_csv_file = open(MAIN_CSV, 'a', newline='', encoding="UTF-8")
# DELIMITER to choose wisely
main_csv_writer = csv.writer(main_csv_file, delimiter=';', quotechar='|')
j = 0
for file in os.listdir(folder_path):  # loop over all files
    if not file.startswith('.'):  # avoid any hidden file, useful on mac
        print('handling file '+str(j)+' : '+file)
        # Adapt encoding to your country source encoding
        with open(folder_path+'/'+file, newline='', encoding="windows-1252") as csvfile:
            csvreader = csv.reader(csvfile, delimiter=';', quotechar='|')
            i = 0
            if not is_header:  # add column labels if the file doesn't preexist
                is_header = True
                header = next(csvreader)
                main_csv_writer.writerow(header)
                i += 1  # consequence of using next() which moves row 1 position forward
            for row in csvreader:
                # print ('row = ', i)
                # print (row)
                if i != 0:  # to avoid the first line with all column labels on every file
                    # removes the \"= and \" from the first column ID (needed in Portugal csv file)
                    row[0] = row[0][2:][:-2]
                    main_csv_writer.writerow(row)
                i += 1
            print(str(i)+' rows have been loaded')
        j += 1
main_csv_file.close()
print("")
print("Process complete, results in : "+MAIN_CSV)
