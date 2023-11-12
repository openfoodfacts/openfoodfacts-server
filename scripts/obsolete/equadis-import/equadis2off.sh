#!/bin/bash

# requires miller >=5.0 (stretch-backports or buster) for unsparsify

tfile=$(mktemp /tmp/off-XXXXXXXXX.csv)

mlr --csv unsparsify /srv2/off-pro/equadis-data-tmp/*.csv >$tfile
mlr -I --csv filter '${gs1.isTradeItemAConsumerUnit} != "false"' \
    then cut -x -f 'gs1.isTradeItemAConsumerUnit' $tfile

# Commenting the non-food filter so that we can move products to OBF, OPF etc.
# I couldn't find a way to make word boundaries work, in order to match full names only
#mlr -I --csv filter '(${gs1.functionalName} !=~ "(bloc wc|dentifrice|deodorant|déo|déodorant|douche|huile à barbe|lave vaisselle|lave-vaisselle|lessive|nettoyant|rasage|raser|savon|shampo|soap|soin barbe|soin visage|toilette|transpirant)"i);' $tfile

# Deduplicate keeping only the latest version of each product
mlr -I --csv put -S -q '@records[NR] = $*;
        @maxdate[${gs1.gtin}] = max(@maxdate[${gs1.gtin}], ${gs1.publicationDateTime});
    end {
        for (int nr in @records) {
        map record = @records[nr];
        if (record["gs1.publicationDateTime"] == @maxdate[record["gs1.gtin"]]) {
            emit record;
        }}}' $tfile


# Code
mlr -I --csv put -S '$code=${gs1.gtin}' \
  then cut -x -f 'gs1.gtin' $tfile

# GS1 id and name
mlr -I --csv put -S '${sources_fields:org-gs1:gln}=${gs1.gln}' \
  then cut -x -f 'gs1.gln' $tfile

# Set the org_name field to gs1.partyName to assign the organization
mlr -I --csv put -S '${sources_fields:org-gs1:partyName}=${gs1.partyName};
                     $org_name=${gs1.partyName}' \
  then cut -x -f 'gs1.partyName' $tfile

# Product Name
# Discarded candidates for product name:
# gs1.descriptionShort,gs1.invoiceName,gs1.variantDescription
# experimentaly on Unilever data, gs1.tradeItemDescription is cleaner
mlr -I --csv put -S '$product_name_fr="";
                     @nam=splitnvx(${gs1.tradeItemDescription}, "§");
                     if (@nam[2]=="languageCode=fr")
                        { $product_name_fr=@nam[1] }' \
  then cut -x -f 'gs1.tradeItemDescription' \
  then cut -x -f 'gs1.descriptionShort' \
  then cut -x -f 'gs1.invoiceName' \
  then cut -x -f 'gs1.variantDescription' $tfile


# Generic Name
mlr -I --csv put -S '$generic_name_fr="";
                     @rna=splitnvx(${gs1.regulatedProductName}, "§");
                     if (@rna[2]=="languageCode=fr")
                        { $generic_name_fr=@rna[1] }' \
  then cut -x -f 'gs1.regulatedProductName' $tfile

# Quantity / Net Weight
# Discarded candidate for Net Weight:
# gs1.netWeight
# experimentaly on Unilever data, gs1.netContent is better
mlr -I --csv put -S '$quantity_value=""; $quantity_unit="";
                     @wei=splitnvx(${gs1.netContent}, "§");
                     $quantity_value=@wei[1];
                     $quantity_unit=sub(@wei[2], "measurementUnitCode=", "gs1:T3780:");' \
  then cut -x -f 'gs1.netContent' \
  then cut -x -f 'gs1.netWeight' $tfile

# Brand
 mlr -I --csv put -S '$brands=${gs1.brandName}' \
   then cut -x -f 'gs1.brandName' $tfile

# Country
mlr -I --csv put -S '$countries = "gs1:T3783:".${gs1.targetMarketCountryCode}' \
  then cut -x -f 'gs1.targetMarketCountryCode' $tfile

# Packaging
mlr -I --csv put -S '$packaging = "gs1:T0137:".${gs1.packagingTypeCode}' \
  then cut -x -f 'gs1.packagingTypeCode' $tfile


# Labels
# labels gs1.packagingMarkedLabelAccreditationCode.k
mlr -I --csv put -S '$labels=""; @lab="";
                      for (int k = 0; k < 5; k += 1)
                          { if ($["gs1.packagingMarkedLabelAccreditationCode.".k] != "")
                                { @lab[k]=$["gs1.packagingMarkedLabelAccreditationCode.".k] }
                          };
                          if (is_map(@lab))
                              {$labels=joinv(@lab, ",")}
                          else {$labels=""};' \
  then cut -x -r -f '"gs1.packagingMarkedLabelAccreditationCode..*$"' $tfile





# Ingredients
mlr -I --csv put -S '$ingredients_text_fr="";
                     @ing=splitnvx(${gs1.ingredientStatement},"§");
                     if (@ing[2]=="languageCode=fr")
                         {$ingredients_text_fr=@ing[1]}' \
  then cut -x -f 'gs1.ingredientStatement' $tfile

# Categories
# * store gs1.gpcCategoryCode and gs1.gpcCategoryName as is in sources_fields:org-gs1 fields
# so that they are available for later use / further matching
# * use other fields as candidates for categories, they will be imported if they match
# the OFF categories taxonomy:
# - gs1.gpcCategoryName: some can match as-is
# - gs1.functionalName: may contain a good category name for some producers (e.g. Unilever)
# but contains a very specific product name for some other producers (e.g. Naturenvie / Lea Nature)

mlr -I --csv put -S '$categories_if_match_in_taxonomy=${gs1.gpcCategoryName};
                     ${sources_fields:org-gs1:gpcCategoryCode}=${gs1.gpcCategoryCode};
                     ${sources_fields:org-gs1:gpcCategoryName}=${gs1.gpcCategoryName}' \
  then cut -x -f 'gs1.gpcCategoryCode' \
  then cut -x -f 'gs1.gpcCategoryName' \
  then cut -x -f 'gs1.additionalTradeItemClassificationSystemCode' \
  then cut -x -f 'gs1.additionalTradeItemClassificationCodeValue' \
  then cut -x -f 'gs1.additionalTradeItemClassificationCodeDescription' $tfile

mlr -I --csv put -S '${categories_if_match_in_taxonomy.2}="";
                     @cat=splitnvx(${gs1.functionalName},  "§");
                     if (@cat[2]=="languageCode=fr")
                         { ${categories_if_match_in_taxonomy.2}="fr:".@cat[1] }' \
  then cut -x -f 'gs1.functionalName' $tfile


# Allergens
# Discarded candidates for Allergens
# allergenStatement (mixes ingredients and traces)
# experimentaly on Unilever data, gs1.allergenTypeCode
# and gs1.levelOfContainmentCode are better
mlr -I --csv put -S '$allergens=""; $traces=""; @trac=""; @aller="";
                     for (int k = 0; k < 10; k += 1)
                         { if ($["gs1.allergenTypeCode".k] != "")
                             { if ($["gs1.levelOfContainmentCode".k] == "MAY_CONTAIN")
                                 { @trac[k]="gs1:T4078:".$["gs1.allergenTypeCode".k] }
                             elif ($["gs1.levelOfContainmentCode".k] == "CONTAINS")
                                 { @aller[k]="gs1:T4078:".$["gs1.allergenTypeCode".k] }
                             }
                         };
                         if (is_map(@trac))
                             {$traces=joinv(@trac, ",")}
                         else {$traces=""};
                         if (is_map(@aller))
                             {$allergens=joinv(@aller, ",")}
                         else {$allergens=""};' \
  then cut -x -r -f '"^gs1.allergenStatement$"' \
  then cut -x -r -f '"^gs1.levelOfContainmentCode[0-9]$"' \
  then cut -x -r -f '"^gs1.allergenTypeCode[0-9]$"' $tfile

# Nutrients


# unreliable for Unilever data (always true)
mlr -I --csv put -S '$no_nutrition_data="";
                     if (${gs1.isNutrientRelevantDataProvided}=="true") {
                         $no_nutrition_data="false"
                     } else {
                         $no_nutrition_data="true"
                     }' \
  then cut -x -f 'gs1.isNutrientRelevantDataProvided' $tfile

mlr -I --csv put -S '
  ${nutrition_data_per}="";
  ${nutrition_data_prepared_per}="";
  ${energy-kj_value}="";
  ${energy-kj_prepared_value}="";
  ${energy-kj_unit}="";
  ${energy-kcal_value}="";
  ${energy-kcal_prepared_value}="";
  ${energy-kcal_unit}="";
  ${fat_value}="";
  ${fat_prepared_value}="";
  ${fat_unit}="";
  ${saturated-fat_value}="";
  ${saturated-fat_prepared_value}="";
  ${saturated-fat_unit}="";
  ${carbohydrates_value}="";
  ${carbohydrates_prepared_value}="";
  ${carbohydrates_unit}="";
  ${sugars_value}="";
  ${sugars_prepared_value}="";
  ${sugars_unit}="";
  ${proteins_value}="";
  ${proteins_prepared_value}="";
  ${proteins_unit}="";
  ${salt_value}="";
  ${salt_prepared_value}="";
  ${salt_unit}="";
  ${monounsaturated-fat_value}="";
  ${monounsaturated-fat_prepared_value}="";
  ${monounsaturated-fat_unit}="";
  ${polyunsaturated-fat_value}="";
  ${polyunsaturated-fat_prepared_value}="";
  ${polyunsaturated-fat_unit}="";
  ${fiber_value}="";
  ${fiber_prepared_value}="";
  ${fiber_unit}="";
  ${vitamin-a_value}="";
  ${vitamin-a_prepared_value}="";
  ${vitamin-a_unit}="";
  ${vitamin-d_value}="";
  ${vitamin-d_prepared_value}="";
  ${vitamin-d_unit}="";
  ${vitamin-b6_value}="";
  ${vitamin-b6_prepared_value}="";
  ${vitamin-b6_unit}="";
  ${sodium_value}="";
  ${sodium_prepared_value}="";
  ${sodium_unit}="";

  @tabnut="";

  @prep="";
  if (${gs1.preparationStateCode} == "PREPARED") {@prep="_prepared"};

  if (${gs1.servingSize} != "") {
      $["nutrition_data".@prep."_per"]=sub(${gs1.servingSize}, "§measurementUnitCode=", " gs1:T3780:")
  }

  # special case for energy (kJ vs kcal)
  for (int k = 0; k < 13; k += 1) {
    if ($["gs1.nutrientTypeCode".k] == "ENER-") {
      @energy=splitnvx($["gs1.quantityContained".k],"§");
      if (@energy[2]=="measurementUnitCode=E14") {
        $["energy-kcal".@prep."_value"]=@energy[1];
        ${energy-kcal_unit}="kcal"
      } elif (@energy[2]=="measurementUnitCode=KJO") {
        $["energy-kj".@prep."_value"]=@energy[1];
        ${energy-kj_unit}="kJ"
      }
    }
  }

  # General case for all other nutrients
  func f(gs1nutname, offnutname, sprep) {
    for (int k = 0; k < 13; k += 1) {
      if ($["gs1.nutrientTypeCode".k] != "") {
        if ($["gs1.nutrientTypeCode".k] == gs1nutname) {
          @nut=splitnvx($["gs1.quantityContained".k],"§");
          @tabnut[offnutname.sprep."_value"]=@nut[1];
          if ($["gs1.measurementPrecisionCode".k]=="LESS_THAN") {
            @tabnut[offnutname.sprep."_value"]="< ".@nut[1]
          } else {
            @tabnut[offnutname.sprep."_value"]=@nut[1];
          }
          @tabnut[offnutname."_unit"]=sub(@nut[2], "measurementUnitCode=", "gs1:T3780:");}}};}

  # reference: GS1 T4073 Nutrient type code
  f("FAT","fat",@prep);
  f("FASAT","saturated-fat",@prep);
  f("CHOAVL","carbohydrates",@prep);
  f("SUGAR-","sugars",@prep);
  f("PRO-","proteins",@prep);
  f("SALTEQ","salt",@prep);
  f("FAMSCIS","monounsaturated-fat",@prep);
  f("FAPUCIS","polyunsaturated-fat",@prep);
  f("FIBTG","fiber",@prep);
  f("VITA-","vitamin-a",@prep);
  f("VITB6-","vitamin-b6",@prep);
  f("VITD-","vitamin-d",@prep);
  f("NA","sodium",@prep);

  for(key, val in @tabnut) {
     $[key]=val
  }' \
  then cut -x -r -f '"^gs1.preparationStateCode$"' \
  then cut -x -r -f '"^gs1.servingSize$"' \
  then cut -x -r -f '"^gs1.nutrientTypeCode[0-9]*$"' \
  then cut -x -r -f '"^gs1.measurementPrecisionCode[0-9]*$"' \
  then cut -x -r -f '"^gs1.quantityContained[0-9]*$"' $tfile



# Customer Service
mlr -I --csv put -S '$customer_service_fr=${gs1.tradeItemContactInformation.contactAddress}' \
  then cut -x -f 'gs1.tradeItemContactInformation.contactAddress' $tfile

# conservation_conditions
mlr -I --csv put -S '$conservation_conditions_fr="";
                     @con=splitnvx(${gs1.consumerStorageInstructions},"§");
                     if (@con[2]=="languageCode=fr")
                         {$conservation_conditions_fr=@con[1]}' \
  then cut -x -f 'gs1.consumerStorageInstructions' $tfile

# preparation
mlr -I --csv put -S '$preparation_fr="";
                     @prep=splitnvx(${gs1.preparationInstructions},"§");
                     if (@prep[2]=="languageCode=fr")
                         {$preparation_fr=@prep[1]}' \
  then cut -x -f 'gs1.preparationInstructions' $tfile

# Dates
# NB: gs1.publicationDateTime was also used to deduplicate
mlr -I --csv put -S '$producer_version_id=${gs1.publicationDateTime}' \
  then cut -x -f 'gs1.publicationDateTime' \
  then cut -x -f 'gs1.effectiveDateTime' \
  then cut -x -f 'gs1.lastChangeDateTime' \
  then cut -x -f 'gs1.startAvailabilityDateTime'  $tfile

# Images
# in the case of Unilever data, there is no indication of which image is which
# we just assume that the first one is FRONT
# (front|ingredients|nutrition|other) _ language code _ url -> front_fr_url
#mlr -I --csv put -S '$front_fr_url=${gs1.uniformResourceIdentifier.0}' \
#  then cut -x -f 'gs1.uniformResourceIdentifier.0' $tfile

#mlr -I --csv put -S '$image_other_fr_url=""; @photo;
#                     for (int k = 1; k < 15; k += 1)
#                         { if ($["gs1.uniformResourceIdentifier.".k] != "")
#                               { @photo[k]=$["gs1.uniformResourceIdentifier.".k] }
#                         };
#                         if (is_map(@photo))
#                             {$image_other_fr_url=joinv(@photo, ",")}
#                         else {$image_other_fr_url=""};' \
# then cut -x -r -f '"gs1.uniformResourceIdentifier..*$"' $tfile


mlr -I --csv put -S '  for (int k = 0; k < 15; k += 1)
                         { $["image_other_fr_url.".k]="";}
                       for (int k = 0; k < 15; k += 1)
                           { if ($["gs1.uniformResourceIdentifier.".k] != "")
                                 { $["image_other_fr_url.".k]=$["gs1.uniformResourceIdentifier.".k]; }
                           };' \
   then cut -x -r -f '"gs1.uniformResourceIdentifier..*$"' $tfile


# mlr -I --csv cut -x -r -f '"^gs1."' $tfile

# convert to TSV and output
mlr --c2t cat $tfile

rm $tfile

