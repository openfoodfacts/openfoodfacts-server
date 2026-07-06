# Add a new country

- populate `packager_sources_config.json` with the new country using iso country code (https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes)
  - add country_name (used for OpenStreetMap search)
  - add sources (1 url = 1 source)
      - url (used for OpenStreetMap search)
      - files (1 Excel/pdf/csv file = 1 file)
         - type (required): excel, pdf, html, csv
         - keyword (optional): used to find the name of the file, use if file contains date in the name
         - last_filename: used to find the name of the file. If keyword is defined and found file is same as last_filename, process will stop early. On the other hand, if keyword is defined and found file is different the last_filename will be updated at the end of a successful processing.
         - sheets (optional): sheet(s) in the Excel file to extract. If missing first sheet (0) will be extracted only. To extract single sheet, set same integer for start and end.
            - start: which sheet to start extracting (starts from 0)
            - end: which sheet to stop extracting
         - header_keywords: used to find header row, so that we can drop lines above the header in Excel/csv, all keywords should appear in the row containing header.
         - columns: which columns in Excel/csv correspond code, name, street, city, postalcode
         - code_format:
            - suffix (required): suffix to add after the code (for example, EU for HR 123 EU)
            - strip_prefix (optional): if file already contains prefix that needs to be dropped.
         - address_extractor: strategy to apply if among the 3 columns (street, city, postalcode), some of them are merged into same column. Strategies are defined in `common/transform.py`.
         - normalize_fields (optional): on which fields applies rules in `packager_text_replacements_config.json`
         - postalcode_format (optional): if it needs to have leading zeros.

- create file <country_code>_packagers_refresh.py
```
#!/usr/bin/env python3
"""
This file is part of Product Opener.

Product Opener
Copyright (C) 2011-2025 Association Open Food Facts
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
"""

from countries.<country_code>.main import main

if __name__ == "__main__":
    main()

```

- create folder `countries/<country_code>/` with `geocode_strategies.py`, `main.py`, `transform.py`.
  - `geocode_strategies.py`: (optional) define strategies to adopt if url returns empty result (remove dash or comma in street, drop street, *etc*.). Start with minimal strategy and add according to what you see in the logs.
  - `main.py`: iterate over sources, 
  - `transform.py`: 


- run the script:  
```
python3 <country_code>_packagers_refresh.py > out
```

and look into the `out` file for 
> No results found (attempt  

and rework the geocode_strategies accordingly and/or use `packager_text_replacements_config.json` to remove typo, unwanted prefix/suffix *etc*.



# country and files summary

| country | url | name (template) | format | pages (start from 0) |
|---------|-----|-----------------|--------|-------|
| all     | https://food.ec.europa.eu/food-safety/biological-safety/food-hygiene/approved-eu-food-establishments/national-websites_en | - | - | - |
| dk      | https://foedevarestyrelsen.dk/kost-og-foedevarer/start-og-drift-af-foedevarevirksomhed/autorisation-og-registrering/registrerede-og-autorisede-foedevarevirksomheder | Autoriserede_Foedevarevirksomheder_Excel.xlsx | xlsx | 2-20 |
| fi      | https://www.ruokavirasto.fi/en/foodstuffs/food-sector/setting-up-a-food-business/make-an-announcement-of-a-food-business-or-apply-for-an-approval/approved-establishments/ | liha-alan_laitokset.xls | xls | 1 |
|         |  | kala-alan_laitokset.xls | xls | 1 |
|         |  | maitoalanlaitokset.xls | xls | 1 |
|         |  | muna-alanlaitokset.xls | xls | 1 |
|         |  | varastolaitokset.xls | xls | 1 |
|         |  | highly-refined-products.xls | xls | 1 |
|         |  | hyvaksytyt-idattamot.xls | xls | 1 |
| hr      | http://veterinarstvo.hr/default.aspx?id=2423 | DD-MM-YYYY. svi odobreni objekti.xls | xls | 0 |
| ie      | 

