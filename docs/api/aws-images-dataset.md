# Open Food Facts AWS images dataset

The Open Food Facts images dataset contains all images uploaded to Open Food
Facts and the OCR results on these images obtained using Google Cloud Vision.

The dataset is stored in the `openfoodfacts-images` bucket hosted in the
`eu-west-3` region. All data is stored in a single `/data` folder.

Data is synchronized every month between Open Food Facts server and S3 bucket,
as such some recent images are likely to be missing. You should not assume all
images are present on the S3 bucket.

To know the bucket key associated with an image for the product with barcode
'4012359114303', you should first split the barcode the following way:
`/401/235/911/4303`.

This splitting process is only relevant for EAN13 (barcodes with 13 digits),
for barcodes with a smaller number of digit (like EAN8), the directory path is
not splitted: `/20065034`.

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

You can know all existing objects (images, OCR results) on the bucket by
downloading the gzipped text file `s3://openfoodfacts-images/data/data_keys.gz`:

`wget https://openfoodfacts-images.s3.eu-west-3.amazonaws.com/data/data_keys.gz`

Then you can easily filter the files you want using `grep` (raw images, OCR
JSON) before downloading them. For example, to keep only 400px versions of all
images:

`zcat data_keys.gz | grep '.400.jpg'`
