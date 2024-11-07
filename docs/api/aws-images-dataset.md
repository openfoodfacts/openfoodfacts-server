# Open Food Facts AWS images dataset

The Open Food Facts images dataset contains all images uploaded to Open Food
Facts and the OCR results on these images obtained using Google Cloud Vision.

The dataset is stored in the `openfoodfacts-images` S3 bucket hosted in the
`eu-west-3` region. All data is stored in a single `/data` folder.

Data is synchronized monthly between the Open Food Facts server and the bucket;
as such some recent images are likely missing. You should not assume all
images are present in the bucket.

To know the bucket key associated with an image for the product with barcode
'4012359114303', you should first split the barcode as follows:
`/401/235/911/4303` (that is, three groups of 3 digits followed by one group of
4 digits, all four groups being prefixed with a `/`).

This splitting is only relevant for EAN13 (13-digit barcodes):
for barcodes with fewer digits (like EAN8), the directory path is
not split: `/20065034`.

To get the raw image '1' for barcode '4012359114303', simply add the image ID:
`/401/235/911/4303/1.jpg`. Here, you will get the "raw" image, as sent by the
contributor. If you don't need the full resolution image, a 400px resized
version is also available, by adding the `.400` suffix after the image ID:
`/401/235/911/4303/1.400.jpg`.

The OCR of the image is a gzipped JSON file, and has the same file name as the
raw image, but with the `.json.gz` extension: `/401/235/911/4303/1.json.gz`

To download images, you can either use AWS CLI, or perform an HTTP request
directly:

`wget https://openfoodfacts-images.s3.eu-west-3.amazonaws.com/data/401/235/911/4303/1.jpg`

You can list all existing objects (images, OCR results) in the bucket by
downloading the gzipped text file `s3://openfoodfacts-images/data/data_keys.gz`:

`wget https://openfoodfacts-images.s3.eu-west-3.amazonaws.com/data/data_keys.gz`

Then you can easily filter the files you want using `grep` (raw images, OCR
JSON) before downloading them. For example, to keep only 400px versions of all
images:

`zcat data_keys.gz | grep '.400.jpg'`

For example, if you want to extract a sample of images, you can use the code snippet below:

```bash
# Extract images from AWS
n=1000
images_dir="images"
bucket_url="https://openfoodfacts-images.s3.eu-west-3.amazonaws.com/"

zcat data_keys.gz |
grep '.jpg' | # Filter
shuf -n "$n" | # Random sample
sed "s|^|$bucket_url|" | #Add bucket_url: "https://openfoodfacts-images.s3.eu-west-3.amazonaws.com/data/376/005/047/0099/1.jpg"
while read -r url; do
    filename=$(echo "$url" | sed "s|$bucket_url||" | tr '/' '_' | sed 's|data_||') # Filename as 376_005_047_0099_1.jpg
    wget -O "$images_dir/$filename" "$url"
done
```

You can further refine the image extraction process by applying additional filters like `last_editor` or `last_edited_date`. This can be done by combining the Open Food Facts database [dump](https://world.openfoodfacts.org/data) with **DuckDB** and the `data_keys.gz` file. For detailed instructions on using DuckDB to efficiently process the OFF database, refer to our [blog post](https://medium.com/@jeremyarancio/duckdb-open-food-facts-the-largest-open-food-database-in-the-palm-of-your-hand-0d4ab30d0701).