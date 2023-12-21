import os
import unittest
from update_tags_per_languages import get_from_api, unknown_tags_taxonomy_comparison, update_tags_field

class TestUpdateTagsPerLanguages(unittest.TestCase):

    def test_get_from_api(self):
        map_tags_field_url_parameter = {
            # # tag field in API, file name in taxonomies: url parameter
            # "allergens": "allergen",
            # "brands": "brand", # all unknown for now (no taxonomy for it)
            "categories": "category",
            # "countries": "country",
            # "labels": "label",
            # "origins": "origin", 
        }
        
        for plural in map_tags_field_url_parameter.keys():
             tags_list_url = f"https://off:off@world.openfoodfacts.net/{plural}.json"
             all_tags = get_from_api(tags_list_url)
             self.assertTrue("tags" in all_tags)
             self.assertTrue("id" in all_tags["tags"][0])
             self.assertTrue("known" in all_tags["tags"][0])
             self.assertTrue("name" in all_tags["tags"][0])


    def test_get_from_api_products_list(self):
        products_list_for_tag_url = f"https://off:off@world.openfoodfacts.net/category/en:lait.json"
        all_products_for_tag = get_from_api(products_list_for_tag_url)
        self.assertTrue("products" in all_products_for_tag)
        self.assertTrue("categories" in all_products_for_tag["products"][0])
        self.assertTrue("categories_lc" in all_products_for_tag["products"][0])
        

    def test_unknown_tags_taxonomy_comparison_function(self):
        all_tags_dict = {
            "tags": [
                {"id": "en:snacks", "known": 1, "name": "snacks"}, # known
                {"id": "en:groceries", "known": 0, "name": "groceries"}, # possible_new_tags
                {"id": "en:cured-hams", "known": 0, "name": "cured-hams"}, # already_referenced_tags
                {"id": "en:chips", "known": 0, "name": "chips"}, # possible_wrong_language_tags
            ],
        }
        file = os.path.abspath(os.path.join(os.path.dirname( __file__ ), '..', f'taxonomies/categories.txt')) 
        possible_wrong_language_tags = unknown_tags_taxonomy_comparison(all_tags_dict, file, "categories")
        os.remove("update_tags_per_languages_possible_new_tags_categories")

        # (result, expected)
        self.assertEqual(possible_wrong_language_tags, {'en:chips': 'de:chips'})


    def test_update_tags_field(self):
        updated_field_1 = update_tags_field("Lait", "en", "en:lait", "fr:laits")
        self.assertEqual(updated_field_1, "fr:laits")

        updated_field_2 = update_tags_field("Dairies,Milks,Lait", "en", "en:lait", "fr:laits")
        self.assertEqual(updated_field_2, "Dairies,Milks, fr:laits")

        updated_field_3 = update_tags_field("Snacks,Chips,Chips au paprika,Chips de pommes de terre,Chips de pommes de terre aromatisées,Chips et frites,Snacks salés", "en", "en:chips", "fr:chips")
        self.assertEqual(updated_field_3, "Snacks, fr:chips,Chips au paprika,Chips de pommes de terre,Chips de pommes de terre aromatisées,Chips et frites,Snacks salés")

if __name__ == '__main__':
    unittest.main()
