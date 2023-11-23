#!/usr/bin/python3
"""Script to generate missing or corrupted Google Cloud Vision JSON.

To run, simply run as 'off' user, with the Google API_KEY as envvar:
`CLOUD_VISION_API_KEY='{KEY}' python3 run_ocr.py`

Missing JSON will be added, and corrupted JSON or Google Cloud Vision JSON
containing an 'errors' fields will be replaced.
"""

import argparse
import base64
import json
import os
import pathlib
import sys
import time
from typing import List, Optional

import requests


API_KEY = os.environ.get("CLOUD_VISION_API_KEY")

if not API_KEY:
    sys.exit("missing Google Cloud CLOUD_VISION_API_KEY as envvar")


CLOUD_VISION_URL = "https://vision.googleapis.com/v1/images:annotate?key={}".format(
    API_KEY
)

BASE_IMAGE_DIR = pathlib.Path("/srv/off/html/images/products")
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
    image_path: pathlib.Path, error_raise: bool = False,
) -> Optional[str]:
    try:
        with image_path.open("rb") as f:
            return base64.b64encode(f.read()).decode("utf-8")
    except Exception as e:
        if error_raise:
            raise e
        else:
            print(e)
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


def run_ocr_on_image_urls(image_urls: List[str]):
    images_content = [
        (image_url, get_base64_image_from_url(image_url)) for image_url in image_urls
    ]
    images_content = [
        (image_url, content)
        for image_url, content in images_content
        if content is not None
    ]

    r = run_ocr_on_image_batch([x[1] for x in images_content])

    if not r.ok:
        print(r.json())

    responses = r.json()["responses"]
    return [(images_content[i][0], responses[i]) for i in range(len(images_content))]


def run_ocr_on_image_paths(image_paths: List[pathlib.Path], override: bool = False):
    images_content = []
    for image_path in image_paths:
        json_path = image_path.with_suffix(".json")
        if json_path.is_file():
            if override:
                print("Deleting file {}".format(json_path))
                json_path.unlink()
            else:
                continue

        content = get_base64_image_from_path(image_path)

        if content:
            images_content.append((image_path, content))

    if not images_content:
        return [], False

    r = run_ocr_on_image_batch([x[1] for x in images_content])
    r_json = r.json()

    if not r.ok:
        print(r_json)
        print(image_paths)
        return [], True

    responses = r_json["responses"]
    return (
        [(images_content[i][0], responses[i]) for i in range(len(images_content))],
        True,
    )


def run_ocr(
    data_path: pathlib.Path,
    batch_size: int = 1,
    sleep: float = 0.0,
    override: bool = False,
):
    print("Running OCR on {} (batch size: {})".format(data_path, batch_size))

    image_paths = []
    with data_path.open("r") as f:
        for line in f:
            image_paths.append(pathlib.Path(line.strip()).with_suffix(".jpg"))

    for path in image_paths:
        responses, performed_request = run_ocr_on_image_paths([path], override)

        for image_path, response in responses:
            json_path = image_path.with_suffix(".json")

            with json_path.open("w") as f:
                print("Dumping OCR JSON to {}".format(json_path))
                json.dump({"responses": [response]}, f)

        if performed_request and sleep:
            time.sleep(sleep)


def dump_ocr(
    image_paths: List[pathlib.Path], sleep: float = 0.0, override: bool = False
):
    responses, performed_request = run_ocr_on_image_paths(image_paths, override)

    for image_path, response in responses:
        json_path = image_path.with_suffix(".json")

        with json_path.open("w") as f:
            print("Dumping OCR JSON to {}".format(json_path))
            json.dump({"responses": [response]}, f)

    if performed_request and sleep:
        time.sleep(sleep)


def add_missing_ocr(sleep: float):
    total = 0
    missing = 0
    json_error = 0
    ocr_error = 0
    valid = 0
    empty_images = 0

    for i, image_path in enumerate(BASE_IMAGE_DIR.glob("**/*.jpg")):
        if not image_path.stem.isdigit():
            continue

        image_size = image_path.stat().st_size

        if not image_size:
            empty_images += 1
            continue

        if image_size >= 10485760:
            continue

        json_path = image_path.with_suffix(".json")

        total += 1
        if not json_path.is_file():
            missing += 1
            dump_ocr([image_path], sleep=sleep, override=False)
            continue

        has_json_error = False
        with json_path.open("r", encoding="utf-8") as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError:
                has_json_error = True

        if has_json_error:
            dump_ocr([image_path], sleep=sleep, override=True)
            json_error += 1
            continue

        has_error = False
        for response in data["responses"]:
            if "error" in response:
                ocr_error += 1
                has_error = True
                dump_ocr([image_path], sleep=sleep, override=True)
                break

        if not has_error:
            valid += 1

        if i % 1000 == 0:
            print(
                "total: {}, missing: {}, json_error: {}, ocr_error: {}, empty images: {}, valid: {}"
                "".format(total, missing, json_error, ocr_error, empty_images, valid)
            )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-path", type=pathlib.Path)
    parser.add_argument("--override", action="store_true")
    parser.add_argument("--sleep", type=float, default=1.0)
    args = parser.parse_args()
    data_path = args.data_path
    if data_path is not None:
        assert data_path.is_file()
        r = run_ocr(data_path, sleep=args.sleep, override=args.override)
    else:
        add_missing_ocr(sleep=args.sleep)
