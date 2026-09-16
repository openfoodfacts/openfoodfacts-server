# How to Add a New Label Logo

If you would like to add a new logo for labels, please follow this process:

1. **Find the canonical name** of the label in the [labels' taxonomy](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/taxonomies/labels.txt). This is the first item in the list of the labels' synonyms (e.g., `en:100% vegetable`).
2. **Get the logo in good quality**: Avoid using contributor photos, as they are not suited for this case. Most labels have official websites with high-quality logos, sometimes in vector format (which is even better for us). As long as we use a logo to objectively inform about the presence of a label on the packaging of a product, there is no need to ask permission.
3. **Name the file appropriately**: The file should be named in the format `name-of-the-label.[width]x90.png` (or `.svg`), where `width` is the width of the logo when it is scaled to 90 pixels high. The filenames need to be unaccented, in lowercase, and use hyphens (`-`) instead of spaces.
4. **Place the logo in the correct directory**: Add the logo in the directory that corresponds to its canonical name. If the canonical name starts with `en:` (e.g., `en:something`), then it needs to be placed in the `/en/labels/` directory. The root directory for logos is `html/images/lang/`.

**Note:** Ensure you also update the taxonomy file to reference the new image file!
