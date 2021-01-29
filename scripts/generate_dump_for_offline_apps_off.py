#!/usr/bin/python
from __future__ import absolute_import, division, print_function
import csv
from itertools import imap
from operator import itemgetter


def main():
    import pandas
    df = pandas.read_csv('/srv/off/html/data/en.openfoodfacts.org.products.csv', sep='\t', low_memory=False)
    colnames = ['code','product_name','quantity','brands','nutriscore_grade','nova_group','ecoscore_grade']
    df.rename(columns={'nutriscore_grade': 'nutrition_grade_fr'}).to_csv('/srv/off/html/data/offline/en.openfoodfacts.org.products.small.csv', columns = colnames,sep='\t',index=False)

if __name__ == '__main__':
    main()

