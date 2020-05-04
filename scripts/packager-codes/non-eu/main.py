from datetime import datetime
import json
import logging
from pathlib import Path
import subprocess
from typing import Any, Mapping, Sequence
from urllib.request import urlopen

import click


logging.basicConfig()
logger = logging.getLogger()
logger.setLevel(logging.INFO)

JSONObject = Mapping[str, Any]


def scrape_document_info() -> Sequence[JSONObject]:
    logger.info("Scraping document information")
    # Try importing scrapy to check for dependency
    import scrapy  # noqa

    spider_file_path = Path("non_eu_spider.py").absolute()
    cmd = "scrapy runspider --output - --output-format json --loglevel WARN".split(" ")
    cmd.append(str(spider_file_path))
    cmd_res = subprocess.run(cmd, stdout=subprocess.PIPE, check=True)
    return json.loads(cmd_res.stdout.decode())


def download_documents(document_info: Sequence[JSONObject], dest_dir: Path) -> None:
    logger.info("Downloading %s documents into '%s'", len(document_info), dest_dir)
    dest_dir = Path(dest_dir)
    for i, doc_info in enumerate(document_info):
        dest_path = dest_dir / doc_info["file_path"]
        logger.info(
            "(%s/%s) Downloading %s", i + 1, len(document_info), doc_info["url"]
        )
        dest_path.parent.mkdir(parents=True, exist_ok=True)
        with urlopen(doc_info["url"]) as response, dest_path.open("wb") as dest_file:
            dest_file.write(response.read())


def get_diff(
    scraped: Sequence[JSONObject], local: Sequence[JSONObject]
) -> Mapping[str, Sequence[JSONObject]]:
    scraped_names = {d["file_path"]: d for d in scraped}
    local_names = {d["file_path"]: d for d in local}

    new_docs = set(scraped_names.keys()).difference(local_names.keys())
    removed_docs = set(local_names.keys()).difference(scraped_names.keys())
    updated_docs = [
        doc_name
        for doc_name, doc in local_names.items()
        if scraped_names[doc_name]["publication_date"] > doc["publication_date"]
    ]

    return {
        "new": [scraped_names[n] for n in new_docs],
        "removed": [local_names[n] for n in removed_docs],
        "updated": [scraped_names[n] for n in updated_docs],
    }


@click.group()
def main():
    pass


@main.command()
@click.argument("data_dir", type=click.Path(file_okay=False))
@click.option(
    "--output-format", "-f", type=click.Choice(["summary", "json"]), default="summary"
)
def status(data_dir: str, output_format: str) -> None:
    data_dir = Path(data_dir)

    meta_path = data_dir / "meta.json"
    logger.info("Loading local metadata from '%s'", meta_path)
    if not meta_path.exists():
        local_meta = {"document_info": []}
    else:
        with meta_path.open("r") as meta_file:
            local_meta = json.load(meta_file)

    scraped_info = scrape_document_info()
    doc_diff = get_diff(scraped_info, local_meta["document_info"])

    if output_format == "json":
        from pprint import pprint

        pprint(doc_diff)
    else:
        text = "Last updated: {}\nNew: {}, Removed: {}, Updated: {}".format(
            local_meta.get("updated", "never"),
            len(doc_diff["new"]),
            len(doc_diff["removed"]),
            len(doc_diff["updated"]),
        )
        click.echo(text)


@main.command()
@click.argument("dest_dir", type=click.Path(file_okay=False))
def download(dest_dir: str) -> None:
    dest_dir = Path(dest_dir)
    if dest_dir.exists():
        raise click.ClickException(
            "destination directory '{}' already exists".format(dest_dir)
        )
    dest_dir.mkdir()

    document_info = scrape_document_info()
    download_documents(document_info, dest_dir)

    meta_path = dest_dir / "meta.json"
    logger.info("Writing metadata in '%s'", meta_path)
    meta = {
        "description": "OpenFoodFacts non-EU packager codes",
        "updated": datetime.now().isoformat(),
        "document_info": document_info,
    }
    with meta_path.open("w") as meta_file:
        json.dump(meta, meta_file)


if __name__ == "__main__":
    main()
