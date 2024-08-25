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
             self.assertTrue("products" in all_tags["tags"][0])


    def test_get_from_api_products_list(self):
        products_list_for_tag_url = f"https://off:off@world.openfoodfacts.net/category/en:lait.json"
        all_products_for_tag = get_from_api(products_list_for_tag_url)
        self.assertTrue("products" in all_products_for_tag)
        self.assertTrue("categories" in all_products_for_tag["products"][0])
        self.assertTrue("categories_lc" in all_products_for_tag["products"][0])
        

    def test_unknown_tags_taxonomy_comparison_function(self):
        with open('update_tags_per_languages_categories', 'w') as create_test_file:
            create_test_file.write("current tag;products")
            # new
            create_test_file.write("\nen:groceries;100")
            # already_referenced_tags, need to update
            create_test_file.write("\nen:cured-ham;80")
            # exist
            create_test_file.write("\nen:chips;60")
            # synonym exists, need to update
            create_test_file.write("\nen:fruit-jams;57")
            # contains xx:, only print in screen, not in files
            create_test_file.write("\nsv:tapas;55")

        unknown_tags_taxonomy_comparison("categories")

        exist_tags = {}
        with open('update_tags_per_languages_categories_exist', 'r') as file:
            # skip header
            file.readline()
            for line in file:
                key, value = line.strip().split(';')[0], line.strip().split(';')[1]
                exist_tags[key] = value
        # (result, expected)
        self.assertEqual(exist_tags, {'en:chips': 'de:chips'})

        new_tags = {}
        with open('update_tags_per_languages_categories_new', 'r') as file:
            # skip header
            file.readline()
            for line in file:
                key, value = line.strip().split(';')[0], line.strip().split(';')[1]
                new_tags[key] = value
        # (result, expected)
        self.assertEqual(new_tags, {'en:groceries': '100'})

        to_update_tags = {}
        with open('update_tags_per_languages_categories_to_update', 'r') as file:
            # skip header
            file.readline()
            for line in file:
                key, value = line.strip().split(';')[0], line.strip().split(';')[1]
                to_update_tags[key] = value
        # (result, expected)
        self.assertEqual(to_update_tags, {'en:cured-ham': '80', 'en:fruit-jams': '57'})

        os.remove("update_tags_per_languages_categories")
        os.remove("update_tags_per_languages_categories_exist")
        os.remove("update_tags_per_languages_categories_new")
        os.remove("update_tags_per_languages_categories_to_update")


    def test_update_tags_field(self):
        updated_field_1 = update_tags_field("Lait", "en", "en:lait", "fr:laits")
        self.assertEqual(updated_field_1, "fr:laits")

        updated_field_2 = update_tags_field("Dairies,Milks,Lait", "en", "en:lait", "fr:laits")
        self.assertEqual(updated_field_2, "en:dairies,en:milks,fr:laits")

        updated_field_3 = update_tags_field("Snacks,Chips,Chips au paprika,Chips de pommes de terre,Chips de pommes de terre aromatisées,Chips et frites,Snacks salés", "en", "en:chips", "fr:chips")
        self.assertEqual(updated_field_3, "en:snacks,fr:chips,en:chips-au-paprika,en:chips-de-pommes-de-terre,en:chips-de-pommes-de-terre-aromatisées,en:chips-et-frites,en:snacks-salés")

if __name__ == '__main__':
    unittest.main()
