#!/bin/bash
# fetch_dlg_medals.sh
# Fetches DLG gold, silver, bronze medals for a given year and puts them in html/images/lang/{en,de}/labels.
# The script automatically resizes the images to 90px height and uses the correct canonical and translated names.

YEAR=$1
if [ -z "$YEAR" ]; then
    echo "Usage: $0 <year>"
    echo "Example: $0 2026"
    exit 1
fi

ROOT_DIR=$(git rev-parse --show-toplevel)
cd "$ROOT_DIR" || exit 1

mkdir -p html/images/lang/en/labels
mkdir -p html/images/lang/de/labels

resize_image() {
    local src="$1"
    local dest="$2"
    if command -v convert >/dev/null 2>&1; then
        convert "$src" -resize x90 "$dest"
    elif command -v sips >/dev/null 2>&1; then
        sips --resampleHeight 90 "$src" --out "$dest" >/dev/null 2>&1
    else
        echo "Error: Neither ImageMagick (convert) nor sips is installed. Cannot resize image."
        exit 1
    fi
}

for metal_de in gold silber bronze; do
    metal_en=$metal_de
    if [ "$metal_de" = "silber" ]; then
        metal_en="silver"
    fi

    echo "Processing $metal_de ($metal_en) for $YEAR..."

    canon_en="${YEAR}-${metal_en}-medal-of-the-german-agricultural-society"
    
    # In German, the adjectives are goldener, silberner, bronzener
    metal_de_adj="${metal_de}ner"
    if [ "$metal_de" = "gold" ]; then metal_de_adj="goldener"; fi
    canon_de="dlg-${metal_de_adj}-preis-${YEAR}"

    url_en="https://www.dlg.org/fileadmin/images/Medaillen/${YEAR}/englisch/medaille_${metal_en}_70x70.png"
    url_en2="https://www.dlg.org/fileadmin/images/Medaillen/${YEAR}/englisch/medaille_${metal_de}_70x70.png"
    url_de="https://www.dlg.org/fileadmin/images/Medaillen/${YEAR}/deutsch/medaille_${metal_de}_70x70.png"

    tmp_en=$(mktemp)
    tmp_de=$(mktemp)

    if curl -s -f "$url_en" -o "$tmp_en"; then
        resize_image "$tmp_en" "html/images/lang/en/labels/${canon_en}.90x90.png"
        echo "Saved en/labels/${canon_en}.90x90.png"
    elif curl -s -f "$url_en2" -o "$tmp_en"; then
        resize_image "$tmp_en" "html/images/lang/en/labels/${canon_en}.90x90.png"
        echo "Saved en/labels/${canon_en}.90x90.png"
    else
        echo "Failed to fetch English image from $url_en (and fallbacks)"
    fi

    if curl -s -f "$url_de" -o "$tmp_de"; then
        resize_image "$tmp_de" "html/images/lang/de/labels/${canon_de}.90x90.png"
        echo "Saved de/labels/${canon_de}.90x90.png"
    else
        echo "Failed to fetch German image from $url_de"
    fi

    rm -f "$tmp_en" "$tmp_de"
done
