from datetime import datetime
import json
import logging
from pathlib import Path
import subprocess
from typing import Any, List, Mapping, Sequence
from urllib.request import urlopen

import click


logging.basicConfig()
logger = logging.getLogger()
logger.setLevel(logging.INFO)

JSONObject = Mapping[str, Any]

SCRAPY_SPIDER_FILE_PATH = Path("non_eu_spider.py").absolute()


def scrape_document_info() -> List[JSONObject]:
    """Scrape official non-EU packager codes page and extract documents information.

    Returns:
        list of JSONObject: List of document information as dictionaries with the keys:
        country_name, title, url, publication_date, file_path, section.
    """
    logger.info("Scraping remote document information")
    cmd = "scrapy runspider --output - --output-format json --loglevel WARN".split(" ")
    cmd.append(str(SCRAPY_SPIDER_FILE_PATH))
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


def document_info_diff(
    scraped: Sequence[JSONObject], local: Sequence[JSONObject]
) -> Mapping[str, List[JSONObject]]:
    scraped_docs = {d["file_path"]: d for d in scraped}
    local_docs = {d["file_path"]: d for d in local}

    new_names = set(scraped_docs.keys()).difference(local_docs.keys())
    removed_names = set(local_docs.keys()).difference(scraped_docs.keys())
    updated_names = [
        doc_name
        for doc_name, doc in local_docs.items()
        if (
            doc_name not in removed_names
            and scraped_docs[doc_name]["publication_date"] > doc["publication_date"]
        )
    ]
    unchanged_names = (
        set(local_docs.keys()).difference(removed_names).difference(updated_names)
    )

    return {
        "new": [scraped_docs[n] for n in new_names],
        "removed": [local_docs[n] for n in removed_names],
        "updated": [scraped_docs[n] for n in updated_names],
        "unchanged": [local_docs[n] for n in unchanged_names],
    }


def load_local_meta(data_dir: Path) -> JSONObject:
    meta_path = data_dir / "meta.json"
    logger.info("Loading local metadata from '%s'", meta_path)
    if not meta_path.exists():
        return {"document_info": []}
    else:
        with meta_path.open("r") as meta_file:
            return json.load(meta_file)


@click.group(help="Manage non-EU packager code data.")
def main():
    pass


@main.command(
    help="Show local data status as compared to remote source.\n\n"
    "DATA_DIR is the path to the local directory containing packager code data. "
    "Defaults to 'packager_codes_data'.",
)
@click.argument(
    "data_dir", type=click.Path(file_okay=False), default="packager_codes_data"
)
@click.option(
    "--output-format",
    "-f",
    type=click.Choice(["summary", "json"]),
    default="summary",
    help="Command output format.",
    show_default=True,
)
def status(data_dir: str, output_format: str) -> None:
    data_dir = Path(data_dir)

    local_meta = load_local_meta(data_dir)
    scraped_info = scrape_document_info()
    print(scraped_info)
    doc_diff = document_info_diff(scraped_info, local_meta["document_info"])

    if output_format == "json":
        click.echo(json.dumps(doc_diff, indent=2))
    else:
        text = (
            "Last updated: {}\nNew: {}, Removed: {}, Updated: {}, Unchanged: {}"
        ).format(
            local_meta.get("updated", "never"),
            len(doc_diff["new"]),
            len(doc_diff["removed"]),
            len(doc_diff["updated"]),
            len(doc_diff["unchanged"]),
        )
        click.echo(text)


@main.command(
    help="Sync packager code files with remote.\n\n"
    "DATA_DIR is the path of the local directory in which to sync data. Defaults to "
    "'packager_codes_data'.",
)
@click.argument(
    "data_dir", type=click.Path(file_okay=False), default="packager_codes_data"
)
def sync(data_dir: str) -> None:
    data_dir = Path(data_dir)
    data_dir.mkdir(exist_ok=True)

    local_meta = load_local_meta(data_dir)
    document_info = scrape_document_info()
    doc_diff = document_info_diff(document_info, local_meta["document_info"])

    logger.info("Deleting %s removed documents", len(doc_diff["removed"]))
    for removed_doc in doc_diff["removed"]:
        doc_path = data_dir / removed_doc["file_path"]
        logger.info("Deleting '%s'", doc_path)
        doc_path.unlink()

    changed_docs = doc_diff["new"] + doc_diff["updated"]
    download_documents(changed_docs, data_dir)

    meta_path = data_dir / "meta.json"
    logger.info("Writing metadata in '%s'", meta_path)
    meta = {
        "description": "OpenFoodFacts non-EU packager codes",
        "updated": datetime.now().isoformat(),
        "document_info": document_info,
    }
    with meta_path.open("w") as meta_file:
        json.dump(meta, meta_file, indent=2)


if __name__ == "__main__":
    main()
