#!/usr/bin/env python3
"""Generate the data used by the nginx njs module that renders the
French "coût environnemental" (Ecobalyse) label as SVG.

See conf/nginx/njs/README.md for the full explanation.

The generated file (conf/nginx/njs/environmental_cost_label_data.js) contains:
- the fixed frame of the label (border, pixel logo, "COÛT ENVIRONNEMENTAL"
  and "points d'impact" already outlined), taken from the official generator
  of the affichage-environnemental.ecobalyse.beta.gouv.fr site
  (https://github.com/incubateur-ademe/ecopass, MIT licence)
- the outlines, advance widths and kerning of the digits in Marianne ExtraBold
  (product cost) and Marianne Medium (cost per 100 g / 100 ml)
- the outlines of the fixed " pts/100g" and " pts/100ml" strings

The charter (https://affichage-environnemental.ecobalyse.beta.gouv.fr/charte.pdf)
asks for vectorized text, so the numbers are drawn with paths instead of
<text> elements: the label then renders identically everywhere, without fonts.

Usage (needs fontTools, e.g. `pip install fonttools brotli`):

    python3 scripts/environmental_cost_label/generate_label_data.py

The fonts and the ecopass source are downloaded from pinned URLs, or can be
passed as local files with --extrabold, --medium and --ecopass-simple-ts.
"""

import argparse
import io
import json
import re
import urllib.request
from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

ECOPASS_COMMIT = "7719c89fefcc8298fa0158bf504a87e64128207c"
ECOPASS_SIMPLE_TS_URL = (
    f"https://raw.githubusercontent.com/incubateur-ademe/ecopass/{ECOPASS_COMMIT}/src/utils/label/simple.ts"
)
# Marianne Medium from the French government design system (DSFR)
MEDIUM_URL = "https://cdn.jsdelivr.net/npm/@gouvfr/dsfr@1.15.4/dist/fonts/Marianne-Medium.woff2"
# Marianne ExtraBold is not part of the DSFR, we use the copy from another ADEME project
EXTRABOLD_URL = (
    "https://raw.githubusercontent.com/incubateur-ademe/nosgestesclimat-site/master/"
    "source/components/ui/fonts/Marianne-ExtraBold.woff2"
)

OUTPUT = Path(__file__).resolve().parents[2] / "conf/nginx/njs/environmental_cost_label_data.js"

CHARS = "0123456789 "
UNITS = {"g": " pts/100g", "ml": " pts/100ml"}


def fetch(url_or_path):
    if re.match(r"^https?://", url_or_path):
        with urllib.request.urlopen(url_or_path) as response:
            return response.read()
    return Path(url_or_path).read_bytes()


def pair_adjustment_subtables(ttfont):
    """Pair adjustment subtables (GPOS lookup type 2, possibly wrapped in extension lookups) of the "kern" feature"""
    gpos = ttfont["GPOS"].table
    lookup_indexes = set()
    for feature_record in gpos.FeatureList.FeatureRecord:
        if feature_record.FeatureTag == "kern":
            lookup_indexes.update(feature_record.Feature.LookupListIndex)

    subtables = []
    for index in sorted(lookup_indexes):
        lookup = gpos.LookupList.Lookup[index]
        for subtable in lookup.SubTable:
            if lookup.LookupType == 9:
                subtable = subtable.ExtSubTable
            if subtable.LookupType == 2:
                subtables.append(subtable)
    return subtables


def x_advance(record):
    return getattr(record.Value1, "XAdvance", 0) or 0


def pair_kerning(subtable, left, right):
    """Kerning between two glyph names in one pair adjustment subtable (0 if none)"""
    coverage = subtable.Coverage.glyphs
    if left not in coverage:
        return 0
    if subtable.Format == 1:
        # Format 1: list of pairs for each first glyph
        pair_set = subtable.PairSet[coverage.index(left)]
        record = next((r for r in pair_set.PairValueRecord if r.SecondGlyph == right), None)
        return x_advance(record) if record is not None else 0
    if subtable.Format == 2:
        # Format 2: kerning between classes of glyphs
        class1 = subtable.ClassDef1.classDefs.get(left, 0)
        class2 = subtable.ClassDef2.classDefs.get(right, 0)
        return x_advance(subtable.Class1Record[class1].Class2Record[class2])
    return 0


def kerning_table(ttfont):
    """Return a function giving the GPOS pair kerning (in font units) between two glyph names.

    Only the "kern" feature with pair adjustment lookups is supported, which is what Marianne uses.
    The first subtable with a non zero kerning for the pair is used."""
    subtables = pair_adjustment_subtables(ttfont)

    def kern(left, right):
        return next((value for value in (pair_kerning(t, left, right) for t in subtables) if value), 0)

    return kern


class Font:
    def __init__(self, data):
        self.ttfont = TTFont(io.BytesIO(data))
        self.cmap = self.ttfont.getBestCmap()
        self.glyph_set = self.ttfont.getGlyphSet()
        self.hmtx = self.ttfont["hmtx"]
        self.upm = self.ttfont["head"].unitsPerEm
        self.kern = kerning_table(self.ttfont)

    def glyph_name(self, char):
        return self.cmap[ord(char)]

    def advance(self, char):
        return self.hmtx[self.glyph_name(char)][0]

    def kerning(self, left, right):
        return self.kern(self.glyph_name(left), self.glyph_name(right))

    def path(self, string):
        """Outline of a string in font units (y axis pointing up), with kerning, and its advance width"""
        pen = SVGPathPen(self.glyph_set, ntos=lambda n: str(round(n)))
        x = 0
        previous = None
        for char in string:
            if previous is not None:
                x += self.kerning(previous, char)
            self.glyph_set[self.glyph_name(char)].draw(TransformPen(pen, (1, 0, 0, 1, x, 0)))
            x += self.advance(char)
            previous = char
        return pen.getCommands(), x


def font_data(font, size, chars):
    return {
        "size": size,
        "upm": font.upm,
        "adv": {char: font.advance(char) for char in chars},
        # only non zero kerning pairs, keyed by the 2 characters
        "kern": {
            left + right: font.kerning(left, right)
            for left in chars
            for right in chars
            if font.kerning(left, right)
        },
        "d": {char: font.path(char)[0] for char in chars if char != " "},
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--extrabold", default=EXTRABOLD_URL, help="Marianne ExtraBold font (URL or file)")
    parser.add_argument("--medium", default=MEDIUM_URL, help="Marianne Medium font (URL or file)")
    parser.add_argument("--ecopass-simple-ts", default=ECOPASS_SIMPLE_TS_URL, help="ecopass simple.ts (URL or file)")
    args = parser.parse_args()

    simple_ts = fetch(args.ecopass_simple_ts).decode("utf-8")
    # The frame is made of all the <path> elements of the official label
    frame = "".join(re.findall(r"<path [^>]*/>", simple_ts))
    if frame.count("<path") != 5:
        raise SystemExit("Unexpected structure of ecopass simple.ts, please check the frame extraction")

    extrabold = Font(fetch(args.extrabold))
    medium = Font(fetch(args.medium))

    small = font_data(medium, 9, CHARS)
    small["units"] = {}
    for unit, string in UNITS.items():
        d, advance = medium.path(string)
        small["units"][unit] = {"d": d, "adv": advance}

    data = {
        "source": f"https://github.com/incubateur-ademe/ecopass/blob/{ECOPASS_COMMIT}/src/utils/label/simple.ts",
        "frame": frame,
        "big": font_data(extrabold, 32, CHARS),
        "small": small,
    }

    output = (
        "// Generated by scripts/environmental_cost_label/generate_label_data.py - do not edit\n"
        "// See conf/nginx/njs/README.md\n"
        f"export default {json.dumps(data, ensure_ascii=False, separators=(',', ':'))};\n"
    )
    OUTPUT.write_text(output, encoding="utf-8")
    print(f"Wrote {OUTPUT} ({len(output)} bytes)")


if __name__ == "__main__":
    main()
