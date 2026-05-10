with open("taxonomies/food/ingredients.txt", "r") as f:
    lines = f.readlines()

new_lines = []
i = 0
while i < len(lines):
    if lines[i].strip() == "en: tempeh" and i+3 < len(lines) and lines[i+1].strip() == "de: Tempeh" and lines[i+2].strip() == "fr: tempeh" and lines[i+3].strip() == "nl: tempeh" and lines[i+4].strip() == "xx: tempeh":
        new_lines.append("en: tempeh\n")
        new_lines.append("xx: tempeh\n")
        new_lines.append("de: Tempeh\n")
        new_lines.append("fr: tempeh\n")
        new_lines.append("nl: tempeh\n")
        i += 5
    else:
        new_lines.append(lines[i])
        i += 1

with open("taxonomies/food/ingredients.txt", "w") as f:
    f.writelines(new_lines)
