import csv
import os


PATH_TO_TEMPORARY = "ingredients_tmp.txt"
PATH_TO_INGREDIENTS = "taxonomies/ingredients.txt"
STRING_FOODGES_VALUE = "carbon_footprint_fr_foodges_value:fr:"
STRING_FOODGES_INGREDIENT = "carbon_footprint_fr_foodges_ingredient:fr:"

unused_mappings = []
dict = {}


temporary_exists = os.path.isfile(PATH_TO_TEMPORARY)
if temporary_exists:
	print "The temporary file already exists"
	exit()

ingredients_exists = os.path.isfile(PATH_TO_INGREDIENTS)
if not ingredients_exists:
        print "The ingredient file does not exist, check the path :" + PATH_TO_INGREDIENTS
        exit()

def check_next_lines(ingredients):
	next_line_is_not_foodges = True
	keep_lines = []
	while next_line_is_not_foodges:
		next_line = ingredients.readline()
		keep_lines.append(next_line)	  
		if STRING_FOODGES_VALUE not in next_line and STRING_FOODGES_INGREDIENT not in next_line:
			next_line_is_not_foodges = False
	return keep_lines

def write_next_lines(next_lines, temporary_file):
	size = len(next_lines)
	for i in range(0, size-1):
		line = next_lines[i]
		if STRING_FOODGES_INGREDIENT in line:
			temporary_file.write(line)
			if line.rstrip("\n") not in dict:
                        	print("this mapping is not known : " + line.rstrip("\n"))
			else:
				temporary_file.write(STRING_FOODGES_VALUE + dict.get(line.rstrip("\n")) + "\n")
				if line.rstrip("\n") in unused_mappings:
					unused_mappings.remove(line.rstrip("\n"))
	temporary_file.write(next_lines[size-1])

with open('FoodGES.csv', 'r') as csvFile:
	reader = csv.reader(csvFile)
	for row in reader:
		dict[row[2]]=row[1]
		unused_mappings.append(row[2])

csvFile.close()

temporary_file = open(PATH_TO_TEMPORARY,"w+")
ingredients = file(PATH_TO_INGREDIENTS)

while True:
	line = ingredients.readline()
	temporary_file.write(line)
	if not line: break
	if STRING_FOODGES_INGREDIENT in line:
		if line.rstrip("\n") not in dict:
			print("this mapping is not known : " + line.rstrip("\n"))
		else:
			temporary_file.write(STRING_FOODGES_VALUE + dict.get(line.rstrip("\n")) + "\n")
			if line.rstrip("\n") in unused_mappings:
				unused_mappings.remove(line.rstrip("\n"))
			next_lines = check_next_lines(ingredients)
			write_next_lines(next_lines, temporary_file)

ingredients.close()
temporary_file.close() 

os.remove(PATH_TO_INGREDIENTS)
os.rename(PATH_TO_TEMPORARY, PATH_TO_INGREDIENTS)

print("\n")
print "This is the list of unused mapping : "
for mapping in unused_mappings:
	print mapping
