#!/usr/bin/env python3

import os
import pandas


def main():
    if not (os.getenv('OFF_PUBLIC_DATA_DIR') and os.getenv('PRODUCT_OPENER_FLAVOR') and os.getenv('PRODUCT_OPENER_FLAVOR_SHORT')):
        print("Environment variables OFF_PUBLIC_DATA_DIR, PRODUCT_OPENER_FLAVOR and PRODUCT_OPENER_FLAVOR_SHORT are required")
        exit(1)
    off_public_data_dir = os.getenv('OFF_PUBLIC_DATA_DIR')
    product_opener_flavor = os.getenv('PRODUCT_OPENER_FLAVOR')
    product_opener_flavor_short = os.getenv('PRODUCT_OPENER_FLAVOR_SHORT')

    if not os.path.exists(off_public_data_dir + '/offline'):
        os.makedirs(off_public_data_dir + '/offline')

    df = pandas.read_csv(off_public_data_dir + '/en.' + product_opener_flavor +
                         '.org.products.csv', sep='\t', low_memory=False)
    colnames = ['code', 'product_name', 'quantity', 'brands']
    # add 'nutriscore_grade','nova_group','environmental_score_grade' columns if the flavor is off
    if product_opener_flavor_short == 'off':
        colnames = colnames + ['nutriscore_grade',
                               'nova_group', 'environmental_score_grade']

    df.rename(columns={'nutriscore_grade': 'nutrition_grade_fr'}).to_csv(off_public_data_dir + '/offline/en.' +
                                                                         product_opener_flavor + '.org.products.small.csv', columns=colnames, sep='\t', index=False)


if __name__ == '__main__':
    main()
