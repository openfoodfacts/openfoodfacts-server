#!/usr/bin/python
from __future__ import absolute_import, division, print_function
import csv
from itertools import imap
from operator import itemgetter


def main():
    import pandas
    df = pandas.read_csv('/srv/obf/html/data/en.openbeautyfacts.org.products.csv', sep='\t', low_memory=False)
    colnames = ['code','product_name','quantity','brands']
    df.to_csv('/srv/obf/html/data/offline/en.openbeautyfacts.org.products.small.csv', columns = colnames,sep='\t',index=False)

if __name__ == '__main__':
    main()

