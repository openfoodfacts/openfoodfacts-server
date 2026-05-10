with open("taxonomies/food/categories.txt", "r") as f:
    lines = f.readlines()

new_lines = []
i = 0
while i < len(lines):
    if lines[i].strip() == "en: Shoshu" and i+2 < len(lines) and lines[i+1].strip() == "ja: 焼酎" and lines[i+2].strip() == "xx: Shoshu":
        new_lines.append("en: Shoshu\n")
        new_lines.append("xx: Shoshu\n")
        new_lines.append("ja: 焼酎\n")
        i += 3
    else:
        new_lines.append(lines[i])
        i += 1

with open("taxonomies/food/categories.txt", "w") as f:
    f.writelines(new_lines)
