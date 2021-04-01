/**
 * Created by Olivier Richard (oric.dev@iznogoud.neomailbox.ch) on 18/03/18.
 *
 * purpose: Constants related to template page stats.html for displaying the statistics of database_aggregation into a table
 */


// statistics table (https://<website>/stats)
var ID_TABLE_STATS = "#stats_table";
var ID_FILE_TIMESTAMP = "#file_timestamp";

// json properties for each database
var FLD_IS_ERROR = "isInError";
var FLD_DB_DISPLAY_NAME = "dbDisplayName";
var FLD_DB_NAME = "dbName";
var FLD_DB_NICK_NAME = "dbNickname";
// true = production
var FLD_IS_ACTIVE = "isActive";
var FLD_SIMILARITY_MIN_PERCENTAGE = "similarityMinPercentage";
var FLD_DB_SUMMARY = "dbSummary";
var FLD_DB_DESCRIPTION_EN = "dbDescriptionEn";
var FLD_DB_DESCRIPTION = "dbDescription";
var FLD_DB_MAX_SIZE = "dbMaxSize";
var FLD_OWNER = "owner";
var FLD_EMAIL_OWNER = "emailOwner";
// link to ComputingInstance file (repository, 'ComputingInstance.java' file)
var FLD_LINK_CI = "linkComputingInstance";
// link to dedicated tag on blog PROSIM to get history reports of all aggregated db-instances
var FLD_LINK_STATS_PROSIM = "statsProsim";
var FLD_DB_SIZE_GB = "dbSize";
var FLD_NB_PRODUCTS_EXTRACTED = "nbProductsExtracted";
var FLD_NB_PRODUCTS = "nbProducts";
var FLD_NB_INTERSECTIONS = "nbIntersections";
var FLD_PROGRESSION = "progression";
