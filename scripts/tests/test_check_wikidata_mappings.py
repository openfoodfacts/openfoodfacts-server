#!/usr/bin/env python3
"""
Unit tests for check_wikidata_mappings.py
"""

import unittest
from scripts.taxonomies.check_wikidata_mappings import (
    normalize_string,
    strip_corporate_suffixes,
    get_tokens,
    determine_taxonomy_type,
    parse_taxonomy_entries,
    parse_git_diff_for_new_wikidata,
    check_name_match,
    check_entity_classes,
    validate_wikidata_entry,
)


class TestCheckWikidataMappings(unittest.TestCase):

    def test_normalize_string(self):
        self.assertEqual(normalize_string("Côte d'Or"), "cote d or")
        self.assertEqual(normalize_string("Crème fraîche"), "creme fraiche")
        self.assertEqual(normalize_string("Ben & Jerry's"), "ben and jerry s")
        self.assertEqual(normalize_string("Coca-Cola"), "coca cola")
        self.assertEqual(normalize_string("  Nissin   Foods  "), "nissin foods")

    def test_strip_corporate_suffixes(self):
        self.assertEqual(strip_corporate_suffixes("nissin food products"), "nissin")
        self.assertEqual(strip_corporate_suffixes("the kraft heinz company"), "kraft heinz")
        self.assertEqual(strip_corporate_suffixes("danone s a"), "danone")

    def test_determine_taxonomy_type(self):
        self.assertEqual(determine_taxonomy_type("taxonomies/brands.txt"), "brand")
        self.assertEqual(determine_taxonomy_type("taxonomies/beauty/brands.txt"), "brand")
        self.assertEqual(determine_taxonomy_type("taxonomies/food/categories.txt"), "category")
        self.assertEqual(determine_taxonomy_type("taxonomies/food/ingredients.txt"), "ingredient")
        self.assertEqual(determine_taxonomy_type("taxonomies/additives.txt"), "additive")
        self.assertEqual(determine_taxonomy_type("taxonomies/labels.txt"), "label")
        self.assertEqual(determine_taxonomy_type("taxonomies/countries.txt"), "country")
        self.assertEqual(determine_taxonomy_type("taxonomies/origins.txt"), "origin")
        self.assertEqual(determine_taxonomy_type("taxonomies/packaging_materials.txt"), "packaging_material")
        self.assertEqual(determine_taxonomy_type("taxonomies/packaging_shapes.txt"), "packaging_shape")

    def test_parse_taxonomy_entries(self):
        sample = """# Header comment

xx: 3 Musketeers
wikidata:en: Q2816512

< en: Noodles
en: Instant noodles
fr: Nouilles instantanées
wikidata:en: Q1051265
"""
        entries = parse_taxonomy_entries("taxonomies/brands.txt", content=sample)
        self.assertEqual(len(entries), 2)

        entry1 = entries[0]
        self.assertEqual(entry1["canonical_name"], "3 Musketeers")
        self.assertIn("3 Musketeers", entry1["names"])
        self.assertEqual(entry1["wikidata_qids"], [(4, "Q2816512")])

        entry2 = entries[1]
        self.assertEqual(entry2["canonical_name"], "Instant noodles")
        self.assertIn("Instant noodles", entry2["names"])
        self.assertIn("Nouilles instantanées", entry2["names"])
        self.assertEqual(entry2["parents"], ["en: Noodles"])
        self.assertEqual(entry2["wikidata_qids"], [(9, "Q1051265")])

    def test_parse_git_diff_for_new_wikidata(self):
        diff_text = """diff --git a/taxonomies/brands.txt b/taxonomies/brands.txt
index 1234567..89abcdef 100644
--- a/taxonomies/brands.txt
+++ b/taxonomies/brands.txt
@@ -50,6 +50,9 @@
 xx: OldBrand
 wikidata:en: Q111111
 
+xx: Nissin, Nissin Foods, 日清食品
+wikidata:en: Q1747864
+
 xx: AnotherBrand
diff --git a/lib/ProductOpener/Config.pm b/lib/ProductOpener/Config.pm
--- a/lib/ProductOpener/Config.pm
+++ b/lib/ProductOpener/Config.pm
@@ -1,3 +1,4 @@
+wikidata:en: Q999999
"""
        entries = parse_git_diff_for_new_wikidata(diff_text)
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]["file_path"], "taxonomies/brands.txt")
        self.assertEqual(entries[0]["qid"], "Q1747864")
        self.assertEqual(entries[0]["line_no"], 54)

    def test_check_name_match_success(self):
        # Nissin Foods matches Japanese and English labels
        entity = {
            "labels": {
                "en": {"value": "Nissin Food Products"},
                "ja": {"value": "日清食品"},
            },
            "aliases": {
                "en": [{"value": "Nissin Foods"}],
            },
            "sitelinks": {
                "enwiki": {"title": "Nissin Foods"},
            },
        }
        matched, entry_m, wd_m = check_name_match(["Nissin", "Nissin Foods", "日清食品"], entity)
        self.assertTrue(matched)

    def test_check_name_match_failure(self):
        # Star Q1747864 has no overlap with Nissin
        entity = {
            "labels": {
                "en": {"value": "HD 218061"},
            },
            "aliases": {
                "en": [{"value": "HD218061"}],
            },
            "sitelinks": {},
        }
        matched, entry_m, wd_m = check_name_match(["Nissin", "Nissin Foods", "日清食品"], entity)
        self.assertFalse(matched)

    def test_check_entity_classes_disallowed(self):
        # Q1747864: orange giant star
        entity = {
            "descriptions": {"en": {"value": "orange giant star in the constellation Aquarius"}},
            "claims": {
                "P31": [
                    {"mainsnak": {"datavalue": {"value": {"id": "Q13890"}}}},
                ]
            },
        }
        class_info = {
            "Q13890": {"label": "double star", "desc": "pair of stars"}
        }
        res = check_entity_classes("brand", entity, class_info)
        self.assertTrue(res["is_disallowed"])

    def test_check_entity_classes_expected(self):
        # Q53293: food manufacturer / enterprise
        entity = {
            "descriptions": {"en": {"value": "Japanese food company"}},
            "claims": {
                "P31": [
                    {"mainsnak": {"datavalue": {"value": {"id": "Q1252971"}}}},
                    {"mainsnak": {"datavalue": {"value": {"id": "Q6881511"}}}},
                ]
            },
        }
        class_info = {
            "Q1252971": {"label": "food manufacturer", "desc": "company that produces foods"},
            "Q6881511": {"label": "enterprise", "desc": "organizational unit"},
        }
        res = check_entity_classes("brand", entity, class_info)
        self.assertFalse(res["is_disallowed"])
        self.assertTrue(res["is_expected"])

    def test_validate_wikidata_entry_pr15287_reproduction(self):
        """Simulates PR 15287 bug: Nissin Foods linked to Q1747864 (star)."""
        entry = {
            "file_path": "taxonomies/brands.txt",
            "line_no": 100,
            "qid": "Q1747864",
            "taxonomy_type": "brand",
            "canonical_name": "Nissin",
            "names": ["Nissin", "Nissin Foods", "日清食品"],
        }
        entity = {
            "labels": {"en": {"value": "HD 218061"}},
            "descriptions": {"en": {"value": "orange giant star in the constellation Aquarius"}},
            "aliases": {},
            "claims": {
                "P31": [{"mainsnak": {"datavalue": {"value": {"id": "Q13890"}}}}]
            },
        }
        class_info = {
            "Q13890": {"label": "double star", "desc": "pair of stars"}
        }

        res = validate_wikidata_entry(entry, entity, class_info)
        self.assertEqual(res["status"], "ERROR")
        self.assertIn("Disallowed", res["message"])

    def test_validate_wikidata_entry_success(self):
        """Simulates valid Nissin Foods entry linked to Q53293."""
        entry = {
            "file_path": "taxonomies/brands.txt",
            "line_no": 100,
            "qid": "Q53293",
            "taxonomy_type": "brand",
            "canonical_name": "Nissin",
            "names": ["Nissin", "Nissin Foods", "日清食品"],
        }
        entity = {
            "labels": {"en": {"value": "Nissin Food Products"}, "ja": {"value": "日清食品"}},
            "descriptions": {"en": {"value": "Japanese food company"}},
            "aliases": {"en": [{"value": "Nissin Foods"}]},
            "claims": {
                "P31": [{"mainsnak": {"datavalue": {"value": {"id": "Q1252971"}}}}]
            },
        }
        class_info = {
            "Q1252971": {"label": "food manufacturer", "desc": "company producing foods"}
        }

        res = validate_wikidata_entry(entry, entity, class_info)
        self.assertEqual(res["status"], "PASS")

    def test_validate_wikidata_entry_missing(self):
        """Simulates nonexistent Wikidata entity."""
        entry = {
            "file_path": "taxonomies/brands.txt",
            "line_no": 100,
            "qid": "Q999999999999",
            "taxonomy_type": "brand",
            "canonical_name": "FakeBrand",
            "names": ["FakeBrand"],
        }
        res = validate_wikidata_entry(entry, None, {})
        self.assertEqual(res["status"], "ERROR")
        self.assertIn("does not exist", res["message"])


if __name__ == "__main__":
    unittest.main()
