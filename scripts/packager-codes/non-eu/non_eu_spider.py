from datetime import datetime, date
from urllib.parse import urljoin
from typing import Any

import scrapy
from scrapy.loader import ItemLoader
from scrapy.loader.processors import MapCompose


def get_one(values: list) -> Any:
    if len(values) != 1:
        raise ValueError("values list length must be equal to 1: {}".format(values))
    return values[0]


def extract_publication_date(date_str: str) -> date:
    return datetime.strptime(date_str.strip(" ()"), "%d/%m/%Y").date()


class NonEuDocumentItem(scrapy.Item):
    country_name = scrapy.Field(output_processor=get_one)  # type: str
    section = scrapy.Field(output_processor=get_one)  # type: str
    title = scrapy.Field(output_processor=get_one)  # type: str
    publication_date = scrapy.Field(
        input_processor=MapCompose(extract_publication_date), output_processor=get_one
    )  # type: datetime
    file_path = scrapy.Field(output_processor=get_one)  # type: str
    url = scrapy.Field(output_processor=get_one)  # type: str


class NonEuSpider(scrapy.Spider):
    name = "non_eu"
    start_urls = [
        "https://webgate.ec.europa.eu/sanco/traces/output/non_eu_listsPerCountry_en.htm"
    ]

    def parse(self, response):
        for country_cell in response.xpath("//ul[@class='country-list']/li"):
            country_name = country_cell.xpath("a[@class='country-name']/text()").get()

            for section_table in country_cell.xpath("ul"):
                section = section_table.xpath("preceding-sibling::h3[1]/text()").get()

                for doc_link in section_table.xpath("li/a"):
                    file_path = doc_link.xpath("@href").get()

                    doc_loader = ItemLoader(item=NonEuDocumentItem(), selector=doc_link)
                    doc_loader.add_value("country_name", country_name)
                    doc_loader.add_value("section", section)
                    doc_loader.add_xpath("title", "text()")
                    doc_loader.add_xpath("publication_date", "span/text()")
                    doc_loader.add_value("file_path", file_path)
                    doc_loader.add_value("url", urljoin(response.url, file_path))
                    yield doc_loader.load_item()
