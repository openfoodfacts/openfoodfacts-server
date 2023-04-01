# How to update Agribalyse (Ecoscore)

Open Food Facts calculates the Ecoscore of a product from the Categories taxonomy where this has been linked to an AGRIBALYSE food code or proxy.

New versions of the AGRIBALYSE database are released from time to time and this document explains how to apply updates. The high-level steps are as follows:

## Obtain and Convert the AGRIBALYSE Spreadsheet

Download the AGRIBALYSE food spreadsheet from the [AGRIBALYSE](https://doc.agribalyse.fr/documentation/acces-donnees) web site (use the French site rather than English as updates on the English site may be delayed), and save it as AGRIBALYSE_vf.xlsm" in the ecoscore/agribalyse folder.

In a backend shell run the ssconvert.sh script. This will re-generate the CSV files, including the AGRIBALYSE_version and AGRIBALYSE_summary files. The AGRIBALYSE_summary file is sorted to make for easier comparison with the previous version.

The Ecoscore calculation just uses the data from the "Detail etape" tab, which is converted to AGRIBALYSE_vf.csv.2 by ssconvert. The Ecoscore.pm module skips the first three lines of this file to ignore headers. This should be checked for each update as the number of header lines has previously changed. Also check that none of the column headings have changed.

## Review and fix any changed Categories

Review the changes to AGRIBALYSE_summary to determine if any codes have been removed or significantly edited and update the Categories taxonomy accordingly.

Once the Categories have been updated you will need to build the taxonomies. You can then update unit test results with the update_tests_results.sh script to see if any have been affected.

It is also worth checking the impact the update has had on the main product database. This can be downloaded locally and the differences determined by running the update_all_produycts script.

The previous values of the Ecoscore are stored in the previous_data section under ecoscore_data. Before applying an update you will need to delete this section with the following MongoDB script:

```js
db.products.update({}, { $unset: { "ecoscore_data.previous_data": 0 } });
```

You can then use the following script from a backend bash shell to update products:

```
./update_all_products.pl --fields categories --compute-ecoscore
```

The process will set the `en:ecoscore_grade_changed` and `en:ecoscore_changed` misc_tags, which can be queried to analyse the results. For example, the following script generates a CSV file that summaries all the categories where the grade has changed:

```js
var results = db.products
  .aggregate([
    {
      $match: {
        misc_tags: "en:ecoscore-grade-changed",
      },
    },
    {
      $group: {
        _id: {
          en: "$ecoscore_data.agribalyse.name_en",
          fr: "$ecoscore_data.agribalyse.name_fr",
          code_before: "$ecoscore_data.previous_data.agribalyse.code",
          code_after: "$ecoscore_data.agribalyse.code",
          before: "$ecoscore_data.previous_data.grade",
          after: "$ecoscore_data.grade",
        },
        count: { $sum: 1 },
      },
    },
  ])
  .toArray();
print("en.Name,fr.Name,Code Before,Code After,Grade Before,Grade After,Count");
results.forEach((result) => {
  // eslint-disable-next-line no-underscore-dangle
  var id = result._id;
  print(
    '"' +
      (id.en || "").replace(/"/g, '""') +
      '","' +
      (id.fr || "").replace(/"/g, '""') +
      '",' +
      id.code_before +
      "," +
      id.code_after +
      "," +
      id.before +
      "," +
      id.after +
      "," +
      result.count
  );
});
```

The following script fetches the specific products that have changed:

```js
var products = db.products
  .find(
    {
      misc_tags: "en:ecoscore-grade-changed",
    },
    {
      _id: 1,
      "ecoscore_data.agribalyse.name_en": 1,
      "ecoscore_data.agribalyse.name_fr": 1,
      "ecoscore_data_main.agribalyse.code": 1,
      "ecoscore_data.previous_data.agribalyse.code": 1,
      "ecoscore_data.agribalyse.code": 1,
      "ecoscore_data_main.grade": 1,
      "ecoscore_data.previous_data.grade": 1,
      "ecoscore_data.grade": 1,
      "ecoscore_data_main.score": 1,
      "ecoscore_data.previous_data.score": 1,
      "ecoscore_data.score": 1,
      "ecoscore_data_main.agribalyse.ef_total": 1,
      "ecoscore_data.previous_data.agribalyse.ef_total": 1,
      "ecoscore_data.agribalyse.ef_total": 1,
      categories_tags: 1,
    }
  )
  .toArray();

print(
  "_id,en.Name,fr.Name,Code Before Main,Code Before Change,Code After,Grade Before Main,Grade Before Change,Grade After,Score Before Main,Score Before Change,Score After,ef_total Before Main,ef_total Before Change,ef_total After,Categories Tags"
);
products.forEach((result) => {
  var ecoscore_data_main = result.ecoscore_data_main || {};
  var ecoscore_data_main_agribalyse = ecoscore_data_main.agribalyse || {};
  // eslint-disable-next-line no-underscore-dangle
  print(
    result._id +
      ',"' +
      (result.ecoscore_data.agribalyse.name_en || "").replace(/"/g, '""') +
      '","' +
      (result.ecoscore_data.agribalyse.name_fr || "").replace(/"/g, '""') +
      '",' +
      ecoscore_data_main_agribalyse.code +
      "," +
      result.ecoscore_data.previous_data.agribalyse.code +
      "," +
      result.ecoscore_data.agribalyse.code +
      "," +
      ecoscore_data_main.grade +
      "," +
      result.ecoscore_data.previous_data.grade +
      "," +
      result.ecoscore_data.grade +
      "," +
      ecoscore_data_main.score +
      "," +
      result.ecoscore_data.previous_data.score +
      "," +
      result.ecoscore_data.score +
      "," +
      ecoscore_data_main_agribalyse.ef_total +
      "," +
      result.ecoscore_data.previous_data.agribalyse.ef_total +
      "," +
      result.ecoscore_data.agribalyse.ef_total +
      ',"' +
      result.categories_tags.join(" ") +
      '"'
  );
});
```

## Link existing Categories to new AGRIBALYSE codes

If a new AGRIBALYSE category matches and existing OFF Category then the two can be linked by adding an `agribalyse_food_code:en` tag. If there is not a precise match then add an `agribalyse_proxy_food_code:en` tag along with the `agribalyse_proxy_food_name:en` and `agribalyse_proxy_food_name:fr` tags.

Re-run the `update_all_products` script after doing this to assess how many products now have an Ecoscore when they did not previously. Use the above scripts to analyse the MongoDB, the new categories will have previous values of `undefined`.

## Add new Categories for new AGRIBALYSE codes

For any new categories, review the AGRIBALYSE category descriptions to ensure they are concise and unambiguous such that an OFF user is most likely to get a match on a type-ahead search. Give notice of the change on the taxonomies channel in Slack so that additional translations can be added for the new categories.

It is not necessary to add a category for every single AGRIBALYSE entry. For example, AGRIBALYSE has over 80 codes for different mineral waters but these all have almost exactly the same environmental impact. In cases like this it is acceptable to pick a single representative AGRIBALYSE code as a proxy for the Category in general.

It may be worth doing a final check to see how many categories cominations still do not have a match to AGRIBALYSE:

```js
var missing = db.products
  .aggregate([
    {
      $match: {
        "ecoscore_data.grade": null,
      },
    },
    {
      $group: {
        _id: "$categories_tags",
        count: { $sum: 1 },
      },
    },
  ])
  .toArray();
print("Category,Count");
missing.forEach((result) => {
  // eslint-disable-next-line no-underscore-dangle
  var id = result._id;
  print('"' + (id.join(",") || "").replace(/"/g, '""') + '",' + result.count);
});
```
