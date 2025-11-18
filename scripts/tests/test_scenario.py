# help uv run this script easily
# /// script
# dependencies = [
#   "locust",
#   "requests",
# ]
# ///

# testing with:
# uvx locust -f test_memory_usage.py --users 50 -t 60s -r 50 --autostart  --html=report.html
# RESULTS:
# same value for max_request_workers et init_server
# 1 process 1.583GiB
# 2 processes 1.233 --> 1.907GiB
# 5 processes 1.243 --> 1.853GiB (but peeked at 2.744GiB)


# 5 process starting 5  2.987GiB


# Run this file with uvx locust -f test_memory_usage.py
import random
import requests

from locust import HttpUser, events, task, tag, run_single_user


USERNAME = "testtest"
PASSWORD = "testtest"

DATA = {
    "products": set(),
    "categories": set(),
    "labels": set(),
}


@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    # fetch products list
    num_pages = 100
    page_num = 1
    while(page_num <= num_pages):
        r = requests.get(
            "http://world.openfoodfacts.localhost/api/v2/search",
            params={
                "fields": "code,categories_tags,labels_tags",
                "page_num": page_num,
                "page_size": 100,
            }
        ).json()
        num_pages = r["count"] // 100 + 1
        DATA["products"].update(d["code"] for d in r["products"])
        for tag_name in ["categories", "labels"]:
            DATA[tag_name].update(c for d in r["products"] for c in d.get(f"{tag_name}_tags", []))
        page_num += 1
    for data_name in ["products", "categories", "labels"]:
        DATA[f"{data_name}_ids"] = list(DATA[data_name])
    # get categories taxonomy
    #r = requests.get("https://static.openfoodfacts.org/data/taxonomies/categories.json")


class POTester(HttpUser):

    host = "http://world.openfoodfacts.localhost"

    @tag("edit")
    @task(10)
    def edit_categories(self):
        code = random.choice(DATA["products_ids"])
        cat = random.choice(DATA["categories_ids"])
        self.client.post("/cgi/product_jqm2.pl", data={"user_id": USERNAME, "password": PASSWORD, "categories": cat})

    @tag("facets")
    @task(1)
    def facets(self):
        cat_type = random.choice(["categories", "labels"])
        cat = random.choice(DATA[f"{cat_type}_ids"])
        r = self.client.get(
            f"/facets/{cat_type}/{cat}",
            name=f"facets/{cat_type}/<id>"
        )

    @tag("facets")
    @task(10)
    def facets_count(self):
        cat_type = random.choice(["categories", "labels"])
        r = self.client.get(
            f"/facets/{cat_type}",
            name=f"facets/{cat_type}"
        )

# --users 50 -t 60s -r 50 --autostart --headless  --html=report.html

if __name__ == "__main__":
    run_single_user(POTester)
