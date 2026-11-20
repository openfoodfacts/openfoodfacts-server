#!/usr/bin/env python3
"""
Unit tests for scripts/detect_forbidden_words.py
Tests detection accuracy, false-positive resistance, streaming, and CLI options.
"""

import csv
import gzip
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

# Import the detector module directly
ROOT_DIR = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT_DIR / "scripts"))

from detect_forbidden_words import (
    ForbiddenWordsDetector,
    load_forbidden_words,
    make_snippet,
    canonical_key,
    detect_file_format,
    build_product_url,
)


class TestForbiddenWordsDetector(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.words_by_lang = load_forbidden_words()
        cls.words_by_lang.setdefault("xx", []).extend([
            "dickhead", "motherfucker", "bullshit", "asshole", "retard"
        ])
        cls.words_by_lang.setdefault("es", []).extend(["hijo de puta", "mierda", "gilipollas"])
        cls.words_by_lang.setdefault("en", []).extend(["dickhead", "fuck", "shit", "bullshit", "cum", "anus"])
        cls.words_by_lang.setdefault("fr", []).extend(["merde", "trou du cul", "pipi", "caca", "bite", "cul"])
        cls.words_by_lang.setdefault("de", []).extend(["scheisse", "arschloch"])
        from detect_forbidden_words import load_allowlist
        cls.barcodes, cls.patterns, cls.country_rules = load_allowlist()
        cls.detector = ForbiddenWordsDetector(cls.words_by_lang, cls.barcodes, cls.patterns, cls.country_rules)
        cls.all_detector = ForbiddenWordsDetector(cls.words_by_lang, cls.barcodes, cls.patterns, cls.country_rules, all_languages=True)

    def test_canonical_key(self):
        self.assertEqual(canonical_key("mÊrde"), "merde")
        self.assertEqual(canonical_key("trôu-du-cûl"), "trou du cul")
        self.assertEqual(canonical_key("nIquE   Ta   mÈrE"), "nique ta mere")
        self.assertEqual(canonical_key("Scheiße"), "scheisse")

    def test_allowlist_barcodes(self):
        # Known real product barcodes (e.g. from BigQuery list) should be bypassed
        allowed_detector = ForbiddenWordsDetector(
            self.words_by_lang,
            allowed_barcodes={"5410293620116", "3760182600142"}
        )
        # Barcode 5410293620116 is 'couilles de singe'
        v = allowed_detector.find_violations("couilles de singe", "fr", code="5410293620116")
        self.assertEqual(v, [])

        # Non-allowed barcode should still be flagged
        v2 = allowed_detector.find_violations("couilles de singe", "fr", code="9999999999999")
        self.assertTrue(len(v2) > 0)

    def test_allowlist_patterns(self):
        # Allowlist patterns from conf/forbidden_words_allowlist.txt
        allowed_detector = ForbiddenWordsDetector(
            self.words_by_lang,
            allowed_patterns={"spotted dick", "cacao", "cornichon", "pissenlit", "fucking delicious"}
        )
        self.assertEqual(allowed_detector.find_violations("Auntys Spotted Dick Puddings", "en"), [])
        self.assertEqual(allowed_detector.find_violations("Fucking delicious cookie", "en"), [])
        self.assertEqual(allowed_detector.find_violations("Chocolat noir pur cacao", "fr"), [])
        self.assertEqual(allowed_detector.find_violations("Salade aux pissenlits", "fr"), [])

        # But standalone or non-allowlisted usage should still be flagged
        v = allowed_detector.find_violations("You are a real dickhead", "en")
        self.assertTrue(any(item[0] == "dickhead" for item in v))


    def test_country_rules_german_pute(self):
        # In German context, 'Pute' means turkey
        allowed_detector = ForbiddenWordsDetector(
            self.words_by_lang,
            country_rules={"pute": ["de", "germany", "en:germany", "at", "ch"]}
        )
        # German product
        self.assertEqual(allowed_detector.find_violations("Sandwich Pute", "de", countries="en:germany"), [])
        self.assertEqual(allowed_detector.find_violations("Gemüse mit Reis & Pute", "de"), [])

        # French insult
        v = allowed_detector.find_violations("Grosse pute", "fr", countries="en:france")
        self.assertTrue(any(item[0] == "pute" for item in v))


    def test_french_detection(self):
        # Merde
        v = self.detector.find_violations("Ce produit c'est de la merde totale", "fr")
        self.assertEqual(len(v), 1)
        self.assertEqual(v[0][0], "merde")

        # Accent variations: mÊrde
        v = self.detector.find_violations("Vraiment de la mÊrde !", "fr")
        self.assertEqual(len(v), 1)
        self.assertEqual(v[0][0], "merde")

        # Multi-word phrase: trou du cul
        v = self.detector.find_violations("Espèce de trou du cul", "fr")
        self.assertEqual(len(v), 1)
        self.assertEqual(v[0][0], "trou du cul")

        # Vandalism sequence
        v = self.detector.find_violations("sexe amour pipi caca bite cul gazi", "fr")
        matched_words = {item[0] for item in v}
        self.assertTrue({"pipi", "caca", "bite", "cul"}.issubset(matched_words))

    def test_english_detection(self):
        v = self.detector.find_violations("What the fuck is this product", "en")
        self.assertEqual(len(v), 1)
        self.assertEqual(v[0][0], "fuck")

        v = self.detector.find_violations("Pure bullshit in ingredients", "en")
        self.assertEqual(len(v), 1)
        self.assertEqual(v[0][0], "bullshit")

        # Specific user-reported vandalism
        v2 = self.detector.find_violations("Cum from my anus", "en")
        matched = {item[0] for item in v2}
        self.assertTrue({"cum", "anus"}.issubset(matched))


    def test_universal_words_across_all_languages(self):
        # Universal words (category xx) should match regardless of language
        for lang in ("fr", "en", "de", "es", "it", "ja", "zh", None):
            v = self.detector.find_violations("Produced by bullshit company", lang)
            self.assertTrue(any(item[0] == "bullshit" for item in v), f"Failed for lang {lang}")

    def test_german_detection(self):
        # Scheisse with ß
        v = self.detector.find_violations("Das ist absolute Scheiße!", "de")
        self.assertEqual(len(v), 1)
        self.assertEqual(v[0][0], "scheisse")

        v = self.detector.find_violations("Du Arschloch", "de")
        self.assertEqual(len(v), 1)
        self.assertEqual(v[0][0], "arschloch")

    def test_spanish_detection(self):
        v = self.detector.find_violations("Esto es una mierda", "es")
        self.assertEqual(len(v), 1)
        self.assertEqual(v[0][0], "mierda")

        v = self.detector.find_violations("Vete a la mierda, hijo de puta", "es")
        matched = {item[0] for item in v}
        self.assertTrue(any("mierda" in m for m in matched))
        self.assertTrue(any("hijo de puta" in m for m in matched))


    def test_food_false_positives(self):
        # English: chocolate bites, energy bites, bite-size
        self.assertEqual(self.detector.find_violations("Crunchy chocolate bites", "en"), [])
        self.assertEqual(self.detector.find_violations("Energy bite with organic dates", "en"), [])
        self.assertEqual(self.detector.find_violations("Bite-size mini muffins", "en"), [])
        self.assertEqual(self.detector.find_violations("Bite-size mini muffins", "fr"), [])

        # Extra virgin olive oil
        self.assertEqual(self.detector.find_violations("Huile d'olive extra vierge", "fr"), [])
        self.assertEqual(self.detector.find_violations("Extra virgin olive oil", "en"), [])

        # Arroz con leche / Confit / Concentré
        self.assertEqual(self.detector.find_violations("Arroz con leche tradicional", "es"), [])
        self.assertEqual(self.detector.find_violations("Confit de canard du Sud-Ouest", "fr"), [])
        self.assertEqual(self.detector.find_violations("Concentré de tomates de Provence", "fr"), [])

        # French culinary terms with 'cul'
        self.assertEqual(self.detector.find_violations("Pâté de porc cul noir du Limousin", "fr"), [])
        self.assertEqual(self.detector.find_violations("Cœurs et culs d'artichauts à l'huile", "fr"), [])
        self.assertEqual(self.detector.find_violations("Préparation en cul de poule", "fr"), [])

        # German bitte schütteln
        self.assertEqual(self.detector.find_violations("Vor dem Öffnen bitte schütteln", "de"), [])
        self.assertEqual(self.detector.find_violations("Vor dem Öffnen bitte schütteln", "fr"), [])

        # French P'tit / P'tits (abbreviation of petit)
        self.assertEqual(self.detector.find_violations("P'tit Déli biscuits", "fr"), [])
        self.assertEqual(self.detector.find_violations("Mes p'tits secrets", "fr"), [])
        self.assertEqual(self.detector.find_violations("P’tit Québec fromage", "fr"), [])

        # Abbreviation Ass. / Ass'n (Association)
        self.assertEqual(self.detector.find_violations("Sioux Honey Ass'n", "en"), [])
        self.assertEqual(self.detector.find_violations("Ass. Agricola Barcelona", "es"), [])

        # Italian food words from allowlist
        self.assertEqual(self.detector.find_violations("Oggi Pesce Spada", "it"), [])
        self.assertEqual(self.detector.find_violations("Molino Quaglia Farina Petra", "it"), [])
        self.assertEqual(self.detector.find_violations("Tisana al Finocchio", "it"), [])
        self.assertEqual(self.detector.find_violations("Pizza Regina", "it"), [])
        self.assertEqual(self.detector.find_violations("Trio de poivrons", "fr"), [])

        # Legitimate brand false positives (Gerber baby food, Cock Brand Asian foods, H E Butt Grocery)
        self.assertEqual(self.detector.find_violations("Gerber", "en"), [])
        self.assertEqual(self.detector.find_violations("Cock Brand", "en"), [])
        self.assertEqual(self.detector.find_violations("H E Butt Grocery Company", "en"), [])

        # Preservative and chemical functions (retard spoilage / staling / oxidation)
        self.assertEqual(self.detector.find_violations("potassium sorbate [to retard spoilage], xanthan gum", "en"), [])
        self.assertEqual(self.detector.find_violations("d, guar gum, potassium sorbate [to [retard] spoilage], xanthan gum, dextrose, ...", "en"), [])
        self.assertEqual(self.detector.find_violations("Calcium propionate added to retard staling", "en"), [])
        self.assertEqual(self.detector.find_violations("Antioxidant to retard oxidation of oils", "en"), [])

        # Multilingual culinary terms: rape (monkfish / grated / rapeseed), negre (black), fag (beechwood), etc.
        self.assertEqual(self.detector.find_violations("Filete de rape fresco", "es", countries="en:spain"), [])
        self.assertEqual(self.detector.find_violations("Emmental râpé 200g", "fr", countries="en:france"), [])
        self.assertEqual(self.detector.find_violations("Rapeseed oil for frying", "en"), [])
        self.assertEqual(self.detector.find_violations("Pebre negre mòlt", "ca", countries="en:spain"), [])
        self.assertEqual(self.detector.find_violations("Vi negre jove de Catalunya", "ca", countries="en:spain"), [])
        self.assertEqual(self.detector.find_violations("Salam maturat afumat cu lemn de fag", "ro", countries="en:romania"), [])
        self.assertEqual(self.detector.find_violations("Bitte kühl und trocken lagern", "de", countries="en:germany"), [])
        self.assertEqual(self.detector.find_violations("Pasta i gräddig sås med bladspenat", "sv", countries="en:sweden"), [])
        self.assertEqual(self.detector.find_violations("Bad Byron's Butt Rub Seasoning", "en"), [])
        self.assertEqual(self.detector.find_violations("Pork shoulder boston butt", "en"), [])

        # OCR artifacts in ingredients
        self.assertEqual(self.detector.find_violations("thickener: guar cum, xanthan gum", "en"), [])
        self.assertEqual(self.detector.find_violations("acidifiant : acide ci - trique", "fr"), [])

        # But non-preservative usage must still be flagged
        v_slur = self.detector.find_violations("This product is total retard", "en")
        self.assertTrue(any(item[0] == "retard" for item in v_slur))
        v_shit = self.detector.find_violations("Holy shit snack", "en")
        self.assertTrue(any(item[0] == "shit" for item in v_shit))


    def test_snippet_generation(self):
        text = "Biscuit sablé aux pépites de chocolat et c'est de la grosse merde selon les avis."
        v = self.detector.find_violations(text, "fr")
        self.assertEqual(len(v), 1)
        canon, raw, (s, e) = v[0]
        snippet = make_snippet(text, s, e, context_chars=20)
        self.assertIn("[merde]", snippet)
        self.assertTrue(snippet.startswith("..."))


class TestDetectorCLI(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.script_path = str(ROOT_DIR / "scripts" / "detect_forbidden_words.py")

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_cli_csv_and_tsv(self):
        # Create a sample test CSV
        csv_path = os.path.join(self.temp_dir.name, "sample.csv")
        out_csv = os.path.join(self.temp_dir.name, "output.csv")

        rows = [
            {
                "code": "1001",
                "product_name": "Organic Milk",
                "ingredients_text": "Whole pasteurized milk, vitamin D3",
                "brands": "Lactel",
                "lang": "en",
                "countries_tags": "en:france",
            },
            {
                "code": "1002",
                "product_name": "Choco Bites",
                "ingredients_text": "Cacao, sugar, bite-size hazelnut pieces",
                "brands": "Nestle",
                "lang": "en",
                "countries_tags": "en:united-kingdom",
            },
            {
                "code": "1003",
                "product_name": "Yaourt aux fruits de merde",
                "ingredients_text": "Lait entier, fraises",
                "brands": "Danone",
                "lang": "fr",
                "countries_tags": "en:france",
            },
            {
                "code": "1004",
                "product_name": "Biscuits croustillants",
                "ingredients_text": "Farine, beurre, un gros trou du cul a craché dedans",
                "brands": "Lu",
                "lang": "fr",
                "countries_tags": "en:france",
            },
            {
                "code": "1005",
                "product_name": "Corn Flakes",
                "ingredients_text": "Corn, salt, sugar",
                "brands": "Salope Brand",
                "lang": "fr",
                "countries_tags": "en:france",
            },
        ]

        with open(csv_path, "w", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
            writer.writeheader()
            writer.writerows(rows)

        # Run CLI
        cmd = [
            sys.executable, self.script_path,
            "--input", csv_path,
            "--output", out_csv,
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"CLI error: {res.stderr}")

        # Check output CSV
        with open(out_csv, "r", encoding="utf-8") as f:
            reader = list(csv.DictReader(f))

        self.assertEqual(len(reader), 3)
        codes = [r["code"] for r in reader]
        self.assertEqual(codes, ["1003", "1004", "1005"])

        words = [r["forbidden_word_matched"] for r in reader]
        self.assertEqual(words, ["merde", "trou du cul", "salope"])

        fields = [r["field_matched"] for r in reader]
        self.assertEqual(fields, ["product_name", "ingredients_text", "brands"])

        # Check URLs
        for r in reader:
            self.assertEqual(r["url"], f"https://world.openfoodfacts.org/product/{r['code']}")

    def test_cli_gzip_tsv(self):
        # Test compressed gzipped TSV file
        tsv_gz_path = os.path.join(self.temp_dir.name, "sample.tsv.gz")
        out_csv = os.path.join(self.temp_dir.name, "output_gz.csv")

        with gzip.open(tsv_gz_path, "wt", encoding="utf-8", newline="") as f:
            f.write("code\tproduct_name\tingredients_text\tbrands\tlang\n")
            f.write("2001\tClean Tea\tGreen tea leaves\tLipton\ten\n")
            f.write("2002\tBad Tea\tGreen tea, what the fuck\tLipton\ten\n")

        cmd = [
            sys.executable, self.script_path,
            "--input", tsv_gz_path,
            "--output", out_csv,
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"CLI error: {res.stderr}")

        with open(out_csv, "r", encoding="utf-8") as f:
            reader = list(csv.DictReader(f))

        self.assertEqual(len(reader), 1)
        self.assertEqual(reader[0]["code"], "2002")
        self.assertEqual(reader[0]["forbidden_word_matched"], "fuck")

    def test_cli_skip_recognized_ingredients(self):
        csv_path = os.path.join(self.temp_dir.name, "ingredients_test.csv")
        out_csv = os.path.join(self.temp_dir.name, "ingredients_out.csv")

        rows = [
            {
                "code": "4001",
                "product_name": "Recognized bread",
                "ingredients_text": "Flour, water, yeast, salt, potassium sorbate",
                "unknown_ingredients_n": "0",
                "known_ingredients_n": "5",
                "ingredients_n": "5",
                "lang": "en",
            },
            {
                "code": "4002",
                "product_name": "Vandalized bread",
                "ingredients_text": "Flour, water, shit, salt",
                "unknown_ingredients_n": "1",
                "known_ingredients_n": "3",
                "ingredients_n": "4",
                "lang": "en",
            },
        ]

        with open(csv_path, "w", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
            writer.writeheader()
            writer.writerows(rows)

        cmd = [
            sys.executable, self.script_path,
            "--input", csv_path,
            "--output", out_csv,
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"CLI error: {res.stderr}")

        with open(out_csv, "r", encoding="utf-8") as f:
            reader = list(csv.DictReader(f))

        # Only 4002 should be flagged, 4001 should be skipped
        self.assertEqual(len(reader), 1)
        self.assertEqual(reader[0]["code"], "4002")
        self.assertEqual(reader[0]["forbidden_word_matched"], "shit")

    def test_cli_stdin(self):
        # Test piping from stdin
        tsv_data = "code\tproduct_name\tlang\n3001\tHoly shit snack\ten\n"
        cmd = [
            sys.executable, self.script_path,
            "--input", "-",
            "--output", os.path.join(self.temp_dir.name, "stdin_out.csv"),
        ]
        res = subprocess.run(cmd, input=tsv_data, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"CLI stdin error: {res.stderr}")

        with open(os.path.join(self.temp_dir.name, "stdin_out.csv"), "r", encoding="utf-8") as f:
            reader = list(csv.DictReader(f))

        self.assertEqual(len(reader), 1)
        self.assertEqual(reader[0]["code"], "3001")
        self.assertEqual(reader[0]["forbidden_word_matched"], "shit")

    def test_parquet_missing_library_error(self):
        # When pyarrow/duckdb are not installed, scanning a parquet file should exit with clear error
        parquet_dummy = os.path.join(self.temp_dir.name, "food.parquet")
        with open(parquet_dummy, "wb") as f:
            f.write(b"PAR1dummy")

        cmd = [
            sys.executable, self.script_path,
            "--input", parquet_dummy,
            "--output", os.path.join(self.temp_dir.name, "parquet_out.csv"),
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("Parquet reading requires 'pyarrow' or 'duckdb'", res.stderr)
        self.assertIn("pip install pyarrow", res.stderr)



if __name__ == "__main__":
    unittest.main()
