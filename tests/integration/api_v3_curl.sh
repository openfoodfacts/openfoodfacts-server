#!/bin/sh

curl -X PATCH -H "Content-Type: application/json" -d '{
    "fields" : "updated,ecoscore_grade,ecoscore_score,ecoscore_data",
    "product": { 
        "categories_tags_add": ["en:chocolate-cookies"],
        "labels_tags_fr": ["ab bio"]
    }
}' https://world.openfoodfacts.org/api/v3/product/test	