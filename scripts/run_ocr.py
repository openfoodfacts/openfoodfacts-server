#!/usr/bin/python3
"""Script to generate missing or corrupted Google Cloud Vision JSON.

To run, simply run as 'off' user, with the Google API_KEY as envvar:
`CLOUD_VISION_API_KEY='{KEY}' python3 run_ocr.py`

Missing JSON will be added, and corrupted JSON or Google Cloud Vision JSON
containing an 'errors' fields will be replaced.
"""

import argparse
import base64
import glob
import gzip
import logging
import os
import pathlib
import sys
import time
from datetime import datetime
from typing import List, Optional

import orjson
import requests

logger = logging.getLogger()
logger.setLevel(logging.DEBUG)
formatter = logging.Formatter(
    "%(asctime)s - %(name)s - %(levelname)s - %(message)s")
stream_handler = logging.StreamHandler()
stream_handler.setLevel(logging.INFO)
stream_handler.setFormatter(formatter)
logger.addHandler(stream_handler)
file_handler = logging.FileHandler("/mnt/off/logs/off/run_ocr.log")
file_handler.setLevel(logging.DEBUG)
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)

API_KEY = os.environ.get("CLOUD_VISION_API_KEY")

if not API_KEY:
    sys.exit("missing Google Cloud CLOUD_VISION_API_KEY as envvar")


CLOUD_VISION_URL = "https://vision.googleapis.com/v1/images:annotate?key={}".format(
    API_KEY
)

session = requests.Session()


def get_base64_image_from_url(
    image_url: str,
    error_raise: bool = False,
    session: Optional[requests.Session] = None,
) -> Optional[str]:
    if session:
        r = session.get(image_url)
    else:
        r = requests.get(image_url)

    if error_raise:
        r.raise_for_status()

    if r.status_code != 200:
        return None

    return base64.b64encode(r.content).decode("utf-8")


def get_base64_image_from_path(
    image_path: pathlib.Path,
    error_raise: bool = False,
) -> Optional[str]:
    try:
        with image_path.open("rb") as f:
            return base64.b64encode(f.read()).decode("utf-8")
    except Exception as e:
        if error_raise:
            raise e
        else:
            logger.exception(e)
            return None


def run_ocr_on_image_batch(base64_images: List[str]) -> requests.Response:
    r = session.post(
        CLOUD_VISION_URL,
        json={
            "requests": [
                {
                    "features": [
                        {"type": "TEXT_DETECTION"},
                        {"type": "LOGO_DETECTION"},
                        {"type": "LABEL_DETECTION"},
                        {"type": "SAFE_SEARCH_DETECTION"},
                        {"type": "FACE_DETECTION"},
                    ],
                    "image": {"content": base64_image},
                }
                for base64_image in base64_images
            ]
        },
    )
    return r


def run_ocr_on_image_paths(image_paths: List[pathlib.Path], override: bool = False):
    images_content = []
    for image_path in image_paths:
        json_path = image_path.with_suffix(".json.gz")
        if json_path.is_file():
            if override:
                logger.debug("Overriding file %s", json_path)
                json_path.unlink()
            else:
                continue

        content = get_base64_image_from_path(image_path)

        if content:
            images_content.append((image_path, content))

    if not images_content:
        return [], False

    r = run_ocr_on_image_batch([x[1] for x in images_content])

    if not r.ok:
        # logger.debug("HTTP %d received", r.status_code)
        # logger.debug("Response: %s", r.text)
        # logger.debug(image_paths)
        return [], True

    r_json = orjson.loads(r.content)
    responses = r_json["responses"]
    return (
        [(images_content[i][0], responses[i])
         for i in range(len(images_content))],
        True,
    )


def dump_ocr(
    image_paths: List[pathlib.Path], sleep: float = 0.0, override: bool = False
):
    responses, performed_request = run_ocr_on_image_paths(
        image_paths, override)

    for image_path, response in responses:
        json_path = image_path.with_suffix(".json.gz")

        with gzip.open(str(json_path), "wb") as f:
            logger.debug("Dumping OCR JSON to %s", json_path)
            f.write(
                orjson.dumps(
                    {"responses": [response], "created_at": int(time.time())})
            )
    if performed_request and sleep:
        time.sleep(sleep)


def add_to_seen_set(seen_path: pathlib.Path, item: str):
    with seen_path.open("a", encoding="utf-8") as f:
        f.write("{}\n".format(item))


def add_missing_ocr(
    base_image_dir: pathlib.Path,
    sleep: float,
    seen_path: pathlib.Path,
    maximum_modification_datetime: Optional[datetime] = None,
    dry_run: bool = False,
):
    logger.info(
        "Launching job with base_image_dir=%s, "
        "sleep=%s, "
        "seen_path=%s, "
        "maximum_modification_datetime=%s, "
        "dry_run=%s",
        base_image_dir,
        sleep,
        seen_path,
        maximum_modification_datetime,
        dry_run,
    )
    total = 0
    missing = 0
    json_error = 0
    ocr_error = 0
    valid = 0
    empty_images = 0
    expired = 0
    # OCR is still in plain JSON
    plain_json_count = 0

    logger.info("Reading seen set from %s", seen_path)

    if seen_path.is_file():
        with seen_path.open("r", encoding="utf-8") as f:
            seen_set = set(map(str.strip, f))
        logger.info("Read %d items from seen set", len(seen_set))
    else:
        seen_set = set()
        logger.info("No seen set found, starting from scratch")

    for i, image_path_str in enumerate(
        glob.iglob(f"{base_image_dir}/**/*.jpg", recursive=True)
    ):
        if i % 10000 == 0:
            logger.info(
                "scanned: %s, total: %s, missing: %s, json_error: %s, "
                "ocr_error: %s, empty images: %s, valid: %s, "
                "plain_json: %s, expired: %s",
                i,
                total,
                missing,
                json_error,
                ocr_error,
                empty_images,
                valid,
                plain_json_count,
                expired,
            )

        image_path = pathlib.Path(image_path_str)
        if not image_path.stem.isdigit():
            continue

        if image_path_str in seen_set:
            continue

        image_size = image_path.stat().st_size

        if not image_size:
            logger.debug("[EMPTY_IMAGE] %s", image_path)
            empty_images += 1
            if not dry_run:
                add_to_seen_set(seen_path, image_path_str)
            continue

        if image_size >= 10485760:
            logger.debug("[IMAGE_TOO_LARGE] %s", image_path)
            if not dry_run:
                add_to_seen_set(seen_path, image_path_str)
            continue

        json_path = image_path.with_suffix(".json.gz")
        total += 1

        if not json_path.is_file():
            plain_json_path = image_path.with_suffix(".json")
            if plain_json_path.is_file():
                logger.debug("[MISSING_NON_GZIPPED_JSON] %s", json_path)
                plain_json_count += 1
                continue

            logger.debug("[MISSING_OCR] %s", json_path)
            missing += 1
            if not dry_run:
                dump_ocr([image_path], sleep=sleep, override=False)
                add_to_seen_set(seen_path, image_path_str)
            continue

        has_json_error = False
        with gzip.open(str(json_path), "rb") as f:
            try:
                data = orjson.loads(f.read())
            except orjson.JSONDecodeError:
                has_json_error = True

        if has_json_error:
            logger.debug("[JSON_ERROR] %s", json_path)
            json_error += 1
            if not dry_run:
                dump_ocr([image_path], sleep=sleep, override=True)
                add_to_seen_set(seen_path, image_path_str)
            continue

        has_error = False
        for response in data["responses"]:
            if "error" in response:
                has_error = True

        if has_error:
            logger.debug("[OCR_ERROR] %s", json_path)
            ocr_error += 1
            if not dry_run:
                dump_ocr([image_path], sleep=sleep, override=True)
                add_to_seen_set(seen_path, image_path_str)
            continue

        if "created_at" not in data:
            logger.debug("[MISSING_CREATED_AT] %s", json_path)
            if not dry_run:
                dump_ocr([image_path], sleep=sleep, override=True)
                add_to_seen_set(seen_path, image_path_str)
            continue
        modification_datetime = datetime.fromtimestamp(data["created_at"])
        if (
            maximum_modification_datetime is not None
            and modification_datetime < maximum_modification_datetime
        ):
            expired += 1
            logger.debug("[EXPIRED] %s", json_path)
            if not dry_run:
                dump_ocr([image_path], sleep=sleep, override=True)
                add_to_seen_set(seen_path, image_path_str)
            continue

        valid += 1
        add_to_seen_set(seen_path, image_path_str)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--sleep", type=float, default=1.0)
    parser.add_argument("--seen-path", type=pathlib.Path, required=True)
    parser.add_argument(
        "--maximum-modification-datetime",
        required=False,
        type=lambda s: datetime.fromisoformat(s),
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Dry run mode (don't write to disk or send Google Cloud Vision requests)",
    )
    parser.add_argument(
        "--base-image-dir", type=pathlib.Path, default="/mnt/off/images/products/"
    )
    args = parser.parse_args()
    add_missing_ocr(
        base_image_dir=args.base_image_dir,
        sleep=args.sleep,
        seen_path=args.seen_path,
        maximum_modification_datetime=args.maximum_modification_datetime,
        dry_run=args.dry_run,
    )
