import csv
import os

def check_next_lines(ingredients):
	next_line_is_not_foodges = True
	keep_lines = []
	while next_line_is_not_foodges:
		next_line = ingredients.readline()
		keep_lines.append(next_line)	  
		if "carbon_footprint_fr_foodges_value:fr:" not in next_line or "carbon_footprint_fr_foodges_ingredient:fr:" not in next_line:
			next_line_is_not_foodges = False
	return keep_lines

def write_next_lines(next_lines, temporary_file):
	size = len(next_lines)
	for i in range(0, size-1):
		line = next_lines[i]
		if "carbon_footprint_fr_foodges_ingredient:fr:" in line:
			temporary_file.write(line)
			temporary_file.write("carbon_footprint_fr_foodges_value:fr:" + dict.pop(line.rstrip("\n"), None) + "\n")
	temporary_file.write(next_lines[size])

dict = {}

with open('FoodGES.csv', 'r') as csvFile:
	reader = csv.reader(csvFile)
	for row in reader:
		dict[row[2]]=row[1]

csvFile.close()

temporary_file = open("ingredients_tmp.txt","w+")
ingredients = file('taxonomies/ingredients.txt')

while True:
	line = ingredients.readline()
	temporary_file.write(line)
	if not line: break
	if "carbon_footprint_fr_foodges_ingredient:fr:" in line:
		if line.rstrip("\n") not in dict:
			print("this mapping is not known : " + line.rstrip("\n"))
		else:
			temporary_file.write("carbon_footprint_fr_foodges_value:fr:" + dict.pop(line.rstrip("\n"), None) + "\n")
			next_lines = check_next_lines(ingredients)
			write_next_lines(next_lines, temporary_file)

ingredients.close()
temporary_file.close() 

os.remove("taxonomies/ingredients.txt")
os.rename("ingredients_tmp.txt", "taxonomies/ingredients.txt")

print "This is the dictionary of unused mapping"
print dict
