import re
import requests
import csv
import geocoder
from bs4 import BeautifulSoup

def make_request(url):
    r = requests.get(url)
    return r.text

path_csv_file = './results.csv'
with open(path_csv_file, mode="w") as csv_file:
    csv_writer = csv.writer(csv_file, delimiter=";")
    csv_writer.writerow(['code', 'name', 'address', 'lat', 'lng'])

    base_url = 'https://pasze.wetgiw.gov.pl/spi/demozatw/index.php?kodwoj=&kodpow=&szukanaNazwa=&szukanaMiejsc=&szukanyWni=&onpage=20&poprzedniaSekcja=1&gatunek=&kategoria='

    # Total of 18 categories so we iterate over it
    for i in range (1, 18):
        url = base_url + '&sekcja=' + str(i)
        results = make_request(url)
        # Get count number and then make requests for all the pages
        soup = BeautifulSoup(results, 'html.parser')
        summary = soup.select('#spiMainFilter #spiMainFilterSummary')
        count = re.findall('[0-9]+', str(summary[0]))[0]
        # We get the total number of pages for each category
        pages = int(count) % 20
        # We iterate for each page
        for j in range(1, pages + 1):
            url_page = url + '&pagenbr=' + str(j)
            data = make_request(url_page)
            parser = BeautifulSoup(data, 'html.parser')
            table = parser.select('#spiMainTable')[0]
            rows = table.select('tbody tr')
            # We get the rows and we iterate over it
            for row in rows:
                cols = row.find_all('td')
                if re.match('[0-9]+', cols[0].text):
                    code = cols[1].text
                    name = cols[2].text
                    address = cols[3].text
                    g = geocoder.osm(address)
                    lng = g.osm['x'] if (g.osm and g.osm['x']) else ''
                    lat = g.osm['y'] if (g.osm and g.osm['y']) else ''
                    csv_writer.writerow([code, name, address, lat, lng])
