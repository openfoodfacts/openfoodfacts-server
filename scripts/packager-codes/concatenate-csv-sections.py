import csv
import os
### Lines with 3 ### might need adaptation to your need
MAIN_CSV = '/Users/Maxime/Downloads/Portugal/Portugal.csv' ### PATH of the csv where you will agregate everything
main_csv_file = open(MAIN_CSV, 'a', newline='',encoding = "ISO-8859-1")  # 'a' to append and not overwrite ; encoding might need adaptation to handle special characters
main_csv_writer = csv.writer(main_csv_file, delimiter=';',quotechar='|') ### DELIMITER to choose wisely

folder_path = "/Users/Maxime/Downloads/Portugal/sources" ### SET to your folder with all csv
for file in os.listdir(folder_path):  #loop over all files
	if not file.startswith('.'):  #avoid any hidden file, useful on mac
		print ('handling : '+file)
		with open(folder_path+'/'+file, newline='',encoding = "ISO-8859-1") as csvfile:
			csvreader = csv.reader(csvfile, delimiter=';',quotechar='|')
			#print('csv reader is ok')
			i=0
			for row in csvreader:
				#print ('row = ', i) 
				#print (row)
				if i!=0: ### to avoid the first line with all column labels
					main_csv_writer.writerow(row)
				i+=1
			print (str(i)+' rows have been loaded')
main_csv_file.close()
