"""This script is used to synchronize Open Food Facts images and OCR JSONs on
AWS S3. As part of AWS Open Dataset program, we can host free of charge data on
AWS S3.

This dataset can be used by researchers to access easily OFF data, without
overloading OFF servers.

This script should be run regularly, to synchronize new images. We currently
upload:

- all raw images (ex: 1.jpg, 2.jpg,...)
- 400px resized version of the raw images
- OCR results of the raw images (ex: 1.json.gz)
"""

import argparse
import gzip
import logging
import re
import tempfile
from logging import getLogger
from pathlib import Path
from typing import Iterator, Tuple

import boto3
import tqdm
from openfoodfacts import DatasetType, ProductDataset

logger = getLogger()
handler = logging.StreamHandler()
formatter = logging.Formatter(
    "%(asctime)s :: %(processName)s :: "
    "%(threadName)s :: %(levelname)s :: "
    "%(message)s"
)
handler.setFormatter(formatter)
handler.setLevel(logging.INFO)
logger.addHandler(handler)
logger.setLevel(logging.INFO)

s3 = boto3.resource("s3", region_name="eu-west-3")
bucket = s3.Bucket("openfoodfacts-images")


BARCODE_PATH_REGEX = re.compile(r"^(...)(...)(...)(.*)$")


def generate_product_path(barcode: str) -> str:
    if not barcode.isdigit():
        raise ValueError("unknown barcode format: {}".format(barcode))

    match = BARCODE_PATH_REGEX.fullmatch(barcode)
    splitted_barcode = [x for x in match.groups() if x] if match else [barcode]
    return "/".join(splitted_barcode)


def get_sync_filepaths(
    base_dir: Path, ds: ProductDataset
) -> Iterator[Tuple[str, Path]]:
    """Return an iterator containing files to synchronize with AWS S3 bucket.

    The iterator returns (barcode, file_path) tuples, where `barcode` is the
    product barcode, and `file_path` is the path of the file to synchronize.

    We use the product dataset to know images associated with each products,
    this way we don't push to S3 deleted images.

    We currently synchronize:

    - all raw images (ex: 1.jpg, 2.jpg,...)
    - 400px resized version of the raw images
    - OCR results of the raw images (ex: 1.json.gz)

    :param base_dir: directory where images are stored
    :param ds: product dataset
    """
    for item in tqdm.tqdm(ds, desc="products"):
        barcode = item["code"]
        if not barcode:
            continue
        product_path = generate_product_path(barcode)
        product_dir = Path(product_path)
        full_product_dir = base_dir / product_dir

        for image_id in item.get("images", {}).keys():
            if not image_id.isdigit():
                # Ignore selected image keys
                continue

            # Only synchronize raw and 400px version of images
            for image_name in (
                "{}.jpg".format(image_id),
                "{}.400.jpg".format(image_id),
            ):
                full_image_path = full_product_dir / image_name
                if not full_image_path.is_file():
                    logger.warning("image {} not found".format(full_image_path))
                    continue
                yield barcode, product_dir / image_name

            # Synchronize OCR JSON if it exists
            ocr_file_name = "{}.json.gz".format(image_id)
            if (full_product_dir / ocr_file_name).is_file():
                yield barcode, product_dir / ocr_file_name


def run(image_dir: Path) -> None:
    """Launch the synchronization.

    :param image_dir: directory where images are stored
    """
    ds = ProductDataset(DatasetType.jsonl, force_download=True, download_newer=True)
    logger.info("Fetching existing keys...")
    existing_keys = set(obj.key for obj in bucket.objects.filter(Prefix="data/"))
    logger.info("%d keys in openfoodfacts-images bucket", len(existing_keys))
    dataset_keys = set()

    uploaded = 0
    kept = 0
    deleted = 0
    for barcode, file_path in get_sync_filepaths(image_dir, ds):
        full_file_path = image_dir / file_path
        key = "data/{}".format(file_path)
        dataset_keys.add(key)

        if key in existing_keys:
            logger.debug("File %s already exists on S3", key)
            kept += 1
            continue

        extra_args = {"Metadata": {"barcode": barcode}}
        if key.endswith(".jpg"):
            extra_args["ContentType"] = "image/jpeg"

        logger.debug("Uploading file %s -> %s", full_file_path, key)
        bucket.upload_file(str(full_file_path), key, ExtraArgs=extra_args)
        uploaded += 1
        existing_keys.add(key)

        if (kept + uploaded) % 1000 == 0:
            logger.info("uploaded: %d, kept: %d", uploaded, kept)

    logger.info("Removing deleted files...")
    for missing_key in existing_keys - dataset_keys:
        # Removing files associated with deleted images
        logger.debug("Deleting S3 file %s", missing_key)
        deleted += 1
        bucket.delete_objects(
            Delete={
                "Objects": [
                    {"Key": missing_key},
                ],
            },
        )

    # We upload all S3 keys in a single `data_keys.txt` text file
    # to make it easier to know existing files on the bucket

    # Create a temporary directory to avoid uploading a corrupted file
    tmp_dir = Path(tempfile.mkdtemp())
    data_keys_path = tmp_dir / "data_keys.txt"
    logger.info("Saving data keys in %s", data_keys_path)

    with gzip.open(str(data_keys_path), "wt") as f:
        f.write("\n".join(sorted(existing_keys)))

    logger.info("Uploading data keys...")
    bucket.upload_file(str(data_keys_path), "data/data_keys.gz")
    data_keys_path.unlink()
    tmp_dir.rmdir()

    logger.info(
        "Synchronization finished, uploaded: %d, kept: %d, deleted: %d",
        uploaded,
        kept,
        deleted,
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="""Synchronize Open Food Facts images and OCR files with AWS S3.

        This script should be run regularly, to synchronize new images. We currently
        upload:

        - all raw images (ex: 1.jpg, 2.jpg,...)
        - 400px resized version of the raw images
        - OCR results of the raw images (ex: 1.json.gz)

        Before upload, the latest version of the dataset is downloaded from Open Food
        Facts servers to get the list of images to synchronize.
        """
    )
    parser.add_argument(
        "image_dir",
        type=Path,
        help="Directory where images are stored.",
    )
    args = parser.parse_args()
    run(args.image_dir)
