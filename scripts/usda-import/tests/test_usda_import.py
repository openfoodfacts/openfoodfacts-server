
import sys
import unittest
from unittest.mock import Mock
from dotenv import dotenv_values
import json

sys.path.append('..')

import usda_to_off

example_code_tags = [
    'code-13',
    '0619128673XXX',
    '061912867XXXX',
    '06191286XXXXX',
    '0619128XXXXXX',
    '061912XXXXXXX',
    '06191XXXXXXXX',
    '0619XXXXXXXXX',
    '061XXXXXXXXXX',
    '06XXXXXXXXXXX',
    '0XXXXXXXXXXXX'
]

class TestUSDAImport(unittest.TestCase):

    def test_generate_code_tags_list(self):

        result = usda_to_off.generate_code_tags_list('0619128673216')
        expected = example_code_tags

        self.assertEqual(expected, result)


    def test_generate_barcode_len_12(self):

        result = usda_to_off.upc_to_barcode('619128673216')

        expected = {
            'code': '0619128673216',
            'code_tags': example_code_tags
        }

        self.assertEqual(expected, result)


    def test_generate_barcode_len_13(self):

        result = usda_to_off.upc_to_barcode('0619128673216')

        expected = {
            'code': '0619128673216',
            'code_tags': example_code_tags
        }

        self.assertEqual(expected, result)


    def test_generate_barcode_len_14(self):

        # length = 12.
        result = usda_to_off.upc_to_barcode('00619128673216')

        expected = {
            'code': '0619128673216',
            'code_tags': example_code_tags
        }

        self.assertEqual(expected, result)


    def test_create_off_001(self):

        usda_to_off.cfg = dotenv_values("../.env")

        with open('619128673216_off.json') as fd:
            expected = json.load(fd)

        result = usda_to_off.create_off('619128673216')

        self.maxDiff = None
        self.assertEqual(expected, result)


if __name__ == '__main__':
    unittest.main()