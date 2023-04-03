# Explanation on packaging data

This document explains how packaging data is currently added, updated and structured in the Open Food Facts database, and how it could be improved.

## Introduction

## Types of packaging data

Food products typically have 1 or more packaging components (e.g. milk may have a bottle and a cap).

For each product, we aim to have a comprehensive list of all its packaging components, with detailed information about each packaging component.

### Data about packaging components

For each packaging component, we want data for different attributes, like its shape (e.g. a bottle) and its size (e.g. plastic).

There are many different attributes that can be interesting for specific uses. For instance, researchers in epidemiology are interested in knowing which packaging component is in contact with the food itself, and which one can be put in the microwave oven, so that they can study the long term effects of some plastics on health.

## Sources of packaging data

We can get packaging data from different sources:

### Users

Users of the Open Food Facts website and app, and users of 3rd party apps, can enter packaging data.

### Manufacturers

Some manufacturers send product data through GS1, which currently has limited support for packaging information (but this is likely to be improved in the years to come).

Some manufacturers send us more detailed packaging data (e.g. recycling instructions) through the Producers Platform.

Some manufacturers send us data used to compute the Eco-Score using the Eco-Score spreadsheet template, which has fields like "Packaging 1", "Material 1", "Packaging 2", "Material 2" etc.

### Product photos and machine learning

We can extract logos related to packaging, or parse the text recognized from product photos to recognize packaging information or recycling instructions.

## How packaging data is currently added, updated and structured in Open Food Facts

In Open Food Facts, we currently have a number of input fields related to packaging. The data in those fields is parsed and analyzed to create a structured list of packaging components with specific attributes.

### Current input fields

#### Packaging tag field (READ and WRITE)

At the start of Open Food Facts in 2012, we had a "packaging" tag field where users could enter comma separated free text entries about the packaging (e.g. "Plastic", "Bag" or "Plastic bag") in different languages.

In 2020, we made this field a taxonomized field. As a result, we now store the language used to fill this field, so that we can match its value to the multilingual packaging taxonomy. So "plastique" in French will be mapped to the canonical "en:plastic" entry.

#### Packaging information / recycling instructions text field (READ and WRITE)

In 2020, we also added a language specific field ("packaging_text_[language code]" e.g. "packaging_text_en" for English) to store free text data about the packaging. It can contain the text of the recycling instructions printed on the packaging (e.g. "bottle to recycle, cap to discard"), or can be filled in by users (e.g. "1 PET plastic bottle to recycle, 1 plastic cap").

### Current resulting packagings data structure (READ only)

The input fields are analyzed and combined to create the "packagings" data structure.

The structure is an array of packaging components. Each packaging component can have values for different attributes:

- number: the number of units for the packaging component (e.g. a pack of beers may contain 6 bottles)
- shape: the general shape of the packaging component (e.g. "bottle", "box")
- material: the material of the packaging component
- quantity: how much product the packaging component contains (e.g. "25 cl")
- recycling: whether the packaging component should be recycled, discarded or reused

The "shape" and "material" fields are taxonomized using the packaging_shapes and packaging_materials taxonomies.

### How the the resulting packagings data structure is created

#### Extract attributes that relate to different packaging components

The values for each input field ("packaging" tag field and "packaging_text_[language code]" packaging information text field) are analyzed[^parse_packaging_from_text_phrase] to recognize packaging components and their attributes. One product may have multiple "packaging_text_[language code]" values in different languages. Only the value for the main product of the language is currently analyzed.

[^parse_packaging_from_text_phrase]: parse_packaging_from_text_phrase() function in [/lib/ProductOpener/Packagings.pm](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/lib/ProductOpener/Packaging.pm)

For instance, if the "packaging" field contains "Plastic bottle, box, cardboard", we will use the packaging shapes, materials and recycling taxonomies to create a list of 3 packaging components: {shape:"en:bottle", material:"en:plastic"}, {shape:"en:box"}, {material:"en:cardboard"}.

And if the "packaging_text_en" field contains "PET bottle to recycle, box to reuse", we will create 2 more packaging components: {shape:"en:bottle", material:"en:pet-polyethylene-terephthalate", recycling:"en:recycle"}, {shape:"box", recycling:"reuse"}.

#### Merge packaging components

The 3 + 2 = 5 resulting packaging components are then added one by one in the packagings structure. When their attributes are compatible, the packaging units are merged[^analyze_and_combine_packaging_data]. For instance {shape:"en:box"} and {material:"en:cardboard"} have non conflicting attributes, so they are merged into {shape:"en:box", material:"en:cardboard"}. Note that it is possible that this is a mistake, and that the "box" and "cardboard" tags concern in fact different components.

[^analyze_and_combine_packaging_data]: analyze_and_combine_packaging_data() function in [/lib/ProductOpener/Packagings.pm](https://github.com/openfoodfacts/openfoodfacts-server/blob/main/lib/ProductOpener/Packaging.pm)

Similarly, as "en:plastic" is a parent of "en:pet-polyethylene-terephthalate" in the packaging_materials taxonomy, we can merge {shape:"en:bottle", material:"en:plastic"} with {shape:"en:bottle", material:"en:pet-polyethylene-terephthalate", recycling:"en:recycle"} into {shape:"en:bottle", material:"en:pet-polyethylene-terephthalate", recycling:"en:recycle"}.

The resulting structure is:

```
packagings: [
    {
        material: "en:pet-polyethylene-terephthalate",
        recycling: "en:recycle",
        shape: "en:bottle"
    },
    {
        recycling: "en:reuse",
        shape: "en:box"
    },
    {
        shape: "en:container"
    }
]
```

### Taxonomies

We have created a number of multilingual taxonomies related to packagings:

- Packaging shapes taxonomy : https://github.com/openfoodfacts/openfoodfacts-server/blob/main/taxonomies/packaging_shapes.txt
- Packaging materials taxonomy : https://github.com/openfoodfacts/openfoodfacts-server/blob/main/taxonomies/packaging_materials.txt
- Packaging recycling taxonomy : https://github.com/openfoodfacts/openfoodfacts-server/blob/main/taxonomies/packaging_recycling.txt
- Preservation methods taxonomy (related) : https://github.com/openfoodfacts/openfoodfacts-server/blob/main/taxonomies/preservation.txt

Those taxonomies are used to structure packaging data in Open Food Facts, and to analyze unstructured input data.

## How we could improve it

### Extend the attributes of the packaging components in the "packagings" data structure

#### Weight

We need to add an attribute for the weight of the packaging component. We might need to add different fields to distinguish values that have been entered by users that weight the packaging, versus values provided by the manufacturer, or average values that we have determined from other products, or that we got from external sources.

### Make the "packagings" data structure READ and WRITE

The "packagings" data structure is currently a READ only field. We could create an API to make it a READ and WRITE field.

For new products, clients (website and apps) could ask users to enter data about all packaging components of the product.

For existing products, clients could display the packaging components and let users change them (e.g. adding or removing components, entering values for new attributes, editing attributes to add more precise values (e.g. which type of plastic) etc.).

#### Add a way to indicate that the "packagings" data structure contains all the packaging components of the product

We currently have no way to know if the packaging data we have for a product is complete, or if we may be missing some packaging components.

We could have a way (e.g. a checkbox) that users could use to indicate all components are accounted for. And we could also do the reverse, and indicate that it is very likely that we are missing some packaging components (e.g. if we have a "cap" but no other component to put the cap on).

### Deprecate the "packaging" tags field

We could discard the existing "packaging" tags field, and replace it with an API to allow clients to add partial information about packaging components.

For instance, if Robotoff detects that the product is in plastic bottle by analyzing a product photo, it could send {shape:"bottle", material:"en:plastic"} and it would be added / combined with the existing "packagings" data.

### Keep the "packaging_text_[language code]" field

It is important to keep this field, as we can display it as-is, use it as input data, and it may contain interesting data that we do not analyze yet.

When filled, the values for this field can be analyzed and added to / combined with the "packagings" data structure. Similarly to ingredient text analysis, we could keep information about which parts of the text were recognized as attributes of a packaging component, and which parts were not recognized and were therefore ignored.

Changing the "packagings" value will not change the "packaging_text_[language code]" values.

## Challenges

### Incomplete lists of packaging components

### Slightly mismatched data from different sources

For a single product, we might get partial packaging data from different sources that we map to similar but distinct shapes, like "bottle", "jar" and "jug". It may be difficult to determine if the data concerns a single packaging component, or different components.

### Products with packaging changes

## Resources

- 2020 project to start structuring packaging data: https://wiki.openfoodfacts.org/Packagings_data_structure
