const fs = require("fs")
const directoryPath = "/srv2/off-pro/equadis-data-tmp/"

function requireUncached(module){
    delete require.cache[require.resolve(module)]
    return require(module)
}

const xml2csv = requireUncached('@wmfs/xml2csv')

const filter = /\.xml$/

fs.readdir(directoryPath, function(err, files) {
  if (err) {
    console.log("Error getting directory information.")
  } else {
    files.forEach(function(file) {

     if (filter.test(file)) {

xml2csv(
  {
    xmlPath: directoryPath+file,
    csvPath: directoryPath+file.replace('.xml','.csv'),
    rootXMLElement: 'tradeItem',
    headerMap: [
      ['gtin.0', 'gs1.gtin', 'string'],
      ['isTradeItemAConsumerUnit.0', 'gs1.isTradeItemAConsumerUnit', 'boolean'],
      ['gln.0', 'gs1.gln', 'string', 'informationProviderOfTradeItem.0'],
      ['partyName.0', 'gs1.partyName', 'string', 'informationProviderOfTradeItem.0'],
      ['gpcCategoryCode.0', 'gs1.gpcCategoryCode', 'string', 'gdsnTradeItemClassification.0'],
      ['gpcCategoryName.0', 'gs1.gpcCategoryName', 'string', 'gdsnTradeItemClassification.0'],
      ['additionalTradeItemClassificationSystemCode.0', 'gs1.additionalTradeItemClassificationSystemCode', 'string', 'gdsnTradeItemClassification.0.additionalTradeItemClassification.0'],
      ['additionalTradeItemClassificationCodeValue.0', 'gs1.additionalTradeItemClassificationCodeValue', 'string', 'gdsnTradeItemClassification.0.additionalTradeItemClassification.0.additionalTradeItemClassificationValue.0'],
      ['additionalTradeItemClassificationCodeDescription.0', 'gs1.additionalTradeItemClassificationCodeDescription', 'string', 'gdsnTradeItemClassification.0.additionalTradeItemClassification.0.additionalTradeItemClassificationValue.0'],
      ['targetMarketCountryCode.0', 'gs1.targetMarketCountryCode', 'string', 'targetMarket.0'],
      ['contactAddress.0', 'gs1.tradeItemContactInformation.contactAddress', 'string', 'tradeItemContactInformation.0'],
      ['descriptionShort.0', 'gs1.descriptionShort', 'string', 'tradeItemInformation.0.extension.0.trade_item_description:tradeItemDescriptionModule.0.tradeItemDescriptionInformation.0'],
      ['functionalName.0', 'gs1.functionalName', 'string', 'tradeItemInformation.0.extension.0.trade_item_description:tradeItemDescriptionModule.0.tradeItemDescriptionInformation.0'],
      ['invoiceName.0', 'gs1.invoiceName',  'string', 'tradeItemInformation.0.extension.0.trade_item_description:tradeItemDescriptionModule.0.tradeItemDescriptionInformation.0'],
      ['regulatedProductName.0', 'gs1.regulatedProductName', 'string', 'tradeItemInformation.0.extension.0.trade_item_description:tradeItemDescriptionModule.0.tradeItemDescriptionInformation.0'],
      ['tradeItemDescription.0', 'gs1.tradeItemDescription', 'string', 'tradeItemInformation.0.extension.0.trade_item_description:tradeItemDescriptionModule.0.tradeItemDescriptionInformation.0'],
      ['variantDescription.0', 'gs1.variantDescription', 'string', 'tradeItemInformation.0.extension.0.trade_item_description:tradeItemDescriptionModule.0.tradeItemDescriptionInformation.0'],
      ['brandName.0', 'gs1.brandName', 'string', 'tradeItemInformation.0.extension.0.trade_item_description:tradeItemDescriptionModule.0.tradeItemDescriptionInformation.0.brandNameInformation.0'],
      ['netContent.0', 'gs1.netContent', 'string', 'tradeItemInformation.0.extension.0.trade_item_measurements:tradeItemMeasurementsModule.0.tradeItemMeasurements.0'],
      ['netWeight.0', 'gs1.netWeight', 'string', 'tradeItemInformation.0.extension.0.trade_item_measurements:tradeItemMeasurementsModule.0.tradeItemMeasurements.0.tradeItemWeight.0'],

      ['startAvailabilityDateTime.0', 'gs1.startAvailabilityDateTime', 'string', 'tradeItemInformation.0.extension.0.delivery_purchasing_information:deliveryPurchasingInformationModule.0.deliveryPurchasingInformation.0'],
      ['lastChangeDateTime.0','gs1.lastChangeDateTime', 'string', 'tradeItemSynchronisationDates.0'],
      ['effectiveDateTime.0','gs1.effectiveDateTime', 'string', 'tradeItemSynchronisationDates.0'],
      ['publicationDateTime.0','gs1.publicationDateTime', 'string', 'tradeItemSynchronisationDates.0'],

      ['allergenStatement.0', 'gs1.allergenStatement', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0'],
      ['allergenTypeCode.0', 'gs1.allergenTypeCode0', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.0'],
      ['levelOfContainmentCode.0', 'gs1.levelOfContainmentCode0', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.0'],
      ['allergenTypeCode.0', 'gs1.allergenTypeCode1', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.1'],
      ['levelOfContainmentCode.0', 'gs1.levelOfContainmentCode1', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.1'],
      ['allergenTypeCode.0', 'gs1.allergenTypeCode2', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.2'],
      ['levelOfContainmentCode.0', 'gs1.levelOfContainmentCode2', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.2'],
      ['allergenTypeCode.0', 'gs1.allergenTypeCode3', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.3'],
      ['levelOfContainmentCode.0', 'gs1.levelOfContainmentCode3', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.3'],
      ['allergenTypeCode.0', 'gs1.allergenTypeCode4', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.4'],
      ['levelOfContainmentCode.0', 'gs1.levelOfContainmentCode4', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.4'],
      ['allergenTypeCode.0', 'gs1.allergenTypeCode5', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.5'],
      ['levelOfContainmentCode.0', 'gs1.levelOfContainmentCode5', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.5'],
      ['allergenTypeCode.0', 'gs1.allergenTypeCode6', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.6'],
      ['levelOfContainmentCode.0', 'gs1.levelOfContainmentCode6', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.6'],
      ['allergenTypeCode.0', 'gs1.allergenTypeCode7', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.7'],
      ['levelOfContainmentCode.0', 'gs1.levelOfContainmentCode7', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.7'],
      ['allergenTypeCode.0', 'gs1.allergenTypeCode8', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.8'],
      ['levelOfContainmentCode.0', 'gs1.levelOfContainmentCode8', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.8'],
      ['allergenTypeCode.0', 'gs1.allergenTypeCode9', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.9'],
      ['levelOfContainmentCode.0', 'gs1.levelOfContainmentCode9', 'string', 'tradeItemInformation.0.extension.0.allergen_information:allergenInformationModule.0.allergenRelatedInformation.0.allergen.9'],
      ['ingredientStatement.0', 'gs1.ingredientStatement', 'string', 'tradeItemInformation.0.extension.0.food_and_beverage_ingredient:foodAndBeverageIngredientModule.0'],
      ['isNutrientRelevantDataProvided.0', 'gs1.isNutrientRelevantDataProvided', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0'],
      ['preparationStateCode.0', 'gs1.preparationStateCode', 'string' , 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0'],
      ['servingSize.0', 'gs1.servingSize', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0'],

      ['nutrientTypeCode.0', 'gs1.nutrientTypeCode0', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.0'],
      ['measurementPrecisionCode.0', 'gs1.measurementPrecisionCode0', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.0'],
      ['quantityContained.0', 'gs1.quantityContained0', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.0'],

      ['nutrientTypeCode.0', 'gs1.nutrientTypeCode1', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.1'],
      ['measurementPrecisionCode.0', 'gs1.measurementPrecisionCode1', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.1'],
      ['quantityContained.0', 'gs1.quantityContained1', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.1'],

      ['nutrientTypeCode.0', 'gs1.nutrientTypeCode2', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.2'],
      ['measurementPrecisionCode.0', 'gs1.measurementPrecisionCode2', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.2'],
      ['quantityContained.0', 'gs1.quantityContained2', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.2'],

      ['nutrientTypeCode.0', 'gs1.nutrientTypeCode3', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.3'],
      ['measurementPrecisionCode.0', 'gs1.measurementPrecisionCode3', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.3'],
      ['quantityContained.0', 'gs1.quantityContained3', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.3'],

      ['nutrientTypeCode.0', 'gs1.nutrientTypeCode4', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.4'],
      ['measurementPrecisionCode.0', 'gs1.measurementPrecisionCode4', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.4'],
      ['quantityContained.0', 'gs1.quantityContained4', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.4'],

      ['nutrientTypeCode.0', 'gs1.nutrientTypeCode5', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.5'],
      ['measurementPrecisionCode.0', 'gs1.measurementPrecisionCode5', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.5'],
      ['quantityContained.0', 'gs1.quantityContained5', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.5'],

      ['nutrientTypeCode.0', 'gs1.nutrientTypeCode6', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.6'],
      ['measurementPrecisionCode.0', 'gs1.measurementPrecisionCode6', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.6'],
      ['quantityContained.0', 'gs1.quantityContained6', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.6'],

      ['nutrientTypeCode.0', 'gs1.nutrientTypeCode7', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.7'],
      ['measurementPrecisionCode.0', 'gs1.measurementPrecisionCode7', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.7'],
      ['quantityContained.0', 'gs1.quantityContained7', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.7'],

      ['nutrientTypeCode.0', 'gs1.nutrientTypeCode8', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.8'],
      ['measurementPrecisionCode.0', 'gs1.measurementPrecisionCode8', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.8'],
      ['quantityContained.0', 'gs1.quantityContained8', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.8'],

      ['nutrientTypeCode.0', 'gs1.nutrientTypeCode9', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.9'],
      ['measurementPrecisionCode.0', 'gs1.measurementPrecisionCode9', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.9'],
      ['quantityContained.0', 'gs1.quantityContained9', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.9'],

      ['nutrientTypeCode.0', 'gs1.nutrientTypeCode10', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.10'],
      ['measurementPrecisionCode.0', 'gs1.measurementPrecisionCode10', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.10'],
      ['quantityContained.0', 'gs1.quantityContained10', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.10'],

      ['nutrientTypeCode.0', 'gs1.nutrientTypeCode11', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.11'],
      ['measurementPrecisionCode.0', 'gs1.measurementPrecisionCode11', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.11'],
      ['quantityContained.0', 'gs1.quantityContained11', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.11'],

      ['nutrientTypeCode.0', 'gs1.nutrientTypeCode12', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.12'],
      ['measurementPrecisionCode.0', 'gs1.measurementPrecisionCode12', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.12'],
      ['quantityContained.0', 'gs1.quantityContained12', 'string', 'tradeItemInformation.0.extension.0.nutritional_information:nutritionalInformationModule.0.nutrientHeader.0.nutrientDetail.12'],

      ['packagingTypeCode.0', 'gs1.packagingTypeCode', 'string', 'tradeItemInformation.0.extension.0.packaging_information:packagingInformationModule.0.packaging.0'],
      ['packagingMarkedLabelAccreditationCode.0','gs1.packagingMarkedLabelAccreditationCode.0', 'string', 'tradeItemInformation.0.extension.0.packaging_marking:packagingMarkingModule.0.packagingMarking.0'],
      ['packagingMarkedLabelAccreditationCode.1','gs1.packagingMarkedLabelAccreditationCode.1', 'string', 'tradeItemInformation.0.extension.0.packaging_marking:packagingMarkingModule.0.packagingMarking.0'],
      ['packagingMarkedLabelAccreditationCode.2','gs1.packagingMarkedLabelAccreditationCode.2', 'string', 'tradeItemInformation.0.extension.0.packaging_marking:packagingMarkingModule.0.packagingMarking.0'],
      ['packagingMarkedLabelAccreditationCode.3','gs1.packagingMarkedLabelAccreditationCode.3', 'string', 'tradeItemInformation.0.extension.0.packaging_marking:packagingMarkingModule.0.packagingMarking.0'],
      ['packagingMarkedLabelAccreditationCode.4','gs1.packagingMarkedLabelAccreditationCode.4', 'string', 'tradeItemInformation.0.extension.0.packaging_marking:packagingMarkingModule.0.packagingMarking.0'],

      ['preparationInstructions.0', 'gs1.preparationInstructions', 'string', 'tradeItemInformation.0.extension.0.food_and_beverage_preparation_serving:foodAndBeveragePreparationServingModule.0.preparationServing.0'],
      ['consumerStorageInstructions.0', 'gs1.consumerStorageInstructions', 'string', 'tradeItemInformation.0.extension.0.consumer_instructions:consumerInstructionsModule.0.consumerInstructions.0'],

      ['uniformResourceIdentifier.0', 'gs1.uniformResourceIdentifier.0', 'string', 'tradeItemInformation.0.extension.0.referenced_file_detail_information:referencedFileDetailInformationModule.0.referencedFileHeader.0'],
      ['uniformResourceIdentifier.0', 'gs1.uniformResourceIdentifier.1', 'string', 'tradeItemInformation.0.extension.0.referenced_file_detail_information:referencedFileDetailInformationModule.0.referencedFileHeader.1'],
      ['uniformResourceIdentifier.0', 'gs1.uniformResourceIdentifier.2', 'string', 'tradeItemInformation.0.extension.0.referenced_file_detail_information:referencedFileDetailInformationModule.0.referencedFileHeader.2'],
      ['uniformResourceIdentifier.0', 'gs1.uniformResourceIdentifier.3', 'string', 'tradeItemInformation.0.extension.0.referenced_file_detail_information:referencedFileDetailInformationModule.0.referencedFileHeader.3'],
      ['uniformResourceIdentifier.0', 'gs1.uniformResourceIdentifier.4', 'string', 'tradeItemInformation.0.extension.0.referenced_file_detail_information:referencedFileDetailInformationModule.0.referencedFileHeader.4'],
      ['uniformResourceIdentifier.0', 'gs1.uniformResourceIdentifier.5', 'string', 'tradeItemInformation.0.extension.0.referenced_file_detail_information:referencedFileDetailInformationModule.0.referencedFileHeader.5'],
      ['uniformResourceIdentifier.0', 'gs1.uniformResourceIdentifier.6', 'string', 'tradeItemInformation.0.extension.0.referenced_file_detail_information:referencedFileDetailInformationModule.0.referencedFileHeader.6'],
      ['uniformResourceIdentifier.0', 'gs1.uniformResourceIdentifier.7', 'string', 'tradeItemInformation.0.extension.0.referenced_file_detail_information:referencedFileDetailInformationModule.0.referencedFileHeader.7'],
      ['uniformResourceIdentifier.0', 'gs1.uniformResourceIdentifier.8', 'string', 'tradeItemInformation.0.extension.0.referenced_file_detail_information:referencedFileDetailInformationModule.0.referencedFileHeader.8'],
      ['uniformResourceIdentifier.0', 'gs1.uniformResourceIdentifier.9', 'string', 'tradeItemInformation.0.extension.0.referenced_file_detail_information:referencedFileDetailInformationModule.0.referencedFileHeader.9'],
      ['uniformResourceIdentifier.0', 'gs1.uniformResourceIdentifier.10', 'string', 'tradeItemInformation.0.extension.0.referenced_file_detail_information:referencedFileDetailInformationModule.0.referencedFileHeader.10'],
      ['uniformResourceIdentifier.0', 'gs1.uniformResourceIdentifier.11', 'string', 'tradeItemInformation.0.extension.0.referenced_file_detail_information:referencedFileDetailInformationModule.0.referencedFileHeader.11'],
      ['uniformResourceIdentifier.0', 'gs1.uniformResourceIdentifier.12', 'string', 'tradeItemInformation.0.extension.0.referenced_file_detail_information:referencedFileDetailInformationModule.0.referencedFileHeader.12'],
      ['uniformResourceIdentifier.0', 'gs1.uniformResourceIdentifier.13', 'string', 'tradeItemInformation.0.extension.0.referenced_file_detail_information:referencedFileDetailInformationModule.0.referencedFileHeader.13'],
      ['uniformResourceIdentifier.0', 'gs1.uniformResourceIdentifier.14', 'string', 'tradeItemInformation.0.extension.0.referenced_file_detail_information:referencedFileDetailInformationModule.0.referencedFileHeader.14']
    ],
  },
  function (err, info) {
    console.log(file)
    console.log(err, info)
    // Done!
  })
     }
    })
  }
})

