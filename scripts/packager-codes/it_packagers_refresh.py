'''
This file is part of Product Opener.
Product Opener
Copyright (C) 2011-2024 Association Open Food Facts
Contact: contact@openfoodfacts.org
Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
Product Opener is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.
You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

# PREREQUISITES
python3
verify the urls and variables in main

# INSTALLATION
## install virtual environment
sudo apt install python3.11-venv
python3 -m venv venv
source venv/bin/activate

## install needed packages
pip install 'polars[pyarrow]'
pip install requests # to get files and webpages
pip install beautifulsoup4 # to get latest csv url from webpage
# pip install requests-cache # for testing without spamming

# RUN
python3 it_packagers_refresh.py

This creates the csv file IT-merge-UTF-8.csv

# POSTPROCESSING
- deactivate the virtual environment:
deactivate
- update .sto files (make build_packager_codes)
'''

import polars as pl
from bs4 import BeautifulSoup
import requests
import io
from pathlib import Path

try:
    import requests_cache
    requests_cache.install_cache('temp', use_cache_dir=True)
except ImportError as e:
    pass  # not caching


def clean_str(expr):
    return expr.str.strip_chars().str.strip_chars(', ').str.replace_all(r'\s+,', ',').str.replace_all(r'\s+', ' ')


def concat_in_group(expr):
    return expr.map_batches(lambda l: l.list.unique().list.sort().list.join('|'), agg_list=True, returns_scalar=True).replace('', None)


def get_alimenti(csv):
    csv_file = session.get(alimenti_csv)
    # headers POA
    # precedente_bollo_cee;num_identificativo_produzione_commercializzazione;ragione_sociale;indirizzo;comune;provincia;codice_regione;regione;classificazione_stabilimento;codice_impianto_attivita;descrizione_impianto_attivita;prodotti_abilitati;specifica_prodotti;paesi_export_autorizzato;longitudine;latitudine;stato_localizzazione;cod_fiscale;p_iva;codice_comune;stato_attivita;data_ultimo_aggiornamento;num_identificativo_produzione_commercializzazione_2
    # headers SPOA
    # precedente_bollo_cee;num_identificativo_produzione_commercializzazione;ragione_sociale;indirizzo;comune;provincia;codice_regione;regione;classificazione_stabilimento;codice_impianto_attivita;descrizione_impianto_attivita;prodotti_abilitati;specifica_prodotti_abilitati;paesi_export_autorizzato;longitudine;latitudine;stato_localizzazione;cod_fiscale;p_iva;codice_comune;stato_attivita;data_ultimo_aggiornamento
    f = io.BytesIO(csv_file.content)
    df = pl.read_csv(f, separator=';', schema_overrides={
                     'longitudine': str, 'latitudine': str})
    df = df.rename({
        'num_identificativo_produzione_commercializzazione': 'codice',
        'p_iva': 'vat',
        'cod_fiscale': 'fiscal_code',
        'ragione_sociale': 'name',
        'indirizzo': 'address',
        'comune': 'city',
        'provincia': 'province',
        'regione': 'region',
        'latitudine': 'lat',
        'longitudine': 'lon',
        'classificazione_stabilimento': 'class',
        'codice_impianto_attivita': 'plant',
    }).with_columns(
        pl.col('codice').str.replace(r'^UE IT\s+(.+)$',
                                     'IT ${1} CE').replace('UE IT ', None).replace('ABP ', None).alias('code'),
        clean_str(pl.col('address')),
        clean_str(pl.col('name')),
        clean_str(pl.col('vat').replace('-', None).replace('XXXXXXX', None)),
        clean_str(pl.col('fiscal_code').replace('-', None)),
        clean_str(pl.col('paesi_export_autorizzato').replace('-', None)),
        pl.col('lat').str.replace(r'(\d+\.\d+)\.(\d+)', '${1}${2}').str.replace(
            # some lat/lon have an extra dot
            r'(\d+\.\d+)\.(\d+)', '${1}${2}'),
        pl.col('lon').str.replace(r'(\d+\.\d+)\.(\d+)', '${1}${2}').str.replace(
            # some lat/lon have an extra dot
            r'(\d+\.\d+)\.(\d+)', '${1}${2}'),
    ).sort('code', 'vat', 'fiscal_code')

    df_uq = df.group_by(
        'code', 'vat', 'fiscal_code', 'name', 'address', 'city', 'province', 'region', 'lat', 'lon', maintain_order=True
    ).agg(
        concat_in_group(pl.col('paesi_export_autorizzato')).alias('export_to'),
        concat_in_group(pl.col('class')).alias('classes'),
        concat_in_group(pl.col('plant')).alias('plants'),
    )

    print(df_uq)
    return df_uq
    # df_uq.write_csv(str(output_file), separator=';')


if __name__ == "__main__":
    code_prefix = 'IT'
    code_suffix = 'CE'
    output_file = f'{code_prefix}-merge-UTF-8.csv'
    output_file = Path(__file__).parent.parent.parent / \
        'packager-codes' / output_file
    output_file = output_file.resolve()
    # use user agent for requests
    headers = {'User-Agent': 'packager-openfoodfacts'}
    session = requests.session()
    session.headers = headers

    # TODO get latest csv urls from web permalinks
    # '.container a[href*=".csv"]:has(> span)'
    alimenti_web_permalink = 'https://www.dati.salute.gov.it/dataset/stabilimenti_italiani_reg_CE_853_2004.jsp'
    # '.container a[href*=".csv"]:has(> span)'
    sottoprodotti_web_permalink = 'https://www.dati.salute.gov.it/dataset/stabilimenti_italiani_reg_CE_1069_2009.jsp'

    alimenti_csv = 'https://www.dati.salute.gov.it/sites/default/files/opendata/STAB_POA_8_20241030.csv'
    sottoprodotti_csv = 'https://www.dati.salute.gov.it/sites/default/files/opendata/STAB_SPOA_9_20241030.csv'

    alimenti_df = get_alimenti(alimenti_csv)
    sottoprodotti_df = get_alimenti(sottoprodotti_csv)
    df_merged = pl.concat([alimenti_df, sottoprodotti_df]).sort(
        'code', 'vat', 'fiscal_code')

    df_merged.write_csv(str(output_file), separator=';')
