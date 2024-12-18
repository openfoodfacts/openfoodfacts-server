import io

taxos = []
modifies = []


def translate_taxo(block):
    taxo = {}
    data = 0  # Lines of "data" eg. wikipedia, wikidata
    # Create taxo dict
    for line in block:
        datas = line.strip().split(":")
        if len(datas[0]) is not 2:
            data = data + 1
            continue
        [ln, value] = datas
        taxo[ln] = value

    # Search for missing language
    if len(taxo) is not 0 and lang not in taxo:
        field = taxo["en"]
        print(f"Taxonomy '{field}' is missing an alias in your language.")
        alias = input("Input one: ")
        if alias is not "skip":
            return (f"{lang}:{alias}\n", data)
        else:
            return None


tagtype = input("Insert tagtype: ")
lang = input("Insert your language code: ")
file_name = f"{tagtype}.txt"

print(f"Reading file {file_name}...")
with io.open(file_name, mode="r", encoding="UTF-8") as file:
    lines = file.readlines()  # File lines in memory
    block = []

    for idx, line in enumerate(lines):
        # Skip comments
        if line.startswith("#"):
            continue

        # On new line it's a finished taxonomy
        if line is "\n":
            translation = translate_taxo(block)

            if translation is not None:  # Check if translation has been skipped
                (alias, data) = translation
                # If the user write 'exit' it saves and terminates
                if alias.endswith("exit\n"):
                    break
                lines.insert(idx - data, alias)

            # Reset block
            block = []
            continue

        block.append(line)

# Write everything on file
with io.open(file_name, mode="w", encoding="UTF-8") as file:
    file.writelines(lines)
