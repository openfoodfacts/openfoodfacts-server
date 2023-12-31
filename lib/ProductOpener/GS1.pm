# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# This package is used to convert CSV or XML file sent by producers to
# an Open Food Facts CSV file that can be loaded with import_csv_file.pl / Import.pm

=head1 NAME

ProductOpener::GS1 - convert data from GS1 Global Data Synchronization Network (GDSN) to the Open Food Facts format.

=head1 SYNOPSIS

=head1 DESCRIPTION

This module converts GDSN data that has previously been converted to JSON
(either from XML with xml2json (e.g. Equadis data), or from JSON provided by a GDSN partner (e.g. CodeOnline)
to the Open Food Facts CSV format.

The conversion is configured through the %gs1_to_off structure to indicate which source field maps to which target field.

And the %gs1_maps translate the GS1 specific identifiers (e.g. for allergens or units) to OFF identifiers.

=cut

package ProductOpener::GS1;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		%gs1_maps

		&init_csv_fields
		&read_gs1_json_file
		&generate_gs1_message_identifier
		&generate_gs1_confirmation_message
		&write_off_csv_file
		&print_unknown_entries_in_gs1_maps
		&convert_gs1_xml_file_to_json

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Display qw/$tt process_template display_date_iso/;

use JSON::PP;
use boolean;
use Data::DeepAccess qw(deep_get);
use XML::XML2JSON;

=head1 GS1 MAPS

GS1 uses many different codes for allergens, packaging etc.
We need to map the different values to the values we use in the taxonomies.

The GS1 standards are evolving, so new values may be introduced over time.

=head2 %unknown_entries_in_gs1_maps

Used to keep track of values we encounter in GS1 data for which we do not have a mapping.

=head2 %gs1_maps

Maps from GS1 to OFF

=cut

my %unknown_entries_in_gs1_maps = ();

# see https://www.gs1.fr/content/download/2265/17736/version/3/file/FicheProduit3.1.9_PROFIL_ParfumerieSelective_20190523.xlsx

%gs1_maps = (

	# https://gs1.se/en/guides/documentation/code-lists/t4078-allergen-type-code/
	allergenTypeCode => {

		"AC" => "Crustaceans",
		"AE" => "Eggs",
		"AF" => "Fish",
		"AM" => "Milk",
		"AN" => "Tree nuts",
		"AP" => "Peanuts",
		"AS" => "Sesame seeds",
		"AU" => "Sulfites",
		"AW" => "Gluten",
		"AX" => "Gluten",
		"AY" => "Soybean",
		"BC" => "Celery",
		"BM" => "Mustard",
		"GB" => "Barley",
		"GK" => "Kamut",
		"GO" => "Oats",
		"GS" => "Spelt",
		"ML" => "Lactose",
		"NL" => "Lupine",
		"NR" => "Rye",
		"SA" => "Almond",
		"SH" => "Hazelnut",
		"SC" => "Cashew",
		"SM" => "Macadamia nut",
		"SP" => "Pecan nut",
		"SQ" => "Queensland nut",
		"SR" => "Brazil nut",
		"ST" => "Pistachio",
		"SW" => "Walnut",
		"UM" => "Molluscs",
		# Shellfish could be Molluscs or Crustaceans
		# "UN" => "Shellfish",
		"UW" => "Wheat",
		"X99" => "None",
	},

	measurementUnitCode => {
		"GRM" => "g",
		"KGM" => "kg",
		"MGM" => "mg",
		"MC" => "mcg",
		"MLT" => "ml",
		"CLT" => "cl",
		"LTR" => "L",
		"E14" => "kcal",
		"KJO" => "kJ",
		"H87" => "pièces",
	},

	# reference: GS1 T4073 Nutrient type code
	# https://gs1.se/en/guides/documentation/test-code-lists/t4073-nutrient-type-code/
	nutrientTypeCode => {
		"BIOT" => "biotin",
		"CA" => "calcium",
		"CASN" => "casein",
		"CHOAVL" => "carbohydrates",
		"CHOCAL" => "vitamin-d",    # cholecalciferol
		"CHOLN" => "choline",
		"CLD" => "chloride",
		"CR" => "chromium",
		"CU" => "copper",
		"ENER-" => "energy",
		"ENERSF" => "calories-from-saturated-fat",
		"ERYTHL" => "erythritol",
		"F18D2CN6" => "linoleic-acid",
		"F18D3N3" => "alpha-linolenic-acid",
		"F20D4" => "arachidonic-acid",
		"F20D5N3" => "eicosapentaenoic-acid",
		"F22D6N3" => "docosahexaenoic-acid",
		"FAT" => "fat",
		"FASAT" => "saturated-fat",
		"FAMSCIS" => "monounsaturated-fat",
		"FAPUCIS" => "polyunsaturated-fat",
		"FAPUN3" => "omega-3-fat",
		"FAPUN6" => "omega-6-fat",
		"FD" => "fluoride",
		"FE" => "iron",
		"FIBSOL" => "soluble-fiber",
		"FIBTG" => "fiber",
		"FIB-" => "fiber",
		"FOL" => "folates",
		"FOLDFE" => "vitamin-b9",
		"FRUFB" => "fructo-oligosaccharide",
		"GALFB" => "galacto-oligosaccharide",
		# G_ entries: cigarettes?
		#"G_CMO" => "carbon-monoxide",
		#"G_HC" => "bicarbonate",
		#"G_NICT" => "nicotine",
		#"G_NMES" => "non-milk-extrinsic-sugars",
		#"G_TAR" => "tar",
		"GINSENG" => "ginseng",
		"HMB" => "beta-hydroxy-beta-methylburate",
		"ID" => "iodine",
		"INOTL" => "inositol",
		"IODIZED_SALT" => "iodized_salt",
		"K" => "potassium",
		"L_CARNITINE" => "carnitine",
		"LACS" => "lactose",
		"MALTDEX" => "maltodextrins",
		"MG" => "magnesium",
		"MN" => "manganese",
		"MO" => "molybdenum",
		"NA" => "sodium",
		"NACL" => "nacl",
		"NIA" => "vitamin-pp",
		"NUCLEOTIDE" => "nucleotide",
		"P" => "phosphorus",
		"PANTAC" => "pantothenic-acid",
		"POLYL" => "polyols",
		"POLYLS" => "polyols",
		"PRO-" => "proteins",
		"RIBF" => "vitamin-b2",
		"SALTEQ" => "salt",
		"SE" => "selenium",
		"STARCH" => "starch",
		"SUCS" => "sucrose",
		"SUGAR" => "sugars",
		"SUGAR-" => "sugars",
		"TAU" => "taurine",
		"UNSATURATED_FAT" => "unsaturated-fat",
		"THIA" => "vitamin-b1",
		"THIA-" => "vitamin-b1",
		"VITA-" => "vitamin-a",
		"VITB12" => "vitamin-b12",
		"VITB6-" => "vitamin-b6",
		"VITC-" => "vitamin-c",
		"VITD-" => "vitamin-d",
		"VITE-" => "vitamin-e",
		"VITK-" => "vitamin-k",
		"VITK" => "vitamin-k",
		"WHEY" => "serum-proteins",
		# skipped X_ entries such as X_ACAI_BERRY_EXTRACT
		"ZN" => "zinc",
		"X_FUNS" => "unsaturated-fat",
	},

	packagingTypeCode => {
		"AE" => "en:aerosol",
		"BA" => "en:barrel",
		"BG" => "en:bag",
		"BK" => "en:tray",
		"BO" => "en:bottle",
		"BPG" => "en:film",
		"BRI" => "en:brick",
		"BX" => "en:box",
		"CNG" => "en:can",
		"CR" => "en:crate",
		"CT" => "en:container",
		"EN" => "en:envelope",
		"JR" => "en:jar",
		"PO" => "en:bag",
		"PUG" => "en:carrying-bag",
		"TU" => "en:tube",
		"WRP" => "en:film",
	},

	# http://apps.gs1.org/GDD/Pages/clDetails.aspx?semanticURN=urn:gs1:gdd:cl:PackagingMarkedLabelAccreditationCode
	packagingMarkedLabelAccreditationCode => {
		"ADCCPA" => "fr:produit-certifie",
		"AGENCE_BIO" => "fr:ab-agriculture-biologique",
		"AB_FRANCE" => "fr:ab-agriculture-biologique",
		"AGRICULTURE_BIOLOGIQUE" => "en:organic",
		# mispelling present in many files
		"AGRICULTURE_BIOLIGIQUE" => "en:organic",
		"AGRI_CONFIANCE" => "fr:agri-confiance",
		"APPELLATION_ORIGINE_CONTROLEE" => "fr:aoc",
		"AQUACULTURE_STEWARDSHIP_COUNCIL" => "en:responsible-aquaculture-asc",
		"BLEU_BLANC_COEUR" => "fr:bleu-blanc-coeur",
		"BIO_LABEL_GERMAN" => "de:EG-Öko-Verordnung",
		"BIO_PARTENAIRE" => "fr:biopartenaire",
		"CROSSED_GRAIN_SYMBOL" => "en:crossed-grain-symbol",
		"DEMETER" => "en:demeter",
		"DEMETER_LABEL" => "en:demeter",
		"ECOCERT_CERTIFICATE" => "en:certified-by-ecocert",
		"ETP" => "en:Ethical Tea Partnership",
		"EU_ECO_LABEL" => "en:eu-ecolabel",
		"EU_ORGANIC_FARMING" => "en:eu-organic",
		"EUROPEAN_VEGETARIAN_UNION" => "en:european-vegetarian-union",
		"EUROPEAN_V_LABEL_VEGAN" => "en:european-vegetarian-union-vegan",
		"EUROPEAN_V_LABEL_VEGETARIAN" => "en:european-vegetarian-union-vegetarian",
		"FAIR_TRADE_MARK" => "en:fairtrade-international",
		"FAIRTRADE_COCOA" => "en:fair-trade",
		"FAIR_TRADE_USA" => "en:fairtrade-usa",
		"FOREST_STEWARDSHIP_COUNCIL_LABEL" => "en:fsc",
		"FOREST_STEWARDSHIP_COUNCIL_MIX" => "en:fsc-mix",
		"FOREST_STEWARDSHIP_COUNCIL_RECYCLED" => "en:fsc-recycled",
		"GREEN_DOT" => "en:green-dot",
		"HAUTE_VALEUR_ENVIRONNEMENTALE" => "fr:haute-valeur-environnementale",
		"IGP" => "en:pgi",
		"LABEL_ROUGE" => "fr:label-rouge",
		"LE_PORC_FRANCAIS" => "en:french-pork",
		"MAX_HAVELAAR" => "en:max-havelaar",
		"MARINE_STEWARDSHIP_COUNCIL_LABEL" => "en:sustainable-seafood-msc",
		"ŒUFS_DE_FRANCE" => "en:french-eggs",
		"OEUFS_DE_FRANCE" => "en:french-eggs",
		"ORIGINE_FRANCE_GARANTIE" => "fr:origine-france",
		"POMMES_DE_TERRES_DE_FRANCE" => "en:potatoes-from-france",
		"PRODUIT_EN_BRETAGNE" => "en:produced-in-brittany",
		"PROTECTED_DESIGNATION_OF_ORIGIN" => "en:pdo",
		"PROTECTED_GEOGRAPHICAL_INDICATION" => "en:pgi",
		"PEFC" => "en:pefc",
		"PEFC_CERTIFIED" => "en:pefc",
		"RAINFOREST_ALLIANCE" => "en:rainforest-alliance",
		"SUSTAINABLE_PALM_OIL_RSPO" => "en:roundtable-on-sustainable-palm-oil",
		"TRADITIONAL_SPECIALTY_GUARANTEED" => "en:tsg",
		"TRIMAN" => "fr:triman",
		"UTZ_CERTIFIED" => "en:utz-certified",
		"UTZ_CERTIFIED_COCOA" => "en:utz-certified-cocoa",
		"VIANDE_AGNEAU_FRANCAIS" => "fr:viande-d-agneau-francais",
		"VIANDE_BOVINE_FRANCAISE" => "en:french-beef",
		"VOLAILLE_FRANCAISE" => "en:french-poultry",
	},

	# https://gs1.se/en/guides/documentation/code-lists/t3783-target-market-country-code/
	targetMarketCountryCode => {
		"040" => "en:austria",
		"056" => "en:belgium",
		"250" => "en:france",
		"276" => "en:germany",
		"380" => "en:italy",
		"724" => "en:spain",
		"756" => "en:switzerland",
	},

	timeMeasurementUnitCode => {
		"MON" => "month",
		"DAY" => "day",
	},
);

# Normalize some entries

foreach my $tag (sort keys %{$gs1_maps{allergenTypeCode}}) {
	my $canon_tag = canonicalize_taxonomy_tag("en", "allergens", $gs1_maps{allergenTypeCode}{$tag});
	if (exists_taxonomy_tag("allergens", $canon_tag)) {
		$gs1_maps{allergenTypeCode}{$tag} = $canon_tag;
	}
	else {
		$log->error("gs1_maps - entry not in taxonomy",
			{tagtype => "allergens", tag => $gs1_maps{allergenTypeCode}{$tag}})
			if $log->is_error();
		die;
	}
}

foreach my $tag (sort keys %{$gs1_maps{packagingMarkedLabelAccreditationCode}}) {
	my $canon_tag = canonicalize_taxonomy_tag("en", "labels", $gs1_maps{packagingMarkedLabelAccreditationCode}{$tag});
	if (exists_taxonomy_tag("labels", $canon_tag)) {
		$gs1_maps{packagingMarkedLabelAccreditationCode}{$tag} = $canon_tag;
	}
	else {
		$log->error("gs1_maps - entry not in taxonomy",
			{tagtype => "labels", tag => $gs1_maps{packagingMarkedLabelAccreditationCode}{$tag}})
			if $log->is_error();
		die;
	}
}

=head2 %gs1_message_to_off

Defines the structure of the GS1 message data and how to extract the fields useful to create a message confirmation.

=cut

my %gs1_message_to_off = (

	fields => [

		[
			"catalogue_item_notification:catalogueItemNotificationMessage",
			{
				fields => [
					[
						"sh:StandardBusinessDocumentHeader",
						{
							fields => [

							],
						}
					],

					[
						"transaction",
						{
							fields => [
								[
									"transactionIdentification",
									{
										fields => [
											["entityIdentification", "transactionIdentification_entityIdentification"],
											[
												"contentOwner",
												{
													fields => [["gln", "transactionIdentification_contentOwner_gln"],],
												}
											],
										],
									},
								],

								[
									"documentCommand",
									{
										fields => [
											[
												"documentCommandHeader",
												{
													fields => [
														[
															"documentCommandIdentification",
															{
																fields => [
																	[
																		"entityIdentification",
																		"documentCommandIdentification_entityIdentification"
																	],
																	[
																		"contentOwner",
																		{
																			fields => [
																				[
																					"gln",
																					"documentCommandIdentification_contentOwner_gln"
																				],
																			],
																		}
																	],
																],
															},
														],
														["type", "documentCommandHeader_type"],
													],
												},
											],

											[
												"catalogue_item_notification:catalogueItemNotification",
												{
													fields => [
														[
															"creationDateTime",
															"catalogueItemNotification_creationDateTime"
														],
														[
															"documentStatusCode",
															"catalogueItemNotification_documentStatusCode"
														],
														[
															"catalogueItemNotificationIdentification",
															{
																fields => [
																	[
																		"entityIdentification",
																		"catalogueItemNotificationIdentification_entityIdentification"
																	],
																	[
																		"contentOwner",
																		{
																			fields => [
																				[
																					"gln",
																					"catalogueItemNotificationIdentification_contentOwner_gln"
																				],
																			],
																		}
																	],
																],
															},
														],
														[
															"catalogueItem",
															{
																fields => [
																	[
																		"tradeItem",
																		{
																			fields => [
																				["gtin", "gtin"],
																				[
																					"targetMarket",
																					{
																						fields => [
																							["targetMarketCountryCode",
																								"targetMarketCountryCode"
																							],
																						],
																					},
																				],
																			],
																		},
																	],
																],
															},
														]
													],
												},
											],
										],
									},
								],
							],
						}
					],
				],
			}
		],
	],
);

=head2 %gs1_product_to_off

Defines the structure of the GS1 product data and how it maps to the OFF data.

=cut

my %gs1_product_to_off = (

	match => [["isTradeItemAConsumerUnit", "true"],],

	fields => [

		# source_field => target_field : assign the value of the source field to the target field
		["gtin", "code"],

		# source_field => source_hash : go down one level
		[
			"brandOwner",
			{
				fields => [
					["gln", "sources_fields:org-gs1:gln"],
					# source_field => target_field1,target_field2 : assign value of the source field to multiple target fields
					["partyName", "sources_fields:org-gs1:partyName, org_name"],
				],
			},
		],

		[
			"gdsnTradeItemClassification",
			{
				fields => [
					["gpcCategoryCode", "sources_fields:org-gs1:gpcCategoryCode"],
					# not always present and could be in different languages
					["gpcCategoryName", "sources_fields:org-gs1:gpcCategoryName, +categories_if_match_in_taxonomy"],
				],
			},
		],

		# will override brandOwner values if present
		[
			"informationProviderOfTradeItem",
			{
				fields => [
					["gln", "sources_fields:org-gs1:gln"],
					# source_field => target_field1,target_field2 : assign value of the source field to multiple target fields
					["partyName", "sources_fields:org-gs1:partyName, org_name"],
				],
			},
		],

		[
			"targetMarket",
			{
				fields => [["targetMarketCountryCode", "countries%targetMarketCountryCode"],],
			},
		],

		# http://apps.gs1.org/GDD/Pages/clDetails.aspx?semanticURN=urn:gs1:gdd:cl:ContactTypeCode&release=4
		# source_field => array of hashes: go down one level, expect an array
		[
			"tradeItemContactInformation",
			[
				{
					# match => hash of key value conditions: assign values to field only if the conditions match
					match => [["contactTypeCode", "CXC"],],
					fields => [["contactName", "customer_service_fr"], ["contactAddress", "+customer_service_fr"],],
				},
			],
		],

		[
			"tradeItemInformation",
			{
				fields => [
					# Sometimes contains strings like "Signal CLAY&CHARCOAL DENTIFRICE 75 ML", not a good fit for the producer_version_id
					# but other time contains strings that look like internal version ids / item ids (e.g. "44041392")
					[
						"productionVariantDescription",
						"sources_fields:org-gs1:productionVariantDescription, producer_version_id"
					],

					[
						"extension",
						{
							fields => [

								[
									"alcohol_information:alcoholInformationModule",
									{
										fields => [
											[
												"alcoholInformation",
												{
													fields => [["percentageOfAlcoholByVolume", "alcohol_100g_value"],],
												},
											],
										],
									},
								],

								[
									"allergen_information:allergenInformationModule",
									{
										fields => [
											[
												"allergenRelatedInformation",
												{
													fields => [
														[
															"allergen",
															[
																{
																	match => [["levelOfContainmentCode", "CONTAINS"],],
																	fields => [
																		# source_field => +target_field' : add to field, separate with commas if field is not empty
																		# source_field => target_field%map_id : map the target value using the specified map_id
																		# (do not assign a value if there is no corresponding entry in the map)
																		[
																			'allergenTypeCode',
																			'+allergens%allergenTypeCode'
																		],
																	],
																},
																{
																	match =>
																		[["levelOfContainmentCode", "MAY_CONTAIN"],],
																	fields => [
																		# source_field => +target_field' : add to field, separate with commas if field is not empty
																		# source_field => target_field%map_id : map the target value using the specified map_id
																		# (do not assign a value if there is no corresponding entry in the map)
																		[
																			'allergenTypeCode',
																			'+traces%allergenTypeCode'
																		],
																	],
																},
															],
														],
														[
															"isAllergenRelevantDataProvided",
															"sources_fields:org-gs1:isAllergenRelevantDataProvided"
														],
													],
												},
											],
										],
									},
								],

								[
									"nutritional_information:nutritionalInformationModule",
									{
										fields => [
											["nutrientHeader"],    # nutrients are handled specially with specific code
										],
									},
								],

								[
									"consumer_instructions:consumerInstructionsModule",
									{
										fields => [
											[
												"consumerInstructions",
												{
													fields =>
														[["consumerStorageInstructions", "conservation_conditions"],],
												},
											],
										],
									}
								],

								[
									"food_and_beverage_ingredient:foodAndBeverageIngredientModule",
									{
										fields => [["ingredientStatement", "ingredients_text"],],
									},
								],

								[
									"nonfood_ingredient:nonfoodIngredientModule",
									{
										fields => [["nonfoodIngredientStatement", "ingredients_text"],],
									},
								],

								[
									"food_and_beverage_preparation_serving:foodAndBeveragePreparationServingModule",
									{
										fields => [
											[
												"preparationServing",
												{
													fields => [["preparationInstructions", "preparation"],],
												},
											],
										],
									},
								],

								[
									"health_related_information:healthRelatedInformationModule",
									{
										fields => [
											[
												"healthRelatedInformation",
												{
													match => [["nutritionalProgramCode", "8"],],
													fields => [["nutritionalScore", "nutriscore_grade_producer"],],
												},
											],
										],
									},
								],

								# 2021-12-20: it looks like the nutritionalProgramCode is now in an extra nutritionProgram field
								[
									"health_related_information:healthRelatedInformationModule",
									{
										fields => [
											[
												"healthRelatedInformation",
												{
													fields => [
														[
															"nutritionalProgram",
															{
																match => [["nutritionalProgramCode", "8"],],
																fields => [
																	["nutritionalScore", "nutriscore_grade_producer"],
																],
															},
														],
													],
												},
											],
										],
									},
								],

								# 20230328: this packaging field is too imprecise, and the packaging field is deprecated,
								# as we have a new packagings components structure
								#
								#								[
								#									"packaging_information:packagingInformationModule",
								#									{
								#										fields => [
								#											[
								#												"packaging",
								#												{
								#													fields => [["packagingTypeCode", "+packaging%packagingTypeCode"],],
								#												},
								#											],
								#										],
								#									},
								#								],

								[
									"packaging_marking:packagingMarkingModule",
									{
										fields => [
											[
												"packagingMarking",
												{
													fields => [
														# the source can be an array if there are multiple labels
														[
															"packagingMarkedLabelAccreditationCode",
															"+labels%packagingMarkedLabelAccreditationCode"
														],
													],
												},
											],
										],
									},
								],

								[
									"place_of_item_activity:placeOfItemActivityModule",
									{
										fields => [
											[
												"placeOfProductActivity",
												{
													fields => [
														# provenanceStatement is a free text field, which can contain manufacturing places
														# and/or origins of ingredients and related statements, in different languages
														["provenanceStatement", "origin"],
													],
												},
											],
										],
									},
								],

								[
									"referenced_file_detail_information:referencedFileDetailInformationModule",
									{
										fields => [
											[
												"referencedFileHeader",
												[
													{
														match => [["isPrimaryFile", "TRUE"],],
														fields => [["uniformResourceIdentifier", "image_front_url"],],
													},
													{
														does_not_match => [["isPrimaryFile", "TRUE"],],
														fields => [["uniformResourceIdentifier", "+image_other_url"],],
													},
												],
											],
										],
									},
								],

								[
									"trade_item_description:tradeItemDescriptionModule",
									{
										fields => [
											[
												"tradeItemDescriptionInformation",
												{
													fields => [
														["descriptionShort", "abbreviated_product_name"],
														["functionalName", "+categories_if_match_in_taxonomy"],
														["regulatedProductName", "generic_name"],
														["tradeItemDescription", "product_name"],
														[
															"brandNameInformation",
															{
																fields => [
																	['brandName' => '+brands'],
																	['subBrand' => '+brands'],
																],
															},
														],
													],
												},
											],
										],
									},
								],

								[
									"trade_item_measurements:tradeItemMeasurementsModule",
									{
										fields => [
											[
												"tradeItemMeasurements",
												{
													fields => [
														["netContent", "quantity"],
														[
															"tradeItemWeight",
															{
																fields => [["netWeight", "net_weight"],],
															},
														],
													],
												},
											],
										],
									},
								],

								[
									"trade_item_lifespan:tradeItemLifespanModule",
									{
										fields => [
											[
												"tradeItemLifespan",
												{
													fields => [
														# the source can be an array if there are multiple labels
														["itemPeriodSafeToUseAfterOpening", "+periods_after_opening"],
													],
												},
											],
										],
									},
								],
							],
						},
					],
				],
			},
		],

		[
			"tradeItemSynchronisationDates",
			{
				fields => [
					["publicationDateTime", "sources_fields:org-gs1:publicationDateTime"]
					,    # Not available in CodeOnline export
					["lastChangeDateTime", "sources_fields:org-gs1:lastChangeDateTime"],
				],
			},
		],
	],
);

=head1 FUNCTIONS

=head2 init_csv_fields ()

%seen_fields and @fields are used to output the fields in the order of the GS1 to OFF mapping configuration

=cut

my %seen_csv_fields = ();
my @csv_fields = ();

sub init_csv_fields() {

	%seen_csv_fields = ();
	@csv_fields = ();
	return;
}

=head2 assign_field ( $results_ref $target_field $target_value)

Used to assign a value to a field, and keep track of the order of the fields we are matching,
so that we can output the fields in the same order when we export a CSV.

=cut

sub assign_field ($results_ref, $target_field, $target_value) {

	$results_ref->{$target_field} = $target_value;

	if (not defined $seen_csv_fields{$target_field}) {
		push @csv_fields, $target_field;
		$seen_csv_fields{$target_field} = 1;
	}
	return;
}

sub extract_nutrient_quantity_contained ($type, $per, $results_ref, $nid, $nutrient_detail_ref) {

	my $nutrient_field = $nid . $type . "_" . $per;

	my $nutrient_value;
	my $nutrient_unit;

	# quantityContained may be a single hash, or an array of hashes
	# e.g. for the energy ENER- field, there are values in kJ and kcal that can be specified in different ways:
	# - Equadis has 2 ENER- nutrientDetail, each with a single quantityContained hash
	# - Agena3000 has 1 ENER- nutrientDetail with an array of 2 quantityContained
	# --> convert a single hash to an array with a hash
	if (    (defined $nutrient_detail_ref->{quantityContained})
		and (ref($nutrient_detail_ref->{quantityContained}) ne "ARRAY"))
	{
		$nutrient_detail_ref->{quantityContained} = [$nutrient_detail_ref->{quantityContained}];
	}

	foreach my $quantity_contained_ref (@{$nutrient_detail_ref->{quantityContained}}) {

		if (defined $quantity_contained_ref->{'#'}) {
			$nutrient_value = $quantity_contained_ref->{'#'};
			$nutrient_unit = $gs1_maps{measurementUnitCode}{$quantity_contained_ref->{'@'}{measurementUnitCode}};
		}
		elsif (defined $quantity_contained_ref->{'$t'}) {
			$nutrient_value = $quantity_contained_ref->{'$t'};
			$nutrient_unit = $gs1_maps{measurementUnitCode}{$quantity_contained_ref->{measurementUnitCode}};
		}
		else {
			$log->error("gs1_to_off - unrecognized quantity contained", {quantityContained => $quantity_contained_ref})
				if $log->is_error();
		}

		# less than < modifier
		if (    (defined $nutrient_detail_ref->{measurementPrecisionCode})
			and ($nutrient_detail_ref->{measurementPrecisionCode} eq "LESS_THAN"))
		{
			$nutrient_value = "< " . $nutrient_value;
		}

		# energy: based on the nutrient unit, assign the energy-kj or energy-kcal field
		if ($nid eq "energy") {
			if ($nutrient_unit eq "kcal") {
				$nutrient_field = "energy-kcal" . $type . "_" . $per;
			}
			else {
				$nutrient_field = "energy-kj" . $type . "_" . $per;
			}
		}

		assign_field($results_ref, $nutrient_field . "_value", $nutrient_value);
		assign_field($results_ref, $nutrient_field . "_unit", $nutrient_unit);
	}
	return;
}

=head2 gs1_to_off ($gs1_to_off_ref, $json_ref, $results_ref)

Recursive function to go through all first level keys of the $gs1_to_off_ref mapping.
All values that can be assigned at that level are assigned, and if we need to go into a nested level,
the function calls itself again.

=head3 Arguments

=head4 $gs1_to_off_ref - Mapping configuration from GS1 to off for the current level

=head4 $json_ref - JSON structure for the current level

=head4 $results_ref - Hash of key / value pairs to store the complete output of the mapping

The same hash reference is passed to recursive calls to the gs1_to_off function.

=cut

sub gs1_to_off;

sub gs1_to_off ($gs1_to_off_ref, $json_ref, $results_ref) {

	# We should have a hash
	if (ref($json_ref) ne "HASH") {
		$log->error("gs1_to_off - json_ref is not a hash",
			{gs1_to_off_ref => $gs1_to_off_ref, json_ref => $json_ref, results_ref => $results_ref})
			if $log->is_error();
		return;
	}

	$log->debug("gs1_to_off", {json_ref_keys => [sort keys %$json_ref]}) if $log->is_debug();

	# Check the matching conditions if any

	if (defined $gs1_to_off_ref->{match}) {

		$log->debug("gs1_to_off - checking conditions", {match => $gs1_to_off_ref->{match}}) if $log->is_debug();

		foreach my $match_field_ref (@{$gs1_to_off_ref->{match}}) {

			my $match_field = $match_field_ref->[0];
			my $match_value = $match_field_ref->[1];

			if (   (not defined $json_ref->{$match_field})
				or ($json_ref->{$match_field} ne $match_value))
			{

				$log->debug(
					"gs1_to_off - condition does not match",
					{
						match_field => $match_field,
						match_value => $match_value,
						actual_value => $json_ref->{$match_field}
					}
				) if $log->is_debug();

				return;
			}
		}

		$log->debug("gs1_to_off - conditions match") if $log->is_debug();
	}

	# Check the matching exceptions

	if (defined $gs1_to_off_ref->{does_not_match}) {

		$log->debug("gs1_to_off - checking conditions", {does_not_match => $gs1_to_off_ref->{does_not_match}})
			if $log->is_debug();

		my $match = 1;

		foreach my $match_field_ref (@{$gs1_to_off_ref->{does_not_match}}) {

			my $match_field = $match_field_ref->[0];
			my $match_value = $match_field_ref->[1];

			if (   (not defined $json_ref->{$match_field})
				or ($json_ref->{$match_field} ne $match_value))
			{

				$log->debug(
					"gs1_to_off - condition does not match",
					{
						match_field => $match_field,
						match_value => $match_value,
						actual_value => $json_ref->{$match_field}
					}
				) if $log->is_debug();

				$match = 0;
				last;
			}
		}

		return if $match;

		$log->debug("gs1_to_off - conditions match") if $log->is_debug();
	}

	$log->debug("gs1_to_off - assigning fields") if $log->is_debug();

	# If the conditions match, assign the fields

	foreach my $source_field_ref (@{$gs1_to_off_ref->{fields}}) {

		my $source_field = $source_field_ref->[0];
		my $source_target = $source_field_ref->[1];

		$log->debug("gs1_to_off - source fields", {source_field => $source_field}) if $log->is_debug();

		if (defined $json_ref->{$source_field}) {

			$log->debug("gs1_to_off - existing source fields",
				{source_field => $source_field, ref => ref($source_target)})
				if $log->is_debug();

			# if the source field is nutrientHeader, we need to extract multiple
			# nutrition facts tables (for unprepared and prepared product)
			# with multiple nutrients.
			# As the mapping is complex, it is done with special code below
			# instead of the generic matching code.

			if ($source_field eq "nutrientHeader") {

				$log->debug("gs1_to_off - special handling for nutrientHeader array") if $log->is_debug();

				# If there is only one nutrition facts table, nutrientHeader might not be an array
				# depending on how the XML was converted to JSON
				# In that case, create an array
				if (ref($json_ref->{$source_field}) eq 'HASH') {
					$json_ref->{$source_field} = [$json_ref->{$source_field}];
				}

				# Some products like ice cream may have nutrients per 100g + nutrients per 100ml
				# in that case, the last values (e.g. for 100g) will override previous values (e.g. for 100ml)

				foreach my $nutrient_header_ref (@{$json_ref->{$source_field}}) {

					my $type = "";

					if ($nutrient_header_ref->{preparationStateCode} eq "PREPARED") {
						$type = "_prepared";
					}

					my $serving_size_value;
					my $serving_size_unit;
					my $serving_size_description;
					my $serving_size_description_lc;

					if (defined $nutrient_header_ref->{servingSize}{'#'}) {
						$serving_size_value = $nutrient_header_ref->{servingSize}{'#'};
						$serving_size_unit = $gs1_maps{measurementUnitCode}
							{$nutrient_header_ref->{servingSize}{'@'}{measurementUnitCode}};
					}
					elsif (defined $nutrient_header_ref->{servingSize}{'$t'}) {
						$serving_size_value = $nutrient_header_ref->{servingSize}{'$t'};
						$serving_size_unit
							= $gs1_maps{measurementUnitCode}{$nutrient_header_ref->{servingSize}{measurementUnitCode}};
					}
					else {
						$log->error("gs1_to_off - unrecognized serving size",
							{servingSize => $nutrient_header_ref->{servingSize}})
							if $log->is_error();
					}

					# We may have a servingSizeDescription in multiple languages, in that case, take the first one

					if (defined $nutrient_header_ref->{servingSizeDescription}) {
						my @serving_size_descriptions;
						if (ref($nutrient_header_ref->{servingSizeDescription}) eq "ARRAY") {
							@serving_size_descriptions = @{$nutrient_header_ref->{servingSizeDescription}};
						}
						else {
							@serving_size_descriptions = ($nutrient_header_ref->{servingSizeDescription});
						}

						if (scalar @serving_size_descriptions > 0) {

							my $serving_size_description_ref = $serving_size_descriptions[0];
							if (defined $serving_size_description_ref->{'#'}) {
								$serving_size_description = $serving_size_description_ref->{'#'};
								$serving_size_description_lc = $serving_size_description_ref->{'@'}{languageCode};
							}
							elsif (defined $serving_size_description_ref->{'$t'}) {
								$serving_size_description = $serving_size_description_ref->{'$t'};
								$serving_size_description_lc = $serving_size_description_ref->{languageCode};
							}
						}
					}

					my $per = "100g";

					if ((defined $serving_size_value) and ($serving_size_value != 100)) {
						$per = "serving";
						$serving_size_value += 0;    # remove extra .0

						# Some serving sizes have an extra description
						# e.g. par portion : 14 g + 200 ml d'eau
						my $extra_serving_size_description = "";
						if ((defined $serving_size_description) and (defined $serving_size_description_lc)) {
							# Par Portion de 30 g (2)
							$serving_size_description
								=~ s/^(par |pour )?((1 |une )?(part |portion ))?(de )?\s*:?=?\s*//i;
							$serving_size_description =~ s/( |\d)(gr|grammes)$/$1g/i;
							# Par Portion de 30 g (2) : remove number of portions
							$serving_size_description =~ s/\(\d+\)//i;
							$serving_size_description =~ s/^\s+//;
							$serving_size_description =~ s/\s+$//;
							# skip the extra description if it is equal to value + unit
							# to avoid things like 43 g (43 g)
							# "Pour 45g ?²?" --> ignore bogus characters at the end
							if (
								($serving_size_description !~ /^\s*$/)
								and ($serving_size_description
									!~ /^$serving_size_value\s*$serving_size_unit(\?|\.|\,|\s|\*|²)*$/i)
								)
							{
								$extra_serving_size_description = ' (' . $serving_size_description . ')';
							}
						}

						assign_field($results_ref, "serving_size",
							$serving_size_value . " " . $serving_size_unit . $extra_serving_size_description);
					}

					if (defined $nutrient_header_ref->{nutrientDetail}) {

						# If there's only one nutrient, we may not get an array

						if (ref($nutrient_header_ref->{nutrientDetail}) ne 'ARRAY') {
							$log->error("gs1_to_off - nutrient_header is not an array ", {results_ref => $results_ref})
								if $log->is_error();
							next;
						}

						foreach my $nutrient_detail_ref (@{$nutrient_header_ref->{nutrientDetail}}) {
							my $nid = $gs1_maps{nutrientTypeCode}{$nutrient_detail_ref->{nutrientTypeCode}};

							if (defined $nid) {
								extract_nutrient_quantity_contained($type, $per, $results_ref, $nid,
									$nutrient_detail_ref);
							}
							else {
								$log->error("gs1_to_off - unrecognized nutrient",
									{code => $results_ref->{code}, nutrient_detail_ref => $nutrient_detail_ref})
									if $log->is_error();
								my $map = "nutrientTypeCode";
								my $source_value = $nutrient_detail_ref->{nutrientTypeCode};
								defined $unknown_entries_in_gs1_maps{$map} or $unknown_entries_in_gs1_maps{$map} = {};
								defined $unknown_entries_in_gs1_maps{$map}{$source_value}
									or $unknown_entries_in_gs1_maps{$map}{$source_value} = 0;
								$unknown_entries_in_gs1_maps{$map}{$source_value}++;
							}
						}
					}
				}
			}

			# If the value is a scalar, it is a target field (or multiple target fields)
			elsif (ref($source_target) eq "") {

				$log->debug(
					"gs1_to_off - source field directly maps to target field",
					{source_field => $source_field, target_field => $source_target}
				) if $log->is_debug();

				# We may have multiple source values, in an array

				my @source_values;

				if (ref($json_ref->{$source_field}) eq "ARRAY") {
					@source_values = @{$json_ref->{$source_field}};
				}
				else {
					@source_values = ($json_ref->{$source_field});
				}

				foreach my $source_value (@source_values) {

					# We may have multiple target fields, separated by commas
					foreach my $target_field (split(/\s*,\s*/, $source_target)) {

						$log->debug(
							"gs1_to_off - assign value to target field",
							{
								source_field => $source_field,
								source_value => $source_value,
								target_field => $target_field
							}
						) if $log->is_debug();

						# We might combine a value and a unit, but also keep them separate so that we can assign fields like quantity_value and quantity_unit
						my $source_value_value;
						my $source_value_unit;

						# Some fields indicate a language:

						# ingredientStatement: {
						#   languageCode: "fr",
						#   $t: "Ingrédients: LAIT entier en poudre (38,9%), PETIT-LAIT filtré en poudre, café soluble (8,0%), fibres de chicorée (oligofructose) (8%), chicorée soluble (7,5%), stabilisant : E331, correcteur d'acidité : E340, sulfate de magnésium."
						# },

						# or another format (depending on how the XML was converted to JSON):

						# ingredientStatement: {
						#   #: "Ingrédients: LAIT entier en poudre (38,9%), PETIT-LAIT filtré en poudre, café soluble (8,0%), fibres de chicorée (oligofructose) (8%), chicorée soluble (7,5%), stabilisant : E331, correcteur d'acidité : E340, sulfate de magnésium.",
						#   @: {
						#     languageCode: "fr"
						#   }
						# },

						if (ref($source_value) eq "HASH") {
							my $language_code;
							my $value;

							# There may be a language code
							if (defined $source_value->{languageCode}) {
								$language_code = $source_value->{languageCode};
							}
							elsif ((defined $source_value->{'@'}) and (defined $source_value->{'@'}{languageCode})) {
								$language_code = $source_value->{'@'}{languageCode};
							}

							# Keep track of language codes so that we can assign the lc and lang fields
							if (defined $language_code) {
								defined $results_ref->{languages} or $results_ref->{languages} = {};
								defined $results_ref->{languages}{$language_code}
									or $results_ref->{languages}{$language_code} = 0;
								$results_ref->{languages}{$language_code}++;
							}

							if (defined $source_value->{'$t'}) {
								$value = $source_value->{'$t'};
							}
							elsif (defined $source_value->{'#'}) {
								$value = $source_value->{'#'};
							}

							# There may be a measurement unit code, or a time measurement unit code
							# in that case, concatenate it to the value

							foreach my $code ("measurementUnitCode", "timeMeasurementUnitCode") {

								if (defined $source_value->{$code}) {
									$source_value_value = $value;
									$source_value_unit = $gs1_maps{$code}{$source_value->{$code}};
									$value .= " " . $gs1_maps{$code}{$source_value->{$code}};
								}
								elsif ((defined $source_value->{'@'}) and (defined $source_value->{'@'}{$code})) {
									$source_value_value = $value;
									$source_value_unit = $gs1_maps{$code}{$source_value->{'@'}{$code}};
									$value .= " " . $gs1_maps{$code}{$source_value->{'@'}{$code}};
								}
							}

							# If the field is a language specific field, we can assign the value to the language specific field
							if ((defined $language_code) and (defined $language_fields{$target_field})) {
								$target_field = $target_field . "_" . lc($language_code);
								$log->debug(
									"gs1_to_off - changed to language specific target field",
									{
										source_field => $source_field,
										source_value => $source_value,
										target_field => $target_field
									}
								) if $log->is_debug();
							}

							if (defined $value) {
								$source_value = $value;
							}
							else {
								$log->error(
									"gs1_to_off - issue with source value structure",
									{
										source_field => $source_field,
										source_value => $source_value,
										target_field => $target_field
									}
								) if $log->is_error();
								$source_value = undef;
							}
						}

						if (
								(defined $source_value)
							and ($source_value ne "")
							# CodeOnline sometimes has empty values '.' or '0' for partyName for one of the fields brandOwner or informationProviderOfTradeItem
							# ignore them in order to keep the partyName value from the other fields
							and not(($source_field eq "partyName") and (length($source_value) < 2))
							)
						{

							# allergenTypeCode => '+traces%allergens',
							# % sign means we will use a map to transform the source value
							if ($target_field =~ /\%/) {
								$target_field = $`;
								my $map = $';
								if (defined $gs1_maps{$map}{$source_value}) {
									$source_value = $gs1_maps{$map}{$source_value};
								}
								else {
									$log->error(
										"gs1_to_off - unknown source value for map",
										{
											code => $results_ref->{code},
											source_field => $source_field,
											source_value => $source_value,
											target_field => $target_field,
											map => $map
										}
									) if $log->is_error();
									defined $unknown_entries_in_gs1_maps{$map}
										or $unknown_entries_in_gs1_maps{$map} = {};
									defined $unknown_entries_in_gs1_maps{$map}{$source_value}
										or $unknown_entries_in_gs1_maps{$map}{$source_value} = 0;
									$unknown_entries_in_gs1_maps{$map}{$source_value}++;
									# Skip the entry
									next;
								}
							}

							# allergenTypeCode => '+traces%allergens',
							# + sign means we will create a comma separated list if we have multiple values
							if ($target_field =~ /^\+/) {
								$target_field = $';

								if (defined $results_ref->{$target_field}) {
									$source_value = $results_ref->{$target_field} . ', ' . $source_value;
								}
							}

							assign_field($results_ref, $target_field, $source_value);

							if ($target_field eq "quantity") {
								if (defined $source_value_value) {
									assign_field($results_ref, $target_field . "_value", $source_value_value);
									assign_field($results_ref, $target_field . "_unit", $source_value_unit);
								}
							}
						}
					}

				}
			}

			elsif (ref($source_target) eq "ARRAY") {

				#	http://apps.gs1.org/GDD/Pages/clDetails.aspx?semanticURN=urn:gs1:gdd:cl:ContactTypeCode&release=4
				#	source_field => array of hashes: go down one level, expect an array
				#
				#		["tradeItemContactInformation", [
				#				{
				#					# match => hash of key value conditions: assign values to field only if the conditions match
				#					match => [
				#						["contactTypeCode", "CXC"],
				#					],
				#					fields => [
				#						["contactAddress", "customer_service_fr"],
				#					],
				#				},
				#			],
				#		],

				$log->debug("gs1_to_off - array field", {source_field => $source_field}) if $log->is_debug();

				# Loop through the array entries of the GS1 to OFF mapping

				foreach my $gs1_to_off_array_entry_ref (@{$source_target}) {

					# Loop through the array entries of the JSON file

					# If the source file is not an array, create it
					# (e.g. if only one element is there, the xml to json conversion might not create an array)
					if (ref($json_ref->{$source_field}) ne "ARRAY") {
						$json_ref->{$source_field} = [$json_ref->{$source_field}];
					}

					foreach my $json_array_entry_ref (@{$json_ref->{$source_field}}) {

						gs1_to_off($gs1_to_off_array_entry_ref, $json_array_entry_ref, $results_ref);
					}
				}
			}

			elsif (ref($source_target) eq "HASH") {

				# Go down one level

				# The source structure may be a hash or an array of hashes
				# e.g. Equadis: allergenRelatedInformation is a hash, CodeOnline: it is an array

				# CodeOnline:

				# allergenRelatedInformation: [
				# 	{
				# 		allergen: [
				# 			{
				# 				allergenTypeCode: "AC",
				# 				levelOfContainmentCode: "FREE_FROM"
				# 			},
				# 			{
				# 				allergenTypeCode: "AE",
				# 				levelOfContainmentCode: "CONTAINS"
				# 			},

				$log->debug("gs1_to_off - source_target is a hash",
					{source_field => $source_field, source_target => $source_target, json_ref => $json_ref})
					if $log->is_debug();

				if (ref($json_ref->{$source_field}) eq "HASH") {

					gs1_to_off($source_target, $json_ref->{$source_field}, $results_ref);
				}
				elsif (ref($json_ref->{$source_field}) eq "ARRAY") {
					foreach my $json_array_entry_ref (@{$json_ref->{$source_field}}) {

						# We should have an array of hashes, but in some CodeOnline files we have an array with an empty array..

						# allergenRelatedInformation: [
						# 	[ ]
						# ]

						if (ref($json_array_entry_ref) eq "HASH") {
							gs1_to_off($source_target, $json_array_entry_ref, $results_ref);
						}
						else {
							$log->debug(
								"gs1_to_off - expected a hash but got an array",
								{
									source_field => $source_field,
									source_target => $source_target,
									json_ref => $json_ref,
									json_array_entry_ref => $json_array_entry_ref
								}
							) if $log->is_debug();
						}
					}
				}
			}
		}
	}
	return;
}

=head2 convert_single_text_property_to_direct_value ($json )

There are different ways to convert a XML document to a JSON data structure.

Historically, we used nodejs xml2json module to convert the GS1 XML to JSON.

Then we added support for CodeOnline JSON exports which used slightly different conversions.

In order to remove the dependency on nodejs, we are now supporting Perl's XML:XML2JSON module that results in different structures.

This function is a recursive function to make the output of Perl XML::XML2JSON similar to nodejs xml2json, as the GS1 module expects this format.

Difference:

XML2JSON creates a hash for simple text values. Text values of tags are converted to $t properties.
e.g. <gtin>03449862093657</gtin>

becomes:

gtin: {
	 $t: "03449865355608"
},

This function converts those hashes with one single $t scalar values to a direct value.

gtin: "03449865355608"

=head3 Arguments

=head4 $json_ref Reference to a decoded JSON structure

=cut

sub convert_single_text_property_to_direct_value ($json_ref) {

	my $type = ref $json_ref or return;

	if ($type eq 'HASH') {
		foreach my $key (keys %$json_ref) {
			if (ref $json_ref->{$key}) {
				# Hash with a single $t value?
				if (    (ref $json_ref->{$key} eq 'HASH')
					and ((scalar keys %{$json_ref->{$key}}) == 1)
					and (defined $json_ref->{$key}{'$t'}))
				{
					$json_ref->{$key} = $json_ref->{$key}{'$t'};
				}
				else {
					convert_single_text_property_to_direct_value($json_ref->{$key});
				}
			}
		}
	}
	elsif ($type eq 'ARRAY') {

		foreach my $elem (@$json_ref) {
			if (ref $elem) {
				convert_single_text_property_to_direct_value($elem);
			}
		}
	}
	return;
}

=head2 convert_gs1_json_message_to_off_products_csv_fields ($json, $products_ref, $messages_ref)

Thus function converts the data for one or more products in the GS1 format converted to JSON.
GS1 format is in XML, it needs to be transformed to JSON with xml2json first.
In some cases, the conversion to JSON has already be done by a third party (e.g. the CodeOnline database from GS1 France).

Note: This function is recursive if there are child products.

One GS1 message can include 1 or more products, typically products that contain other products
(e.g. a pallet of cartons of products).

=head3 Arguments

=head4 $json_ref Reference to a decoded JSON structure

=head4 $product_ref - Reference to an array of product data

Each product data will be added as one element (a hash ref) of the product data array.

For each product, the key of the hash is the name of the OFF csv field, and it is associated with the corresponding value for the product.

=head4 $messages_ref - Reference to an array of GS1 messages data

Each message will be added as one element (a hash ref) of the messages data array.

=cut

sub convert_gs1_json_message_to_off_products_csv ($json_ref, $products_ref, $messages_ref) {

	# Depending on how the original XML was converted to JSON,
	# text values of XML tags can be assigned directly as the value of the corresponding key
	# or they can be stored inside a hash with the $t key
	# e.g.
	# levelOfContainmentCode: {
	#	$t: "MAY_CONTAIN"
	# },

	# The JSON can contain only the product information "tradeItem" level
	# or the tradeItem can be encapsulated in a message

	# catalogue_item_notification:catalogueItemNotificationMessage
	# - transaction
	# -- documentCommand
	# --- catalogue_item_notification:catalogueItemNotification
	# ---- catalogueItem
	# ----- tradeItem

	# If there is an encapsulating message, extract the relevant fields
	# that we will need to create a confirmation message
	if (defined $json_ref->{"catalogue_item_notification:catalogueItemNotificationMessage"}) {
		my $message_ref = {};
		gs1_to_off(\%gs1_message_to_off, $json_ref, $message_ref);
		push @$messages_ref, $message_ref;
		$log->debug("convert_gs1_json_to_off_csv - GS1 message fields", {message_ref => $message_ref})
			if $log->is_debug();
	}

	foreach my $field (
		qw(
		catalogue_item_notification:catalogueItemNotificationMessage
		transaction
		documentCommand
		catalogue_item_notification:catalogueItemNotification
		catalogueItem
		)
		)
	{
		if (defined $json_ref->{$field}) {
			$json_ref = $json_ref->{$field};
			$log->debug("convert_gs1_json_to_off_csv - remove encapsulating field", {field => $field})
				if $log->is_debug();
		}
	}

	# A product can contain a child product
	my $child_product_json_ref = deep_get($json_ref, qw(catalogueItemChildItemLink catalogueItem));
	if (defined $child_product_json_ref) {
		$log->debug("convert_gs1_json_to_off_csv - found a child item", {}) if $log->is_debug();
		convert_gs1_json_message_to_off_products_csv($child_product_json_ref, $products_ref, $messages_ref);
	}

	if (defined $json_ref->{tradeItem}) {
		$json_ref = $json_ref->{tradeItem};
	}

	if (not defined $json_ref->{gtin}) {
		$log->debug("convert_gs1_json_to_off_csv - no gtin - skipping", {json_ref => $json_ref}) if $log->is_debug();
		return {};
	}

	if ((not defined $json_ref->{isTradeItemAConsumerUnit}) or ($json_ref->{isTradeItemAConsumerUnit} ne "true")) {
		$log->debug(
			"convert_gs1_json_to_off_csv - isTradeItemAConsumerUnit not true - skipping",
			{isTradeItemAConsumerUnit => $json_ref->{isTradeItemAConsumerUnit}}
		) if $log->is_debug();
		return {};
	}

	my $product_ref = {};

	gs1_to_off(\%gs1_product_to_off, $json_ref, $product_ref);

	# assign the lang and lc fields
	if (defined $product_ref->{languages}) {
		my @sorted_languages = sort({$product_ref->{languages}{$b} <=> $product_ref->{languages}{$a}}
			keys %{$product_ref->{languages}});
		my $top_language = $sorted_languages[0];
		$product_ref->{lc} = $top_language;
		$product_ref->{lang} = $top_language;
		delete $product_ref->{languages};
	}

	push @$products_ref, $product_ref;
	return;
}

=head2 read_gs1_json_file ($json_file, $products_ref, $messages_ref)

Read a GS1 message file in json format, convert the included products in the OFF format,
and store the resulting products in the $products_ref array

The encapsulating GS1 message is added to the $messages_ref array

=head3 Arguments

=head4 input json file path and name $json_file

=head4 reference to output products array $products_ref

=head4 reference to output messages array $messages_ref


=cut

sub read_gs1_json_file ($json_file, $products_ref, $messages_ref) {

	$log->debug("read_gs1_json_file", {json_file => $json_file}) if $log->is_debug();

	open(my $in, "<", $json_file) or die("Cannot open json file $json_file : $!\n");
	my $json = join(q{}, (<$in>));
	close($in);

	my $json_ref = decode_json($json);

	# Convert JSON structures created from the XML::XML2JSON module
	# to the format generated by the nodejs xml2json module
	# which is the expected format of the ProductOpener::GS1 module
	convert_single_text_property_to_direct_value($json_ref);

	convert_gs1_json_message_to_off_products_csv($json_ref, $products_ref, $messages_ref);
	return;
}

sub generate_gs1_message_identifier() {

	# local GLN + 60 random hexadecimal characters
	my $identifier = deep_get(\%options, qw(gs1 local_gln)) . "_";
	$identifier .= sprintf("%x", rand 16) for 1 .. 60;

	return $identifier;
}

=head2 generate_gs1_confirmation_message ($notification_message_ref, $timestamp)

GS1 data pools (catalogs) send us GSDN Catalogue Item Notification (CIN) which are messages
that contain the data for 1 product (and possibly sub-products).

The GS1 standard offers data recipient (such as Open Food Facts) to send back
Catalogue Item Confirmation (CIC) messages to acknowledge the notification and give
its status.

This function generates the CIC message corresponding to a CIN message.

See https://www.gs1.org/docs/gdsn/tiig/3_1/GDSN_Trade_Item_Implementation_Guide.pdf for more details.

=head3 Arguments

=head4 reference to the notification message (as parsed by convert_gs1_json_message_to_off_products_csv)

=head4 timestamp

The current time is passed as a parameter to the function. This is so that we can 
generate test confirmation messages which don't have a different content every time we run them.

=cut

sub generate_gs1_confirmation_message ($notification_message_ref, $timestamp) {

	# We will need to generate a message identifier, put it in the XML content,
	# and return it as it is used as the file name
	my $confirmation_instance_identifier = generate_gs1_message_identifier();

	# Template data for the confirmation
	my $confirmation_data_ref = {
		Sender_Identifier => deep_get(\%options, qw(gs1 local_gln)),
		Receiver_Identifier => deep_get(\%options, qw(gs1 agena3000 receiver_gln)),
		recipientGLN => deep_get(\%options, qw(gs1 local_gln)),
		recipientDataPool => deep_get(\%options, qw(gs1 agena3000 data_pool_gln)),
		InstanceIdentifier => $confirmation_instance_identifier,
		transactionIdentification_entityIdentification => generate_gs1_message_identifier(),
		documentCommandIdentification_entityIdentification => generate_gs1_message_identifier(),
		catalogueItemNotificationIdentification_entityIdentification => generate_gs1_message_identifier(),
		CreationDateAndTime => display_date_iso($timestamp),
		catalogueItemConfirmationStateCode => 'RECEIVED',
	};

	# Include the notification data in the template data for the confirmation
	$confirmation_data_ref->{notification} = $notification_message_ref;

	my $xml;
	if (process_template('gs1/catalogue_item_confirmation.tt.xml', $confirmation_data_ref, \$xml)) {
		$log->debug("generate_gs1_confirmation_message - success",
			{confirmation_instance_identifier => $confirmation_instance_identifier})
			if $log->is_error();
	}
	else {
		$log->error("generate_gs1_confirmation_message - template error", {error => $tt->error()}) if $log->is_error();
	}

	return ($confirmation_instance_identifier, $xml);
}

=head2 write_off_csv_file ($csv_file, $products_ref)

Write all product data from the $products_ref array to a CSV file in OFF format.

=head3 Arguments

=head4 output CSV file path and name

=head4 reference to output products array $products_ref

=cut

sub write_off_csv_file ($csv_file, $products_ref) {

	$log->debug("write_off_csv_file", {csv_file => $csv_file}) if $log->is_debug();

	open(my $filehandle, ">:encoding(UTF-8)", $csv_file) or die("Cannot write csv file $csv_file : $!\n");

	my $separator = "\t";

	my $csv = Text::CSV->new({binary => 1, sep_char => $separator})    # should set binary attribute.
		or die "Cannot use CSV: " . Text::CSV->error_diag();

	# Print the header line with fields names

	$log->debug("write_off_csv_file - header", {csv_fields => \@csv_fields}) if $log->is_debug();

	$csv->print($filehandle, \@csv_fields);
	print $filehandle "\n";

	# We may have the same product multiple times, sort by sources_fields:org-gs1:publicationDateTime
	# or by lastChangeDateTime (publicationDateTime is not in the CodeOnline export)
	my %seen_products = ();

	foreach my $product_ref (
		sort {
			($b->{"sources_fields:org-gs1:publicationDateTime"} // $b->{"sources_fields:org-gs1:lastChangeDateTime"})
				cmp($a->{"sources_fields:org-gs1:publicationDateTime"}
					// $a->{"sources_fields:org-gs1:lastChangeDateTime"})
		} @$products_ref
		)
	{

		$log->debug("write_off_csv_file - product", {code => $product_ref->{code}}) if $log->is_debug();
		if (defined $seen_products{$product_ref->{code}}) {
			# Skip product for which we have a more recent publication
			next;
		}
		else {
			$seen_products{$product_ref->{code}} = 1;
		}

		my @csv_fields_values = ();
		foreach my $field (@csv_fields) {
			push @csv_fields_values, $product_ref->{$field};
		}

		$csv->print($filehandle, \@csv_fields_values);
		print $filehandle "\n";
	}

	close $filehandle;
	return;
}

=head2 print_unknown_entries_in_gs1_maps ()

Prints the entries for GS1 data types for which we do not have a corresponding OFF match,
ordered by the number of occurrences in the GS1 data

=cut

sub print_unknown_entries_in_gs1_maps() {

	my $unknown_entries = 0;

	foreach my $map (sort keys %unknown_entries_in_gs1_maps) {
		print "$map map has unknown entries:\n";

		foreach my $source_value (
			sort {$unknown_entries_in_gs1_maps{$map}{$a} <=> $unknown_entries_in_gs1_maps{$map}{$b}}
			keys %{$unknown_entries_in_gs1_maps{$map}}
			)
		{
			print $source_value . "\t" . $unknown_entries_in_gs1_maps{$map}{$source_value} . "\n";
			$unknown_entries++;
		}

		print "\n";
	}

	return $unknown_entries;
}

=head2 convert_gs1_xml_file_to_json ($xml_file, $json_file)

Convert a GS1 XML file to a JSON file

=cut 

sub convert_gs1_xml_file_to_json ($xml_file, $json_file) {

	my $xml2json = XML::XML2JSON->new(module => 'JSON', pretty => 1, force_array => 0, attribute_prefix => "");

	open(my $in, "<:encoding(UTF-8)", $xml_file) or die("Could not read $xml_file: $!");
	my $xml = join('', (<$in>));
	close($in);

	my $json = $xml2json->convert($xml);

	# XML2JSON changes the namespace concatenation character from : to $
	# e.g. "allergen_information$allergenInformationModule":
	# it is unwanted, turn it back to : so that we can match the expected input of ProductOpener::GS1
	$json =~ s/([a-z])\$([a-z])/$1:$2/ig;

	# Note: XML2JSON also creates a hash for simple text values. Text values of tags are converted to $t properties.
	# e.g. <gtin>03449862093657</gtin>
	#
	# becomes:
	#
	# gtin: {
	#    $t: "03449865355608"
	# },
	#
	# This is taken care of later by the ProductOpener::GS1::convert_single_text_property_to_direct_value() function

	open(my $out, ">:encoding(UTF-8)", $json_file) or die("Could not write $json_file: $!");
	print $out $json;
	close($out);
	return;
}

1;

