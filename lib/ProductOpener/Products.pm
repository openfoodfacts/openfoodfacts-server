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

=head1 NAME

ProductOpener::Products - create and save products

=head1 SYNOPSIS

C<ProductOpener::Products> is used to create products and save them in Product Opener's
database and file system.

    use ProductOpener::Products qw/:all/;

	my $product_ref = init_product($User_id, $Org_id, $code, $countryid);

	$product_ref->{product_name_en} = "Chocolate cookies";

	store_product("my-user", $product_ref, 'helpful comment');


=head1 DESCRIPTION

=head2 Revisions

When a product is saved, a new revision of the product is created. All revisions are saved
in the file system:

products/[barcode path]/1.sto - first revision
products/[barcode path]/2.sto - 2nd revision
...
products/[barcode path]/product.sto - link to latest revision

The latest revision is stored in the products collection of the MongoDB database.

=head2 Completeness, data quality and edit history

Before a product is saved, this module compute the completeness and quality of the data,
and the edit history.

=cut

package ProductOpener::Products;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&is_valid_code
		&normalize_code
		&normalize_code_with_gs1_ai
		&assign_new_code
		&product_id_for_owner
		&get_server_for_product
		&server_for_product_type
		&split_code
		&product_path
		&product_path_from_id
		&product_id_from_path
		&get_owner_id
		&normalize_product_data
		&init_product
		&retrieve_product
		&store_product
		&product_name_brand
		&product_name_brand_quantity
		&product_url
		&product_action_url
		&normalize_search_terms
		&compute_keywords
		&log_change

		&get_change_userid_or_uuid
		&compute_codes
		&compute_completeness_and_missing_tags
		&compute_product_history_and_completeness
		&compute_languages
		&review_product_type
		&compute_changes_diff_text
		&compute_data_sources
		&compute_sort_keys

		&process_product_edit_rules
		&preprocess_product_field
		&product_data_is_protected

		&make_sure_numbers_are_stored_as_numbers
		&change_product_code
		&change_product_type

		&find_and_replace_user_id_in_products

		&remove_fields

		&add_images_urls_to_product

		&analyze_and_enrich_product_data

		&is_owner_field

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::ProductSchemaChanges qw/$current_schema_version convert_product_schema/;
use ProductOpener::Store qw/get_string_id_for_lang get_url_id_for_lang retrieve store/;
use ProductOpener::Config qw/:all/;
use ProductOpener::ConfigEnv qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS ensure_dir_created_or_die/;
use ProductOpener::Users qw/$Org_id $Owner_id $User_id %User init_user/;
use ProductOpener::Orgs qw/retrieve_org/;
use ProductOpener::Lang qw/$lc %tag_type_singular lang/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Mail qw/send_email/;
use ProductOpener::URL qw(format_subdomain get_owner_pretty_path);
use ProductOpener::Data qw/execute_query get_products_collection get_recent_changes_collection/;
use ProductOpener::MainCountries qw/compute_main_countries/;
use ProductOpener::Text qw/remove_email remove_tags_and_quote/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Redis qw/push_to_redis_stream/;
use ProductOpener::Food qw/%nutriments_lists %cc_nutriment_table/;
use ProductOpener::Units qw/normalize_product_quantity_and_serving_size/;

# needed by analyze_and_enrich_product_data()
# may be moved to another module at some point
use ProductOpener::Packaging qw/analyze_and_combine_packaging_data/;
use ProductOpener::DataQuality qw/check_quality/;
use ProductOpener::TaxonomiesEnhancer qw/check_ingredients_between_languages/;

# Specific to the product type
use ProductOpener::FoodProducts qw/specific_processes_for_food_product/;
use ProductOpener::PetFoodProducts qw/specific_processes_for_pet_food_product/;
use ProductOpener::BeautyProducts qw/specific_processes_for_beauty_product/;

use CGI qw/:cgi :form escapeHTML/;
use Encode;
use JSON;
use Log::Any qw($log);
use Data::DeepAccess qw(deep_get);

use LWP::UserAgent;
use Storable qw(dclone);
use File::Copy::Recursive;
use File::Basename qw/dirname/;
use ProductOpener::GeoIP;

use Algorithm::CheckDigits;
my $ean_check = CheckDigits('ean');

use Scalar::Util qw(looks_like_number);

use GS1::SyntaxEngine::FFI::GS1Encoder;

=head1 FUNCTIONS

=head2 make_sure_numbers_are_stored_as_numbers ( PRODUCT_REF )

C<make_sure_numbers_are_stored_as_numbers()> forces numbers contained in the product data to be stored
as numbers (and not strings) in MongoDB.

Perl scalars are not typed, the internal type depends on the last operator
used on the variable... e.g. if it is printed with a string concatenation,
then it's converted to a string.

See https://metacpan.org/pod/JSON%3a%3aXS#PERL---JSON

=cut

sub make_sure_numbers_are_stored_as_numbers ($product_ref) {

	if (defined $product_ref->{nutriments}) {
		foreach my $field (keys %{$product_ref->{nutriments}}) {
			# _100g and _serving need to be numbers
			if ($field =~ /_(100g|serving)$/) {
				# Store as number
				$product_ref->{nutriments}{$field} += 0.0;
			}
			elsif ($field =~ /_(modifier|unit|label)$/) {
				# Store as string
				$product_ref->{nutriments}{$field} .= "";
			}
			# fields like "salt", "salt_value"
			# -> used internally, should not be used by apps
			# store as numbers
			elsif (looks_like_number($product_ref->{nutriments}{$field})) {
				# Store as number
				$product_ref->{nutriments}{$field} += 0.0;
			}
		}
	}

	# Make sure product _id and code are saved as string and not a number
	# see bug #1077 - https://github.com/openfoodfacts/openfoodfacts-server/issues/1077
	# make sure that code is saved as a string, otherwise mongodb saves it as number, and leading 0s are removed
	# Note: #$product_ref->{code} .= ''; does not seem to be enough to force the type to be a string
	$product_ref->{_id} = "$product_ref->{_id}";
	$product_ref->{code} = "$product_ref->{code}";

	return;
}

=head2 assign_new_code ( )

C<assign_new_code()> assigns a new unused code to store a new product
that does not have a barcode.

	my ($code, $product_id) = assign_new_code();

=head3 Return values

A list with the new code and the corresponding product_id.

=head3 Caveats

=head4 Invalid codes

This function currently assign new codes in sequence starting from 2000000000001.
We increment the number by 1 for each product (which means codes are not valid as the
last digit is supposed to be the check digit), and check if there is already a product for that number.

=head4 Code conflicts

Codes starting with 2 are reserved for internal uses, there may be conflicts as other
companies can use the same codes.

=cut

sub assign_new_code() {

	my $code = 2000000000001;    # Codes beginning with 2 are for internal use

	my $internal_code_ref = retrieve("$BASE_DIRS{PRODUCTS}/internal_code.sto");
	if ((defined $internal_code_ref) and (${$internal_code_ref} > $code)) {
		$code = ${$internal_code_ref};
	}

	my $product_id = product_id_for_owner($Owner_id, $code);

	while (-e ("$BASE_DIRS{PRODUCTS}/" . product_path_from_id($product_id))) {

		$code++;
		$product_id = product_id_for_owner($Owner_id, $code);
	}

	store("$BASE_DIRS{PRODUCTS}/internal_code.sto", \$code);

	$log->debug("assigning a new code", {code => $code, lc => $lc}) if $log->is_debug();

	return ($code, $product_id);
}

=head2 normalize_code()

C<normalize_code()> this function normalizes the product code by:
- running the given code through normalization method provided by GS1 to format a GS1 data string, or data URL to a GTIN,
- keeping only digits and removing spaces/dashes etc.,
- normalizing the length by adding leading zeroes or removing the leading zero (in case of 14 digit codes)

=head3 Arguments

Product Code in the Raw form: $code

=head3 Return Values

Normalized version of the code

=cut

sub normalize_code ($code) {

	if (defined $code) {
		($code, my $gs1_ai_data_str) = &normalize_code_with_gs1_ai($code);
		$code = normalize_code_zeroes($code);
	}
	return $code;
}

=head2 normalize_code_zeroes($code)

On disk, we store product files and images in directories named after the product code, and we add leading 0s to the paths.
So we need to normalize the number of leading 0s of product codes, so that we don't have 2 products for codes that differ only by leading 0s.

This function normalizes the product code by:
- removing leading zeroes,
- adding leading zeroes to have at least 13 digits,
- removing leading zeroes for EAN8s to keep only 8 digits

Note: this function adds leading 0s even if the GS1 code is not valid.

=cut

sub normalize_code_zeroes($code) {

	# Return the code as-is if it is not all digits
	if ($code !~ /^\d+$/) {
		return $code;
	}

	# Remove leading zeroes
	$code =~ s/^0+//;

	# Add leading zeroes to have at least 13 digits
	if (length($code) < 13) {
		$code = "0" x (13 - length($code)) . $code;
	}

	# Remove leading zeroes for EAN8s to keep only 8 digits
	if ((length($code) eq 13) and ($code =~ /^00000/)) {
		$code = $';
	}

	return $code;
}

=head2 is_valid_upc12($code)

C<is_valid_upc12()> this function validates a UPC-12 code by:
- checking if the input is exactly 12 digits long,
- verifying the check digit using the modulo 10 algorithm.

=head3 Arguments

UPC-12 Code in the Raw form: $code

=head3 Return Values

1 (true) if the UPC-12 code is valid, 0 (false) otherwise.

=cut

# use strict;
# use warnings;

sub is_valid_upc12 {
	my ($upc) = @_;

	# Check if the input is exactly 12 digits long
	return 0 unless $upc =~ /^\d{12}$/;

	# Extract the first 11 digits and the check digit
	my $check_digit = substr($upc, -1);
	my $upc_without_check_digit = substr($upc, 0, 11);

	# Calculate the check digit
	my $sum_odd = 0;
	my $sum_even = 0;
	for my $i (0 .. 10) {
		if ($i % 2 == 0) {
			$sum_odd += substr($upc_without_check_digit, $i, 1);
		}
		else {
			$sum_even += substr($upc_without_check_digit, $i, 1);
		}
	}
	my $total_sum = ($sum_odd * 3) + $sum_even;
	my $calculated_check_digit = (10 - ($total_sum % 10)) % 10;

	# Validate the check digit
	return $check_digit == $calculated_check_digit;
}

=head2 normalize_code_with_gs1_ai($code)

C<normalize_code_with_gs1_ai()> this function normalizes the product code by:
- running the given code through normalization method provided by GS1 to format a GS1 data string, or data URI to a GTIN,
- keeping only digits and removing spaces/dashes etc.,
- normalizing the length by adding leading zeroes or removing the leading zero (in case of 14 digit codes)

=head3 Arguments

Product Code in the Raw form: $code

=head3 Return Values

Normalized version of the code, and GS1 AI data string of the code, if a valid GS1 string was given as the argument

=cut

sub normalize_code_with_gs1_ai ($code) {

	my $ai_data_str;
	if (defined $code) {
		my ($gs1_code, $gs1_ai_data_str) = &_try_normalize_code_gs1($code);
		if ($gs1_code and $gs1_ai_data_str) {
			$code = $gs1_code;
			$ai_data_str = $gs1_ai_data_str;
		}

		# Keep only digits, remove spaces, dashes and everything else
		$code =~ s/\D//g;

		# might be upc12
		if (is_valid_upc12($code)) {
			$code = "0" . $code;
		}

		# Check if the length of the code is 14 and the first character is '0'
		if (length($code) == 14 && substr($code, 0, 1) eq '0') {
			# Drop the first zero
			$code = substr($code, 1);
		}
	}

	return ($code, $ai_data_str);
}

sub _try_normalize_code_gs1 ($code) {
	my $ai_data_str;
	eval {
		$code =~ s/[\N{U+001D}\N{U+241D}]/^/g;    # Replace FNC1/<GS1> with ^ for the GS1Encoder to work
		if ($code =~ /^\(.+/) {
			# Code could be a GS1 bracketed AI element string
			my $encoder = GS1::SyntaxEngine::FFI::GS1Encoder->new();
			if ($encoder->ai_data_str($code)) {
				$ai_data_str = $encoder->ai_data_str();
			}
		}
		elsif ($code =~ /^\^.+/) {
			# Code could be a GS1 unbracketed AI element string
			my $encoder = GS1::SyntaxEngine::FFI::GS1Encoder->new();
			if ($encoder->data_str($code)) {
				$ai_data_str = $encoder->ai_data_str();
			}
		}
		elsif ($code =~ /^http?s:\/\/.+/) {
			# Code could be a GS1 unbracketed AI element string
			my $encoder = GS1::SyntaxEngine::FFI::GS1Encoder->new();
			if ($encoder->data_str($code)) {
				$ai_data_str = $encoder->ai_data_str();
			}
		}
		elsif ($code =~ /^01(\d{14})/) {
			# Code could be a GS1 unbracketed AI element string
			my $encoder = GS1::SyntaxEngine::FFI::GS1Encoder->new();
			if ($encoder->data_str("^01$1")) {
				$ai_data_str = $encoder->ai_data_str();
			}
		}
	};
	if ($@) {
		# $log->warn("GS1Parser error", {error => $@}) if $log->is_warn();
		$code = undef;
		$ai_data_str = undef;
	}

	if ((defined $code) and (defined $ai_data_str) and ($ai_data_str =~ /^\(01\)(\d{1,14})/)) {
		return ($1, $ai_data_str);
	}
	else {
		return;
	}
}

# - When products are public, the _id is the code, and the path is of the form 123/456/789/0123
# - When products are private, the _id is [owner]/[code] (e.g. user-abc/1234567890123 or org-xyz/1234567890123
# FIXME: bug #677

=head2 is_valid_code($code)

C<is_valid_code()> checks if the given code is a valid product code.

=head3 Arguments

Product Code: $code

=head3 Return Values

Boolean value indicating if the code is valid or not.

=cut

sub is_valid_code ($code) {
	# Return an empty string if $code is undef
	return '' if !defined $code;
	return $code =~ /^\d{4,40}$/;
}

=head2 split_code()

C<split_code()> this function splits the product code for determining the product path and the _id.
product_path_from_id() utilizes this for the said purpose.

=head3 Arguments

Product Code: $code

=head3 Return Values

Code that has been split into 3 sections of three digits and one fourth section with the remaining digits.
Example: 1234567890123  :-  123/456/789/0123

=cut

sub split_code ($code) {

	# Require at least 4 digits (some stores use very short internal barcodes, they are likely to be conflicting)
	if (not is_valid_code($code)) {

		$log->info("invalid code", {code => $code}) if $log->is_info();
		return "invalid";
	}

	# Remove leading zeroes
	$code =~ s/^0+//;

	# Pad code with 0s if it has less than 13 digits
	if (length($code) < 13) {
		$code = "0" x (13 - length($code)) . $code;
	}

	# First splits into 3 sections of 3 numbers and the last section with the remaining numbers
	my $path = $code;
	if ($code =~ /^(.{3})(.{3})(.{3})(.*)$/) {
		$path = "$1/$2/$3/$4";
	}
	return $path;
}

=head2 product_id_for_owner ( OWNER_ID, CODE )

C<product_id_for_owner()> returns the product id associated with a product barcode.

If the products on the server are public, the product id is equal to the product code.

If the products on the server are private (e.g. on the platform for producers),
the product_id is of the form user-[user id]/[code] or org-[organization id]/code.

=head3 Parameters

=head4 Owner id

=head4 Code

Product barcode

In most cases, pass $Owner_id which is initialized by ProductOpener::Users::init_user()

  undef for public products
  user-[user id] or org-[organization id] for private products

=head3 Return values

The product id.

=cut

sub product_id_for_owner ($ownerid, $code) {

	if ($server_options{private_products}) {
		if (defined $ownerid) {
			return $ownerid . "/" . $code;
		}
		else {
			# Should not happen
			die("Owner not set");
		}
	}
	else {
		return $code;
	}
}

=head2 server_for_product_type ( $product_type )

Returns the server for the product, if it is not on the current server.

=head3 Parameters

=head4 $product_type

=head3 Return values

undef is the product is on the current server, or server id of the server of the product otherwise.

=cut

sub server_for_product_type ($product_type) {

	if ((defined $product_type) and ($product_type ne $options{product_type})) {

		return $options{product_types_flavors}{$product_type};
	}

	return;
}

=head2 get_server_for_product ( $product_ref )

Return the MongoDB database for the product: off, obf, opf, opff or off-pro

If we are on the producers platform, we currently have only one server: off-pro

=cut

sub get_server_for_product ($product_ref) {

	my $server;

	# On the pro platform, we currently have only one server
	if ($server_options{private_products}) {
		$server = $mongodb;    # off-pro
	}
	else {
		# In case we need to move a product from OFF to OBF etc.
		# we will have a old_product_type field

		$server
			= $options{product_types_flavors}{$product_ref->{old_product_type}
				|| $product_ref->{product_type}
				|| $options{product_type}};

	}

	return $server;
}

=head2 product_path_from_id ( $product_id )

Returns the relative path for the product.

=head3 Parameters

=head4 $product_id

Product id of the form [code], [owner-id]/[code]

=head3 Return values

The relative path for the product.

=cut

sub product_path_from_id ($product_id) {

	if (    ($server_options{private_products})
		and ($product_id =~ /\//))
	{
		return $` . "/" . split_code($');
	}
	else {
		return split_code($product_id);
	}

}

=head2 product_path ( $product_ref )

Returns the relative path for the product.

=head3 Parameters

=head4 $product_ref

Product object reference.

=head3 Return values

The relative path for the product.

=cut

sub product_path ($product_ref) {

	# Previous version of product_path() was expecting the code instead of a reference to the product object
	if (ref($product_ref) ne 'HASH') {
		die("Argument of product_path() must be a reference to the product hash object, not a scalar: $product_ref\n");
	}

	if ($server_options{private_products}) {
		return $product_ref->{owner} . "/" . split_code($product_ref->{code});
	}
	else {
		return split_code($product_ref->{code});
	}
}

=head2 product_id_from_path ( $product_path )

Reverse of product_path_from_id.

There is no guarantee the result will be correct... but it's way faster than loading the sto !

=cut

sub product_id_from_path ($product_path) {
	my $id = $product_path;
	# only keep dir
	if ($id =~ /\.sto$/) {
		$id = dirname($id);
	}
	# eventually remove root path
	my $root = quotemeta("$BASE_DIRS{PRODUCTS}/");
	$id =~ s/^$root//;
	# transform to id by simply removing "/"
	$id =~ s/\///g;
	return $id;
}

sub get_owner_id ($userid, $orgid, $ownerid) {

	if ($server_options{private_products}) {

		if (not defined $ownerid) {
			if (defined $orgid) {
				$ownerid = "org-" . $orgid;
			}
			else {
				$ownerid = "user-" . $userid;
			}
		}
	}

	return $ownerid;
}

=head2 init_product ( $userid, $orgid, $code, $countryid )

Initializes and return a $product_ref structure for a new product.
If $countryid is defined and is not "en:world", then assign this country for the countries field.
Otherwise, use the country associated with the ip address of the user.

=head3 Return Type

Returns a $product_ref structure

=cut

sub init_product ($userid, $orgid, $code, $countryid) {

	$log->debug("init_product", {userid => $userid, orgid => $orgid, code => $code, countryid => $countryid})
		if $log->is_debug();

	# We can have a server passed in the code. e.g. obf:43242345
	my $server;
	if ($code =~ /:/) {
		$server = $`;
		$code = $';
		$log->debug("init_product - found server in code",
			{userid => $userid, orgid => $orgid, server => $server, code => $code, countryid => $countryid})
			if $log->is_debug();
	}

	my $creator = $userid;

	if ((not defined $userid) or ($userid eq '')) {
		$creator = "openfoodfacts-contributors";
	}

	my $product_ref = {
		id => $code . '',    # treat code as string
		_id => $code . '',
		code => $code . '',    # treat code as string
		created_t => time(),
		creator => $creator,
		rev => 0,
		product_type => $options{product_type},
	};

	if (defined $server) {
		$product_ref->{server} = $server;
	}

	if ($server_options{private_products}) {
		my $ownerid = get_owner_id($userid, $orgid, $Owner_id);

		$product_ref->{owner} = $ownerid;
		$product_ref->{_id} = $ownerid . "/" . $code;

		$log->debug(
			"init_product - private_products enabled",
			{
				userid => $userid,
				orgid => $orgid,
				code => $code,
				ownerid => $ownerid,
				product_id => $product_ref->{_id}
			}
		) if $log->is_debug();
	}

	my $country;

	if (((not defined $countryid) or ($countryid eq "en:world")) and (remote_addr() ne "127.0.0.1")) {
		$country = ProductOpener::GeoIP::get_country_for_ip(remote_addr());
	}
	elsif ((defined $countryid) and ($countryid ne "en:world")) {
		$country = $countryid;
		$country =~ s/^en://;
	}

	# ugly fix: products added by yuka should have country france, regardless of the server ip
	if ($creator eq 'kiliweb') {
		if (defined single_param('cc')) {
			$country = lc(single_param('cc'));
			$country =~ s/^en://;

			# 01/06/2019 --> Yuka always sends fr fields even for Spanish products, try to correct it
			my %lc_overrides = (
				au => "en",
				es => "es",
				it => "it",
				de => "de",
				uk => "en",
				gb => "en",
				pt => "pt",
				nl => "nl",
				us => "en",
				ie => "en",
				nz => "en",
			);

			if (defined $lc_overrides{$country}) {
				$lc = $lc_overrides{$country};
			}
		}
		else {
			$country = "france";
		}
	}

	# ugly fix: elcoco -> Spain
	if ($creator eq 'elcoco') {
		$country = "spain";
	}

	if (defined $lc) {
		$product_ref->{lc} = $lc;
		$product_ref->{lang} = $lc;
	}

	if ((defined $country) and ($country !~ /^world$/i)) {
		if ($country !~ /a1|a2|o1/i) {
			$product_ref->{countries} = "en:" . $country;
			my $field = 'countries';
			if (defined $taxonomy_fields{$field}) {
				$product_ref->{$field . "_hierarchy"}
					= [gen_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field})];
				$product_ref->{$field . "_tags"} = [];
				foreach my $tag (@{$product_ref->{$field . "_hierarchy"}}) {
					push @{$product_ref->{$field . "_tags"}}, get_taxonomyid("en", $tag);
				}
			}
			# if lc is not defined or is set to en, set lc to main language of country
			if (    ($lc eq 'en')
				and (defined $country_languages{lc($country)})
				and (defined $country_languages{lc($country)}[0]))
			{
				$product_ref->{lc} = $country_languages{lc($country)}[0];
			}
		}
	}
	return $product_ref;
}

sub retrieve_product ($product_id, $include_deleted = 0, $rev = undef) {

	my $path = product_path_from_id($product_id);

	my $full_product_path;

	if (defined $rev) {
		# check that $rev is a number
		if ($rev !~ /^\d+$/) {
			return;
		}
		$full_product_path = "$BASE_DIRS{PRODUCTS}/$path/$rev.sto";
	}
	else {
		$full_product_path = "$BASE_DIRS{PRODUCTS}/$path/product.sto";
	}

	$log->debug(
		"retrieve_product",
		{
			product_id => $product_id,
			rev => $rev,
			full_product_path => $full_product_path
		}
	) if $log->is_debug();

	my $product_ref = retrieve($full_product_path);

	if (not defined $product_ref) {
		$log->debug("retrieve_product - product does not exist", {product_id => $product_id, path => $path})
			if $log->is_debug();
	}
	else {
		if (($product_ref->{deleted}) and (not $include_deleted)) {
			$log->debug(
				"retrieve_product - deleted product",
				{
					product_id => $product_id,
					path => $path,
				}
			) if $log->is_debug();
			return;
		}

		# If the product is on another server, set the server field so that it will be saved in the other server if we save it

		my $server = server_for_product_type($product_ref->{product_type});

		if (defined $server) {
			$product_ref->{server} = $server;
			$log->debug(
				"retrieve_product - product on another server",
				{
					product_id => $product_id,
					path => $path,
					server => $server
				}
			) if $log->is_debug();
		}
		else {
			# If the product was moved previously, it may have a server field, remove it
			delete $product_ref->{server};
		}
	}

	# We may read a product file that was saved with an old version of the schema
	# If so, we convert it to the current schema
	convert_product_schema($product_ref, $current_schema_version);

	normalize_product_data($product_ref);

	return $product_ref;
}

=head2 change_product_code ($product_ref, $new_code)

Utility function to change the barcode of a product.
Fails and returns an error if the code is invalid, or if there is already a product with the new code.

=head3 Parameters

=head4 $product_ref

=head4 $new_code

=head3 Return value

If successful: undef
If there was an error: invalid_code or new_code_already_exists

=cut

sub change_product_code ($product_ref, $new_code) {

	# Currently only called by admins and moderators

	my $code = $product_ref->{code};

	$new_code = normalize_code($new_code);
	if (not is_valid_code($new_code)) {
		return "invalid_code";
	}
	else {
		# check that the new code is available
		if (-e "$BASE_DIRS{PRODUCTS}/" . product_path_from_id($new_code) . "/product.sto") {
			$log->warn("cannot change product code, because the new code already exists",
				{code => $code, new_code => $new_code})
				if $log->is_warn();
			return "error_new_code_already_exists";
		}
		else {
			$product_ref->{old_code} = $code;
			$code = $new_code;
			$product_ref->{code} = $code;
			$log->info("changing code", {old_code => $product_ref->{old_code}, code => $code})
				if $log->is_info();
		}
	}

	return;
}

=head2 change_product_type ($product_ref, $new_product_type)

Utility function to change the product type of a product.
Fails and returns an error if the product type is invalid.

=head3 Parameters

=head4 $product_ref

=head4 $new_product_type

=head3 Return value

If successful: undef
If there was an error: invalid_product_type

=cut

sub change_product_type ($product_ref, $new_product_type) {

	# Currently only called by admins and moderators

	my $product_type = $product_ref->{product_type};

	# Return if the product type is already the new product type, or if the new product type is not defined
	if ((not defined $new_product_type) or ((not defined $options{product_types_flavors}{$new_product_type}))) {
		return "invalid_product_type";
	}
	elsif ($product_type ne $new_product_type) {
		$product_ref->{old_product_type} = $product_type;
		$product_ref->{product_type} = $new_product_type;
		$log->info("changing product type",
			{old_product_type => $product_ref->{old_product_type}, product_type => $new_product_type})
			if $log->is_info();
	}

	return;
}

=head2 compute_sort_keys ( $product_ref )

Compute sort keys that are stored in the MongoDB database and used to order results of queries.

=head3 last_modified_t - date of last modification of the product page

Used on the web site for facets pages, except the index page.

=head3 popularity_key - Popular and recent products

Used for the Personal Search project to provide generic search results that apps can personalize later.

=cut

sub compute_sort_keys ($product_ref) {

	my $popularity_key = 0;

	# Use the popularity tags
	if (defined $product_ref->{popularity_tags}) {
		my %years = ();
		my $latest_year;
		foreach my $tag (@{$product_ref->{popularity_tags}}) {
			# one product could have:
			# "top-50000-scans-2019",
			# "top-100000-scans-2019",
			# "top-100000-scans-2020",
			if ($tag =~ /^top-(\d+)-scans-20(\d\d)$/) {
				my $top = $1;
				my $year = $2;
				# Save the smaller top for each year
				if ((not defined $years{$year}) or ($years{$year} > $top)) {
					$years{$year} = $top;
				}
				if ((not defined $latest_year) or ($year > $latest_year)) {
					$latest_year = $year;
				}
			}
		}
		# Keep only the latest year, and make the latest year count more than previous years
		if (defined $latest_year) {
			$popularity_key += $latest_year * 1000000 * 1000 - $years{$latest_year} * 1000;
		}
	}

	# unique_scans_n : number of unique scans for the last year processed by scanbot.pl
	if (defined $product_ref->{unique_scans_n}) {
		$popularity_key += $product_ref->{unique_scans_n};
	}

	# give a small boost to products for which we have recent images
	if (defined $product_ref->{last_image_t}) {

		my $age = int((time() - $product_ref->{last_image_t}) / (86400 * 30));    # in months
		if ($age < 12) {
			$popularity_key += 12 - $age;
		}
	}

	# Add 0 so we are sure the key is saved as int
	$product_ref->{popularity_key} = $popularity_key + 0;

	return;
}

=head2 store_product ($user_id, $product_ref, $comment)

Save changes of a product:
- in a new .sto file on the disk
- in MongoDB (in the products collection, or products_obsolete collection if the product is obsolete)

Before saving, some field values are computed, and product history and completeness is computed.

=cut

sub store_product ($user_id, $product_ref, $comment) {

	my $code = $product_ref->{code};
	my $product_id = $product_ref->{_id};
	my $path = product_path($product_ref);
	my $rev = $product_ref->{rev};
	my $action = "updated";

	# Update product schema version
	$product_ref->{schema_version} = $current_schema_version;

	$log->debug(
		"store_product - start",
		{
			code => $code,
			product_id => $product_id,
			obsolete => $product_ref->{obsolete},
			was_obsolete => $product_ref->{was_obsolete}
		}
	) if $log->is_debug();

	my $delete_from_previous_products_collection = 0;

	# if we have a "server" value (e.g. from an import),
	# we save the product on the corresponding server but we don't need to move an existing product
	if (defined $product_ref->{server}) {
		my $new_server = $product_ref->{server};
		# Update the product_type from the server
		if (defined $options{flavors_product_types}{$new_server}) {
			my $error = change_product_type($product_ref, $options{flavors_product_types}{$new_server});
			# Log if we have an error
			if ($error) {
				$log->error("store_product - change_product_type - error",
					{error => $error, product_ref => $product_ref});
			}
		}
		delete $product_ref->{server};
	}

	# If we do not have a product_type, we set it to the default product_type of the current server
	# This can happen if we are reverting a product to a previous version that did not have a product_type
	if (not defined $product_ref->{product_type}) {
		$product_ref->{product_type} = $options{product_type};
	}

	# In case we need to move a product from OFF to OBF etc.
	# we will have a old_product_type field

	# Get the previous server and collection for the product
	my $previous_server = get_server_for_product($product_ref);

	# We use the was_obsolete flag so that we can remove the product from its old collection
	# (either products or products_obsolete) if its obsolete status has changed
	my $previous_products_collection = get_products_collection(
		{database => $options{other_servers}{$previous_server}{mongodb}, obsolete => $product_ref->{was_obsolete}});

	# Change of product type
	if (defined $product_ref->{old_product_type}) {
		$log->info("changing product type",
			{old_product_type => $product_ref->{old_product_type}, product_type => $product_ref->{product_type}})
			if $log->is_info();
		$delete_from_previous_products_collection = 1;
		delete $product_ref->{old_product_type};
	}

	# Get the server and collection for the product that we will write
	my $new_server = get_server_for_product($product_ref);
	my $new_products_collection = get_products_collection(
		{database => $options{other_servers}{$new_server}{mongodb}, obsolete => $product_ref->{obsolete}});

	if ($previous_server ne $new_server) {
		$log->info("changing server", {old_server => $previous_server, new_server => $new_server, code => $code})
			if $log->is_info();
		$delete_from_previous_products_collection = 1;
	}

	# the obsolete (and was_obsolete) field is either undef or an empty string, or contains "on"
	if (   ($product_ref->{was_obsolete} and not $product_ref->{obsolete})
		or (not $product_ref->{was_obsolete} and $product_ref->{obsolete}))
	{
		# The obsolete status changed, we need to remove the product from its previous collection
		$log->debug(
			"obsolete status changed",
			{
				code => $code,
				product_id => $product_id,
				obsolete => $product_ref->{obsolete},
				was_obsolete => $product_ref->{was_obsolete},
				previous_products_collection => $previous_products_collection
			}
		) if $log->is_debug();
		$delete_from_previous_products_collection = 1;

		if ($product_ref->{obsolete} eq 'on') {
			$action = "archived";
		}
		elsif ($product_ref->{was_obsolete} eq 'on') {
			$action = "unarchived";
		}
	}

	delete $product_ref->{was_obsolete};

	# Change of barcode
	if (defined $product_ref->{old_code}) {

		my $old_code = $product_ref->{old_code};
		my $old_product_id = product_id_for_owner($Owner_id, $old_code);
		my $old_path = product_path_from_id($old_product_id);

		$log->info("moving product", {old_code => $old_code, code => $code})
			if $log->is_info();

		# Move directory

		my $prefix_path = $path;
		$prefix_path =~ s/\/[^\/]+$//;    # remove the last subdir: we'll move it

		$log->debug("creating product directories", {path => $path, prefix_path => $prefix_path}) if $log->is_debug();
		# Create the directories for the product
		ensure_dir_created_or_die("$BASE_DIRS{PRODUCTS}/$prefix_path");
		ensure_dir_created_or_die("$BASE_DIRS{PRODUCTS_IMAGES}/$prefix_path");

		# Check if we are updating the product in place:
		# the code changed, but it is the same path
		# this can happen if the path is already normalized, but the code is not
		# in that case we just want to update the code, and remove the old one from MongoDB
		# we don't need to move the directories
		if ("$BASE_DIRS{PRODUCTS}/$old_path" eq "$BASE_DIRS{PRODUCTS}/$path") {
			$log->debug("updating product code in place", {old_code => $old_code, code => $code}) if $log->is_debug();
			delete $product_ref->{old_code};
			# remove the old product from the previous collection
			if ($delete_from_previous_products_collection) {
				execute_query(
					sub {
						return $previous_products_collection->delete_one({"_id" => $product_ref->{_id}});
					}
				);
			}
			$product_ref->{_id} = $product_ref->{code} . '';    # treat id as string;
		}

		if (    (!-e "$BASE_DIRS{PRODUCTS}/$path")
			and (!-e "$BASE_DIRS{PRODUCTS_IMAGES}/$path"))
		{
			# File::Copy move() is intended to move files, not
			# directories. It does work on directories if the
			# source and target are on the same file system
			# (in which case the directory is just renamed),
			# but fails otherwise.
			# An alternative is to use File::Copy::Recursive
			# but then it will do a copy even if it is the same
			# file system...
			# Another option is to call the system mv command.
			#
			# use File::Copy;

			File::Copy::Recursive->import(qw( dirmove ));

			$log->debug("moving product data",
				{source => "$BASE_DIRS{PRODUCTS}/$old_path", destination => "$BASE_DIRS{PRODUCTS}/$path"})
				if $log->is_debug();
			dirmove("$BASE_DIRS{PRODUCTS}/$old_path", "$BASE_DIRS{PRODUCTS}/$path")
				or $log->error(
				"could not move product data",
				{
					source => "$BASE_DIRS{PRODUCTS}/$old_path",
					destination => "$BASE_DIRS{PRODUCTS}/$path",
					error => $!
				}
				);

			$log->debug(
				"moving product images",
				{
					source => "$BASE_DIRS{PRODUCTS_IMAGES}/$old_path",
					destination => "$BASE_DIRS{PRODUCTS_IMAGES}/$path"
				}
			) if $log->is_debug();
			dirmove("$BASE_DIRS{PRODUCTS_IMAGES}/$old_path", "$BASE_DIRS{PRODUCTS_IMAGES}/$path")
				or $log->error(
				"could not move product images",
				{
					source => "$BASE_DIRS{PRODUCTS_IMAGES}/$old_path",
					destination => "$BASE_DIRS{PRODUCTS_IMAGES}/$path",
					error => $!
				}
				);
			$log->debug("images and data moved");

			delete $product_ref->{old_code};

			execute_query(
				sub {
					return $previous_products_collection->delete_one({"_id" => $product_ref->{_id}});
				}
			);

			$product_ref->{_id} = $product_ref->{code} . '';    # treat id as string;

		}
		else {
			(-e "$BASE_DIRS{PRODUCTS}/$path")
				and $log->error("cannot move product data, because the destination already exists",
				{source => "$BASE_DIRS{PRODUCTS}/$old_path", destination => "$BASE_DIRS{PRODUCTS}/$path"});
			(-e "$BASE_DIRS{PRODUCTS_IMAGES}/$path")
				and $log->error(
				"cannot move product images data, because the destination already exists",
				{
					source => "$BASE_DIRS{PRODUCTS_IMAGES}/$old_path",
					destination => "$BASE_DIRS{PRODUCTS_IMAGES}/$path"
				}
				);
		}

		$comment .= " - barcode changed from $old_code to $code by $user_id";
	}

	if ($rev < 1) {
		# Create the directories for the product
		ensure_dir_created_or_die("$BASE_DIRS{PRODUCTS}/$path");
		ensure_dir_created_or_die("$BASE_DIRS{PRODUCTS_IMAGES}/$path");
	}

	# Check lock and previous version
	my $changes_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/changes.sto");
	if (not defined $changes_ref) {
		$changes_ref = [];
	}
	my $current_rev = scalar @{$changes_ref};
	if ($rev != $current_rev) {
		# The product was updated after the form was loaded..

		# New product over deleted product?
		# can be also bug https://github.com/openfoodfacts/openfoodfacts-server/issues/2321
		# where 2 changes were recorded in the same rev
		# to avoid similar bugs, and to have the same number of changes and rev,
		# assign the number of changes to the rev
		if ($rev < $current_rev) {
			$rev = $current_rev;
		}
	}

	# Increment the revision
	$rev++;

	$product_ref->{rev} = $rev;
	# last_modified_t is the date of the last change of the product raw data
	# last_updated_t is the date of the last change of the product derived data (e.g. ingredient analysis, scores etc.)
	$product_ref->{last_modified_by} = $user_id;
	$product_ref->{last_modified_t} = time() + 0;
	$product_ref->{last_updated_t} = $product_ref->{last_modified_t};
	if (not exists $product_ref->{creator}) {
		my $creator = $user_id;
		if ((not defined $user_id) or ($user_id eq '')) {
			$creator = "openfoodfacts-contributors";
		}
		$product_ref->{creator} = $creator;
	}

	if (defined $product_ref->{owner}) {
		$product_ref->{owners_tags} = $product_ref->{owner};
	}
	else {
		delete $product_ref->{owners_tags};
	}

	my $change_ref = {
		userid => $user_id,
		ip => remote_addr(),
		t => $product_ref->{last_modified_t},
		comment => $comment,
		rev => $rev,
	};

	# Allow apps to send the user agent as a form parameter instead of a HTTP header, as some web based apps can't change the User-Agent header sent by the browser
	my $user_agent
		= remove_tags_and_quote(decode utf8 => single_param("User-Agent"))
		|| remove_tags_and_quote(decode utf8 => single_param("user-agent"))
		|| remove_tags_and_quote(decode utf8 => single_param("user_agent"))
		|| user_agent();

	if ((defined $user_agent) and ($user_agent ne "")) {
		$change_ref->{user_agent} = $user_agent;
	}

	# Allow apps to send app_name, app_version and app_uuid parameters
	foreach my $field (qw(app_name app_version app_uuid)) {
		my $value = remove_tags_and_quote(decode utf8 => single_param($field));
		if ((defined $value) and ($value ne "")) {
			$change_ref->{$field} = $value;
		}
	}

	push @{$changes_ref}, $change_ref;

	add_user_teams($product_ref);

	compute_codes($product_ref);

	compute_languages($product_ref);

	my $blame_ref = {};

	compute_product_history_and_completeness($product_ref, $changes_ref, $blame_ref);

	compute_data_sources($product_ref, $changes_ref);

	compute_main_countries($product_ref);

	compute_sort_keys($product_ref);

	if (not defined $product_ref->{_id}) {
		$product_ref->{_id} = $product_ref->{code} . '';    # treat id as string
	}

	# index for full text search
	compute_keywords($product_ref);

	# make sure that the _id and code are saved as a string, otherwise mongodb may save them as numbers
	# for _id , it makes them possibly non unique, and for code, we would lose leading 0s
	$product_ref->{_id} .= '';
	$product_ref->{code} .= '';

	# make sure we have numbers, perl can convert numbers to string depending on the last operation done...
	$product_ref->{last_modified_t} += 0;
	$product_ref->{created_t} += 0;
	$product_ref->{complete} += 0;
	$product_ref->{popularity_key} += 0;
	$product_ref->{rev} += 0;

	# make sure nutrient values are numbers
	make_sure_numbers_are_stored_as_numbers($product_ref);

	$change_ref = $changes_ref->[-1];
	my $diffs = $change_ref->{diffs};
	my %diffs = %{$diffs};
	if ((!$diffs) or (!keys %diffs)) {
		$log->info("changes not stored because of empty diff", {change_ref => $change_ref}) if $log->is_info();
		# 2019/09/12 - this was deployed today, but it causes changes not to be saved
		# compute_product_history_and_completeness() was not written to make sure that it sees all changes
		# keeping the log and disabling the "return 0" so that all changes are saved
		#return 0;
	}

	# First store the product data in a .sto file on disk
	store("$BASE_DIRS{PRODUCTS}/$path/$rev.sto", $product_ref);

	# Also store the product in MongoDB, unless it was marked as deleted
	if ($product_ref->{deleted}) {
		$new_products_collection->delete_one({"_id" => $product_ref->{_id}});
	}
	else {
		$new_products_collection->replace_one({"_id" => $product_ref->{_id}}, $product_ref, {upsert => 1});
	}

	# product that has a changed obsolete status
	if ($delete_from_previous_products_collection) {
		$previous_products_collection->delete_one({"_id" => $product_ref->{_id}});
	}

	# Update link
	my $link = "$BASE_DIRS{PRODUCTS}/$path/product.sto";
	if (-l $link) {
		unlink($link) or $log->error("could not unlink old product.sto", {link => $link, error => $!});
	}

	symlink("$rev.sto", $link)
		or $log->error("could not symlink to new revision",
		{source => "$BASE_DIRS{PRODUCTS}/$path/$rev.sto", link => $link, error => $!});

	store("$BASE_DIRS{PRODUCTS}/$path/changes.sto", $changes_ref);
	log_change($product_ref, $change_ref);

	$log->debug("store_product - done", {code => $code, product_id => $product_id}) if $log->is_debug();

	if ($product_ref->{deleted}) {
		$action = "deleted";
	}
	elsif ($rev == 1) {
		$action = "created";
	}

	# Publish information about update on Redis stream
	$log->debug("push_to_redis_stream",
		{code => $code, product_id => $product_id, action => $action, comment => $comment, diffs => $diffs})
		if $log->is_debug();
	push_to_redis_stream($user_id, $product_ref, $action, $comment, $diffs);

	return 1;
}

=head2 compute_data_sources ( $product_ref, $changes_ref )

Analyze the sources field of the product, as well as the changes to add to the data_sources field.

Sources allows to add some producers imports that were done before the producers platform was created.

The changes structure allows to add apps.

=cut

sub compute_data_sources ($product_ref, $changes_ref) {

	my %data_sources = ();

	if (defined $product_ref->{sources}) {
		foreach my $source_ref (@{$product_ref->{sources}}) {

			next if not defined $source_ref->{id};

			if ($source_ref->{id} eq 'casino') {
				$data_sources{"Producers"} = 1;
				$data_sources{"Producer - Casino"} = 1;
			}
			if ($source_ref->{id} eq 'carrefour') {
				$data_sources{"Producers"} = 1;
				$data_sources{"Producer - Carrefour"} = 1;
			}
			if ($source_ref->{id} eq 'ferrero') {
				$data_sources{"Producers"} = 1;
				$data_sources{"Producer - Ferrero"} = 1;
			}
			if ($source_ref->{id} eq 'fleurymichon') {
				$data_sources{"Producers"} = 1;
				$data_sources{"Producer - Fleury Michon"} = 1;
			}
			if ($source_ref->{id} eq 'iglo') {
				$data_sources{"Producers"} = 1;
				$data_sources{"Producer - Iglo"} = 1;
			}
			if ($source_ref->{id} eq 'ldc') {
				$data_sources{"Producers"} = 1;
				$data_sources{"Producer - LDC"} = 1;
			}
			if ($source_ref->{id} eq 'sodebo') {
				$data_sources{"Producers"} = 1;
				$data_sources{"Producer - Sodebo"} = 1;
			}
			if ($source_ref->{id} eq 'systemeu') {
				$data_sources{"Producers"} = 1;
				$data_sources{"Producer - Systeme U"} = 1;
			}
			if ($source_ref->{id} eq 'biscuiterie-sainte-victoire') {
				$data_sources{"Producers"} = 1;
				$data_sources{"Producer - Biscuiterie Sainte Victoire"} = 1;
			}

			if ($source_ref->{id} eq 'openfood-ch') {
				$data_sources{"Databases"} = 1;
				$data_sources{"Database - FoodRepo / openfood.ch"} = 1;
			}
			if ($source_ref->{id} eq 'usda-ndb') {
				$data_sources{"Databases"} = 1;
				$data_sources{"Database - USDA NDB"} = 1;
			}
			if ($source_ref->{id} eq 'codeonline') {
				$data_sources{"Databases"} = 1;
				$data_sources{"Database - CodeOnline"} = 1;
				$data_sources{"Database - GDSN"} = 1;
			}
			if ($source_ref->{id} eq 'equadis') {
				$data_sources{"Databases"} = 1;
				$data_sources{"Database - Equadis"} = 1;
				$data_sources{"Database - GDSN"} = 1;
			}
			if ($source_ref->{id} eq 'agena3000') {
				$data_sources{"Databases"} = 1;
				$data_sources{"Database - Agena3000"} = 1;
				$data_sources{"Database - GDSN"} = 1;
			}
		}
	}

	# Add a data source for apps

	foreach my $change_ref (@$changes_ref) {

		if (defined $change_ref->{app}) {

			my $app_name = deep_get(\%options, "apps_names", $change_ref->{app}) || $change_ref->{app};

			$data_sources{"Apps"} = 1;
			$data_sources{"App - " . $app_name} = 1;
		}
	}

	if ((scalar keys %data_sources) > 0) {
		add_tags_to_field($product_ref, "en", "data_sources", join(',', sort keys %data_sources));
	}

	return;
}

=head2 normalize_product_data($product_ref)

Function to do some normalization of product data (from the product database or input product data from a service)

=cut

sub normalize_product_data($product_ref) {

	# We currently have two fields lang and lc that are used to store the main language of the product
	# TODO: at some point, we should keep only one field
	# In theory, they should always have a value (defaulting to English), and they should be the same
	# It is possible that in some situations, one or the other is missing
	# e.g. when a product service is called directly with product data, and the product is not loaded
	# through the database or the .sto file.
	# some old revisions may also have missing values

	my $main_lc = $product_ref->{lc} || $product_ref->{lang} || "en";
	$product_ref->{lang} = $main_lc;
	$product_ref->{lc} = $main_lc;

	return;
}

sub compute_completeness_and_missing_tags ($product_ref, $current_ref, $previous_ref) {

	normalize_product_data($product_ref);
	my $lc = $product_ref->{lc};

	# Compute completeness and missing tags

	my @states_tags = ();

	# Images

	my $complete = 1;
	my $notempty = 0;
	my $step = 1.0 / 10.0;    # Currently, we check for 10 items.
	my $completeness = 0.0;

	if (scalar keys %{$current_ref->{uploaded_images}} < 1) {
		push @states_tags, "en:photos-to-be-uploaded";
		$complete = 0;
	}
	else {
		push @states_tags, "en:photos-uploaded";
		my $half_step = $step * 0.5;
		$completeness += $half_step;

		my $image_step = $half_step * (1.0 / 4.0);

		my $images_completeness = 0;

		foreach my $imagetype (qw(front ingredients nutrition packaging)) {

			if (defined $current_ref->{selected_images}{$imagetype . "_" . $lc}) {
				$images_completeness += $image_step;
				push @states_tags, "en:" . $imagetype . "-photo-selected";
			}
			else {
				if (    ($imagetype eq "nutrition")
					and (defined $product_ref->{no_nutrition_data})
					and ($product_ref->{no_nutrition_data} eq 'on'))
				{
					$images_completeness += $image_step;
				}
				else {
					push @states_tags, "en:" . $imagetype . "-photo-to-be-selected";
				}
			}
		}

		$completeness += $images_completeness;

		if ($images_completeness == $half_step) {
			push @states_tags, "en:photos-validated";

		}
		else {
			push @states_tags, "en:photos-to-be-validated";
			$complete = 0;
		}
		$notempty++;
	}

	my @needed_fields = qw(product_name quantity packaging brands categories origins);
	my $all_fields = 1;
	foreach my $field (@needed_fields) {
		if ((not defined $product_ref->{$field}) or ($product_ref->{$field} eq '')) {
			$all_fields = 0;
			push @states_tags, "en:" . get_string_id_for_lang("en", $field) . "-to-be-completed";
		}
		else {
			push @states_tags, "en:" . get_string_id_for_lang("en", $field) . "-completed";
			$notempty++;
			$completeness += $step;
		}
	}

	if ($all_fields == 0) {
		push @states_tags, "en:characteristics-to-be-completed";
		$complete = 0;
	}
	else {
		push @states_tags, "en:characteristics-completed";
	}

	if ((defined $product_ref->{emb_codes}) and ($product_ref->{emb_codes} ne '')) {
		push @states_tags, "en:packaging-code-completed";
		$notempty++;
		$completeness += $step;
	}
	else {
		push @states_tags, "en:packaging-code-to-be-completed";
	}

	if ((defined $product_ref->{expiration_date}) and ($product_ref->{expiration_date} ne '')) {
		push @states_tags, "en:expiration-date-completed";
		$notempty++;
		$completeness += $step;
	}
	else {
		push @states_tags, "en:expiration-date-to-be-completed";
		# $complete = 0;
	}

	if (    (defined $product_ref->{ingredients_text})
		and ($product_ref->{ingredients_text} ne '')
		and (not($product_ref->{ingredients_text} =~ /\?/)))
	{
		push @states_tags, "en:ingredients-completed";
		$notempty++;
		$completeness += $step;
	}
	else {
		push @states_tags, "en:ingredients-to-be-completed";
		$complete = 0;
	}

	if (
		(
			(
					(defined $current_ref->{nutriments})
				and (scalar grep {$_ !~ /^(nova|fruits-vegetables)/} keys %{$current_ref->{nutriments}}) > 0
			)
		)
		or ((defined $product_ref->{no_nutrition_data}) and ($product_ref->{no_nutrition_data} eq 'on'))
		)
	{
		push @states_tags, "en:nutrition-facts-completed";
		$notempty++;
		$completeness += $step;
	}
	else {
		push @states_tags, "en:nutrition-facts-to-be-completed";
		$complete = 0;
	}

	if ($complete) {
		push @states_tags, "en:complete";

		if ((defined $product_ref->{checked}) and ($product_ref->{checked} eq 'on')) {
			push @states_tags, "en:checked";
		}
		else {
			push @states_tags, "en:to-be-checked";
		}
	}
	else {
		push @states_tags, "en:to-be-completed";
	}

	if ($notempty == 0) {
		$product_ref->{empty} = 1;
		push @states_tags, "en:empty";
	}
	else {
		delete $product_ref->{empty};
	}

	# On the producers platform, keep track of which products have changes to be exported
	if ($server_options{private_products}) {
		if (    (defined $product_ref->{last_exported_t})
			and ($product_ref->{last_exported_t} > $product_ref->{last_modified_t}))
		{
			push @states_tags, "en:exported";
		}
		else {
			push @states_tags, "en:to-be-exported";
			if ($product_ref->{to_be_automatically_exported}) {
				push @states_tags, "en:to-be-automatically-exported";
			}
		}
	}

	$product_ref->{complete} = $complete;
	$current_ref->{complete} = $complete;
	$product_ref->{completeness} = $completeness;
	$current_ref->{completeness} = $completeness;

	if ($complete) {
		if ((not defined $previous_ref->{complete}) or ($previous_ref->{complete} == 0)) {
			$product_ref->{completed_t} = $product_ref->{last_modified_t} + 0;
			$current_ref->{completed_t} = $product_ref->{last_modified_t} + 0;
		}
		else {
			$product_ref->{completed_t} = $previous_ref->{completed_t} + 0;
			$current_ref->{completed_t} = $previous_ref->{completed_t} + 0;
		}
	}
	else {
		delete $product_ref->{completed_t};
		delete $current_ref->{completed_t};
	}

	$product_ref->{states} = join(', ', reverse @states_tags);
	$product_ref->{"states_hierarchy"} = [reverse @states_tags];
	$product_ref->{"states_tags"} = [reverse @states_tags];

	#my $field = "states";
	#
	#$product_ref->{$field . "_hierarchy" } = [ gen_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field}) ];
	#$product_ref->{$field . "_tags" } = [];
	#foreach my $tag (@{$product_ref->{$field . "_hierarchy" }}) {
	#		push @{$product_ref->{$field . "_tags" }}, get_taxonomyid($tag);
	#}

	# old name
	delete $product_ref->{status};
	delete $product_ref->{status_tags};

	return;
}

=head2 get_change_userid_or_uuid ( $change_ref )

For a specific change, analyze change identifiers (comment, user agent, userid etc.)
to determine if the change was done through an app, the OFF userid, or an app specific UUID

=head3 Parameters

=head4 $change_ref

reference to a change record

=head3 Return value

The function returns by order of preference:
- a real user userid if we have an userid which is not the userid of an app
- an appid + app uuid (e.g. some-app.Z626FZF4RTFSG6)
- an app userid if the app did not provide an app uuid
- openfoodfacts-contributors

=cut

sub get_change_userid_or_uuid ($change_ref) {

	my $userid = $change_ref->{userid};

	my $app;
	my $app_userid_prefix;
	my $uuid;

	# Is the userid the userid of an app?
	if (defined $userid) {
		$app = deep_get(\%options, "apps_userids", $userid);
		if (defined $app) {
			# If the userid is an an account for an app, unset the userid,
			# so that it can be replaced by the app + an app uuid if provided
			$userid = undef;
		}
	}

	# Is it an app that sent an app_name?
	if ((not defined $app) and (defined $change_ref->{app_name})) {
		$app = get_string_id_for_lang("no_language", $change_ref->{app_name});
	}

	# Set the app field for the Open Food Facts app
	if (    (not defined $app)
		and (defined $options{official_app_comment})
		and ($change_ref->{comment} =~ /$options{official_app_comment}/i))
	{
		$app = $options{official_app_id};
	}

	# If we do not have a user specific userid (e.g. a logged in user using the Open Food Facts app),
	# try to identify the UUID passed in the comment by some apps

	# use UUID provided by some apps like Yuka
	# UUIDs are mix of [a-zA-Z0-9] chars, they must not be lowercased by getfile_id

	# (app)Waistline: e2e782b4-4fe8-4fd6-a27c-def46a12744c
	# (app)Labeleat1.0-SgP5kUuoerWvNH3KLZr75n6RFGA0
	# (app)Contributed using: OFF app for iOS - v3.0 - user id: 3C0154A0-D19B-49EA-946F-CC33A05E404A
	#
	# but not:
	# (app)Updated via Power User Script

	if ((defined $app) and ((not defined $userid) or ($userid eq ''))) {

		$app_userid_prefix = deep_get(\%options, "apps_uuid_prefix", $app);

		# Check if the app passed the app_uuid parameter
		if (defined $change_ref->{app_uuid}) {
			$uuid = $change_ref->{app_uuid};
		}
		# Extract UUID from comment
		elsif ( (defined $app_userid_prefix)
			and ($change_ref->{comment} =~ /$app_userid_prefix/i))
		{
			$uuid = $';
		}

		if (defined $uuid) {

			# Remove any app specific suffix
			my $app_userid_suffix = deep_get(\%options, "apps_uuid_suffix", $app);
			if (defined $app_userid_suffix) {
				$uuid =~ s/$app_userid_suffix(\s|\(|\[])*$//i;
			}

			$uuid =~ s/^(-|_|\s|\(|\[])+//;
			$uuid =~ s/(-|_|\s|\)|\])+$//;
		}

		# If we have a uuid from an app, make the userid a combination of app + uuid
		if ((defined $uuid) and ($uuid !~ /^(-|_|\s|-|_|\.)*$/)) {
			$userid = $app . '.' . $uuid;
		}
		# otherwise use the original userid used for the API if any
		elsif (defined $change_ref->{userid}) {
			$userid = $change_ref->{userid};
		}
	}

	if (not defined $userid) {
		$userid = "openfoodfacts-contributors";
	}

	# Add the app to the change structure if we identified one, this will be used to populate the data sources field
	if (defined $app) {
		$change_ref->{app} = $app;
	}

	$log->debug(
		"get_change_userid_or_uuid",
		{
			change_ref => $change_ref,
			app => $app,
			app_userid_prefix => $app_userid_prefix,
			uuid => $uuid,
			userid => $userid
		}
	) if $log->is_debug();

	return $userid;
}

=head2 replace_user_id_in_product ( $product_id, $user_id, $new_user_id )

For a specific product, replace a specific user_id associated with changes (edits, new photos etc.)
by another user_id.

This can be used when we want to rename a user_id, or when an user asks its data to be deleted:
we can rename it to a generic user account like openfoodfacts-contributors.

=head3 Parameters

=head4 Product id

=head4 User id

=head3 New user id

=cut

# Fields that contain usernames
my @users_fields = qw(editors_tags photographers_tags informers_tags correctors_tags checkers_tags weighers_tags);

sub replace_user_id_in_product ($product_id, $user_id, $new_user_id, $products_collection) {

	my $path = product_path_from_id($product_id);

	# List of changes

	my $changes_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/changes.sto");
	if (not defined $changes_ref) {
		$log->warn("replace_user_id_in_products - no changes file found for " . $product_id);
		return;
	}

	my $most_recent_product_ref;

	my $revs = 0;

	foreach my $change_ref (@{$changes_ref}) {

		if ((defined $change_ref->{userid}) and ($change_ref->{userid} eq $user_id)) {
			$change_ref->{userid} = $new_user_id;
		}

		# We need to go through all product revisions to rename all instances of the user id

		$revs++;
		my $rev = $change_ref->{rev};
		if (not defined $rev) {
			$rev = $revs;    # was not set before June 2012
		}
		my $product_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/$rev.sto");

		if (defined $product_ref) {

			my $changes = 0;

			# Product creator etc.

			foreach my $user_field (qw(creator last_modified_by last_editor)) {

				if ((defined $product_ref->{$user_field}) and ($product_ref->{$user_field} eq $user_id)) {
					$product_ref->{$user_field} = $new_user_id;
					$changes++;
				}
			}

			# Lists of users computed by compute_product_history_and_completeness()

			foreach my $users_field (@users_fields) {
				if (defined $product_ref->{$users_field}) {
					for (my $i = 0; $i < scalar @{$product_ref->{$users_field}}; $i++) {
						if ($product_ref->{$users_field}[$i] eq $user_id) {
							$product_ref->{$users_field}[$i] = $new_user_id;
							$changes++;
						}
					}
				}
			}

			# Images uploaders

			if (defined $product_ref->{images}) {
				foreach my $id (sort keys %{$product_ref->{images}}) {
					if (    (defined $product_ref->{images}{$id}{uploader})
						and ($product_ref->{images}{$id}{uploader} eq $user_id))
					{
						$product_ref->{images}{$id}{uploader} = $new_user_id;
						$changes++;
					}
				}
			}

			# Save product

			if ($changes) {
				store("$BASE_DIRS{PRODUCTS}/$path/$rev.sto", $product_ref);
			}
		}

		$most_recent_product_ref = $product_ref;
	}

	if ((defined $most_recent_product_ref) and (not $most_recent_product_ref->{deleted})) {
		$products_collection->replace_one({"_id" => $most_recent_product_ref->{_id}},
			$most_recent_product_ref, {upsert => 1});
	}

	store("$BASE_DIRS{PRODUCTS}/$path/changes.sto", $changes_ref);

	return;
}

=head2 find_and_replace_user_id_in_products ( $user_id, $new_user_id )

Find all products changed by a specific user_id, and replace the user_id associated with changes (edits, new photos etc.)
by another user_id.

This can be used when we want to rename a user_id, or when an user asks its data to be deleted:
we can rename it to a generic user account like openfoodfacts-contributors.

=head3 Parameters

=head4 User id

=head3 New user id

=cut

sub find_and_replace_user_id_in_products ($user_id, $new_user_id) {

	$log->debug("find_and_replace_user_id_in_products", {user_id => $user_id, new_user_id => $new_user_id})
		if $log->is_debug();

	my $or = [];

	foreach my $users_field (@users_fields) {
		push @{$or}, {$users_field => $user_id};
	}

	my $query_ref = {'$or' => $or};

	my $count = 0;
	for (my $obsolete = 0; $obsolete <= 1; $obsolete++) {
		my $products_collection = get_products_collection({obsolete => $obsolete, timeout => 60 * 60 * 1000});
		my $cursor = $products_collection->query($query_ref)->fields({_id => 1, code => 1, owner => 1});
		$cursor->immortal(1);

		while (my $product_ref = $cursor->next) {

			my $product_id = $product_ref->{_id};

			# Ignore bogus product that might have been saved in the database
			next if (not defined $product_id) or ($product_id eq "");

			$log->info("find_and_replace_user_id_in_products - product_id",
				{user_id => $user_id, new_user_id => $new_user_id, product_id => $product_id})
				if $log->is_info();

			replace_user_id_in_product($product_id, $user_id, $new_user_id, $products_collection);
			$count++;
		}
	}

	$log->info("find_and_replace_user_id_in_products - done",
		{user_id => $user_id, new_user_id => $new_user_id, count => $count})
		if $log->is_info();

	return;
}

=head2 record_user_edit_type($users_ref, $user_type, $user_id)

Record that a user has made a change of a specific type to the product.

=head3 Parameters

=head4 $users_ref Structure that holds the records by type

For each type, there is a "list" array, and a "seen" hash

=head4 $user_type e.g. editors, photographers, weighers

=head4 $user_id

=cut

sub record_user_edit_type ($users_ref, $user_type, $user_id) {

	if ((defined $user_id) and ($user_id ne '')) {
		if (not defined $users_ref->{$user_type}{seen}{$user_id}) {
			$users_ref->{$user_type}{seen}{$user_id} = 1;
			push @{$users_ref->{$user_type}{list}}, $user_id;
		}
	}
	return;
}

sub compute_product_history_and_completeness ($current_product_ref, $changes_ref, $blame_ref) {

	my $code = $current_product_ref->{code};
	my $product_id = $current_product_ref->{_id};
	my $path = product_path($current_product_ref);

	$log->debug("compute_product_history_and_completeness", {code => $code, product_id => $product_id})
		if $log->is_debug();

	# Keep track of the last user who modified each field
	%{$blame_ref} = ();

	return if not defined $changes_ref;

	# Populate the entry_dates_tags field

	$current_product_ref->{entry_dates_tags} = [];
	my $created_t = $current_product_ref->{created_t} + 0;
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($created_t + 0);
	push @{$current_product_ref->{entry_dates_tags}}, sprintf("%04d-%02d-%02d", $year + 1900, $mon + 1, $mday);
	push @{$current_product_ref->{entry_dates_tags}}, sprintf("%04d-%02d", $year + 1900, $mon + 1);
	push @{$current_product_ref->{entry_dates_tags}}, sprintf("%04d", $year + 1900);

	# Open Food Hunt 2015 - from Feb 21st (earliest) to March 1st (latest)
	if (($created_t > (1424476800 - 12 * 3600)) and ($created_t < (1424476800 - 12 * 3600 + 10 * 86400))) {
		push @{$current_product_ref->{entry_dates_tags}}, "open-food-hunt-2015";
	}

	my $last_modified_t = $current_product_ref->{last_modified_t} + 0;
	($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($last_modified_t + 0);
	$current_product_ref->{last_edit_dates_tags} = [];
	push @{$current_product_ref->{last_edit_dates_tags}}, sprintf("%04d-%02d-%02d", $year + 1900, $mon + 1, $mday);
	push @{$current_product_ref->{last_edit_dates_tags}}, sprintf("%04d-%02d", $year + 1900, $mon + 1);
	push @{$current_product_ref->{last_edit_dates_tags}}, sprintf("%04d", $year + 1900);

	if (defined $current_product_ref->{last_checked_t}) {
		my $last_checked_t = $current_product_ref->{last_checked_t} + 0;
		($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($last_checked_t + 0);
		$current_product_ref->{last_check_dates_tags} = [];
		push @{$current_product_ref->{last_check_dates_tags}}, sprintf("%04d-%02d-%02d", $year + 1900, $mon + 1, $mday);
		push @{$current_product_ref->{last_check_dates_tags}}, sprintf("%04d-%02d", $year + 1900, $mon + 1);
		push @{$current_product_ref->{last_check_dates_tags}}, sprintf("%04d", $year + 1900);
	}
	else {
		delete $current_product_ref->{last_check_dates_tags};
	}

	# Read all previous versions to see which fields have been added or edited

	my @fields = (
		'product_type', 'code',
		'lang', 'product_name',
		'generic_name', @ProductOpener::Config::product_fields,
		@ProductOpener::Config::product_other_fields, 'no_nutrition_data',
		'nutrition_data_per', 'nutrition_data_prepared_per',
		'serving_size', 'allergens',
		'traces', 'ingredients_text'
	);

	my %previous = (uploaded_images => {}, selected_images => {}, fields => {}, nutriments => {});
	my %last = %previous;
	my %current;

	# Create a structure that will contain lists of users that have modified the product
	# in different ways (editors, photographers etc.)
	my $users_ref;

	foreach my $user_type (keys %users_tags_fields) {
		$users_ref->{$user_type} = {
			list => [],    # list of users, ordered by least recent update
			seen => {},    # hash of users, used to add users only once to the list
		};
	}

	my $revs = 0;

	my %changed_by = ();

	foreach my $change_ref (@{$changes_ref}) {
		$revs++;
		my $rev = $change_ref->{rev};
		if (not defined $rev) {
			$rev = $revs;    # was not set before June 2012
		}
		my $product_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/$rev.sto");

		# if not found, we may be be updating the product, with the latest rev not set yet
		if ((not defined $product_ref) or ($rev == $current_product_ref->{rev})) {
			$product_ref = $current_product_ref;
			$log->debug("specified product revision was not found, using current product ref", {revision => $rev})
				if $log->is_debug();
		}

		if (defined $product_ref) {

			# fix last_modified_t using the one from change_ref if it greater than the current_product_ref

			if ($change_ref->{t} > $current_product_ref->{last_modified_t}) {
				$current_product_ref->{last_modified_t} = $change_ref->{t};
			}

			# some very early products added in 2012 did not have created_t

			if ((not defined $current_product_ref->{created_t}) or ($current_product_ref->{created_t} == 0)) {
				$current_product_ref->{created_t} = $change_ref->{t};
			}

			%current = (
				rev => $rev,
				lc => $product_ref->{lc},
				uploaded_images => {},
				selected_images => {},
				fields => {},
				nutriments => {},
				packagings => {},
			);

			# Uploaded images

			# $product_ref->{images}{$imgid} ($imgid is a number)

			# Validated images

			# $product_ref->{images}{$id} ($id = front / ingredients / nutrition)

			if (defined $product_ref->{images}) {
				foreach my $imgid (sort keys %{$product_ref->{images}}) {
					if ($imgid =~ /^\d/) {
						$current{uploaded_images}{$imgid} = 1;
					}
					else {
						my $language_imgid = $imgid;
						if ($imgid !~ /_\w\w$/) {
							$language_imgid = $imgid . "_" . $product_ref->{lc};
						}
						$current{selected_images}{$language_imgid}
							= $product_ref->{images}{$imgid}{imgid} . ' '
							. $product_ref->{images}{$imgid}{rev} . ' '
							. $product_ref->{images}{$imgid}{geometry};
					}
				}
			}

			# Regular text fields

			foreach my $field (@fields) {
				$current{fields}{$field} = $product_ref->{$field};
				if (defined $current{fields}{$field}) {
					$current{fields}{$field} =~ s/^\s+//;
					$current{fields}{$field} =~ s/\s+$//;
				}
			}

			# Language specific fields
			if (defined $product_ref->{languages_codes}) {
				$current{languages_codes} = [keys %{$product_ref->{languages_codes}}];
				foreach my $language_code (@{$current{languages_codes}}) {
					foreach my $field (keys %language_fields) {
						next if $field =~ /_image$/;
						next if not exists $product_ref->{$field . '_' . $language_code};
						$current{fields}{$field . '_' . $language_code} = $product_ref->{$field . '_' . $language_code};
						$current{fields}{$field . '_' . $language_code} =~ s/^\s+//;
						$current{fields}{$field . '_' . $language_code} =~ s/\s+$//;
					}
				}
			}

			# Nutriments

			if (defined $product_ref->{nutriments}) {
				foreach my $nid (keys %{$product_ref->{nutriments}}) {
					if ((defined $product_ref->{nutriments}{$nid}) and ($product_ref->{nutriments}{$nid} ne '')) {
						$current{nutriments}{$nid} = $product_ref->{nutriments}{$nid};
					}
				}
			}

			# Packagings components
			if (defined $product_ref->{packagings}) {
				# To check if packaging data (shape, materials etc.) and packaging weights have changed
				# we compute a scalar serialization for them so that it's easy to see if they have changed
				my $packagings_data_signature = "";
				my $packagings_weights_signature = "";
				foreach my $packagings_ref (@{$product_ref->{packagings}}) {
					# We make a copy of numeric values so that Perl does not turn the value to a string when we concatenate it in the signature
					my $number_of_units = $packagings_ref->{number_of_units};
					my $weight_measured = $packagings_ref->{weight_measured};

					$packagings_data_signature .= "number_of_units:" . ($number_of_units // '') . ',';
					foreach my $property (qw(shape material recycling quantity_per_unit)) {
						$packagings_data_signature .= $property . ":" . ($packagings_ref->{$property} // '') . ',';
					}
					$packagings_data_signature .= "\n";
					$packagings_weights_signature .= ($weight_measured // '') . "\n";
				}
				# If the signature is empty or contains only line feeds, we don't have data
				if ($packagings_data_signature !~ /^\s*$/) {
					$current{packagings}{data} = $packagings_data_signature;
				}
				if ($packagings_weights_signature !~ /^\s*$/) {
					$current{packagings}{weights_measured} = $packagings_weights_signature;
				}
			}

			$current{checked} = $product_ref->{checked};
			$current{last_checked_t} = $product_ref->{last_checked_t};
		}

		# Differences and attribution to users

		my %diffs = ();

		my $userid = get_change_userid_or_uuid($change_ref);

		$changed_by{$userid} = 1;

		if (    (defined $current{last_checked_t})
			and ((not defined $previous{last_checked_t}) or ($previous{last_checked_t} != $current{last_checked_t})))
		{
			record_user_edit_type($users_ref, "checkers", $product_ref->{last_checker});
		}

		foreach my $group ('uploaded_images', 'selected_images', 'fields', 'nutriments', 'packagings') {

			defined $blame_ref->{$group} or $blame_ref->{$group} = {};

			my @ids;

			if ($group eq 'fields') {
				@ids = @fields;

				# also check language specific fields for language codes of the current and previous product
				my @languages_codes = ();
				my %languages_codes = ();
				foreach my $current_or_previous_ref (\%current, \%previous) {
					if (defined $current_or_previous_ref->{languages_codes}) {
						foreach my $language_code (@{$current_or_previous_ref->{languages_codes}}) {
							# commenting next line so that we see changes for both ingredients_text and ingredients_text_$lc
							# even if they are the same.
							# keeping ingredients_text as at the start of the project, we had only ingredients_text and
							# not language specific versions
							# next if $language_code eq $current_or_previous_ref->{lc};
							next if defined $languages_codes{$language_code};
							push @languages_codes, $language_code;
							$languages_codes{$language_code} = 1;
						}
					}
				}

				foreach my $language_code (sort @languages_codes) {
					foreach my $field (sort keys %language_fields) {
						next if $field =~ /_image$/;
						push @ids, $field . "_" . $language_code;
					}
				}
			}
			elsif ($group eq 'nutriments') {
				@ids = @{$nutriments_lists{off_europe}};
			}
			elsif ($group eq 'packagings') {
				@ids = ("data", "weights_measured");
			}
			else {
				my $uniq = sub {
					my %seen;
					grep {!$seen{$_}++} @_;
				};
				@ids = $uniq->(keys %{$current{$group}}, keys %{$previous{$group}});
			}

			foreach my $id (@ids) {

				my $diff = undef;

				if (    ((not defined $previous{$group}{$id}) or ($previous{$group}{$id} eq ''))
					and ((defined $current{$group}{$id}) and ($current{$group}{$id} ne '')))
				{
					$diff = 'add';
				}
				elsif ( ((defined $previous{$group}{$id}) and ($previous{$group}{$id} ne ''))
					and ((not defined $current{$group}{$id}) or ($current{$group}{$id} eq '')))
				{
					$diff = 'delete';
				}
				elsif ( (defined $previous{$group}{$id})
					and (defined $current{$group}{$id})
					and ($previous{$group}{$id} ne $current{$group}{$id}))
				{
					$log->debug(
						"difference in products detected",
						{
							id => $id,
							previous_rev => $previous{rev},
							previous => $previous{$group}{$id},
							current_rev => $current{rev},
							current => $current{$group}{$id}
						}
					) if $log->is_debug();
					$diff = 'change';
				}

				if (defined $diff) {

					# Assign blame

					if (defined $blame_ref->{$group}{$id}) {
						$blame_ref->{$group}{$id} = {
							previous_userid => $blame_ref->{$group}{$id}{userid},
							previous_t => $blame_ref->{$group}{$id}{t},
							previous_rev => $blame_ref->{$group}{$id}{rev},
							previous_value => $blame_ref->{$group}{$id}{value},
						};
					}
					else {
						$blame_ref->{$group}{$id} = {};
					}

					$blame_ref->{$group}{$id}{userid} = $change_ref->{userid};
					$blame_ref->{$group}{$id}{t} = $change_ref->{t};
					$blame_ref->{$group}{$id}{rev} = $change_ref->{rev};
					$blame_ref->{$group}{$id}{value} = $current{$group}{$id};

					defined $diffs{$group} or $diffs{$group} = {};
					defined $diffs{$group}{$diff} or $diffs{$group}{$diff} = [];
					push @{$diffs{$group}{$diff}}, $id;

					# Attribution and last_image_t

					if (($diff eq 'add') and ($group eq 'uploaded_images')) {
						# images uploader and uploaded_t where not set before 2015/08/04, set them using the change history
						# ! only update the values if the image still exists in the current version of the product (wasn't moved or deleted)
						if (exists $current_product_ref->{images}{$id}) {
							if (not defined $current_product_ref->{images}{$id}{uploaded_t}) {
								$current_product_ref->{images}{$id}{uploaded_t} = $product_ref->{last_modified_t} + 0;
							}
							if (not defined $current_product_ref->{images}{$id}{uploader}) {
								$current_product_ref->{images}{$id}{uploader} = $userid;
							}

							# when moving images, attribute the image to the user that uploaded the image

							$userid = $current_product_ref->{images}{$id}{uploader};
							if ($userid eq 'unknown') {    # old unknown user
								$current_product_ref->{images}{$id}{uploader}
									= "openfoodfacts-contributors";
								$userid = "openfoodfacts-contributors";
							}
							$change_ref->{userid} = $userid;

						}

						# set last_image_t

						if (   (not exists $current_product_ref->{last_image_t})
							or ($product_ref->{last_modified_t} > $current_product_ref->{last_image_t}))
						{
							$current_product_ref->{last_image_t} = $product_ref->{last_modified_t};
						}

					}

					# Packagings
					if (    ($group eq 'packagings')
						and ($id eq 'weights_measured')
						and (($diff eq 'add') or ($diff eq 'change')))
					{
						record_user_edit_type($users_ref, "weighers", $userid);
					}

					# Uploaded photos + all fields
					if (($diff eq 'add') and ($group eq 'uploaded_images')) {
						record_user_edit_type($users_ref, "photographers", $userid);
					}
					elsif ($diff eq 'add') {
						record_user_edit_type($users_ref, "informers", $userid);
					}
					elsif ($diff eq 'change') {
						record_user_edit_type($users_ref, "correctors", $userid);
					}
				}
			}
		}

		$change_ref->{diffs} = dclone(\%diffs);

		$current_product_ref->{last_editor} = $change_ref->{userid};

		compute_completeness_and_missing_tags($product_ref, \%current, \%previous);

		%last = %{dclone(\%previous)};
		%previous = %{dclone(\%current)};
	}

	# Populate the last_image_date_tags field

	if ((exists $current_product_ref->{last_image_t}) and ($current_product_ref->{last_image_t} > 0)) {
		$current_product_ref->{last_image_dates_tags} = [];
		my $last_image_t = $current_product_ref->{last_image_t};
		my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($last_image_t);
		push @{$current_product_ref->{last_image_dates_tags}}, sprintf("%04d-%02d-%02d", $year + 1900, $mon + 1, $mday);
		push @{$current_product_ref->{last_image_dates_tags}}, sprintf("%04d-%02d", $year + 1900, $mon + 1);
		push @{$current_product_ref->{last_image_dates_tags}}, sprintf("%04d", $year + 1900);
	}
	else {
		delete $current_product_ref->{last_image_dates_tags};
	}

	$current_product_ref->{editors_tags} = [sort keys %changed_by];

	$current_product_ref->{photographers_tags} = $users_ref->{photographers}{list};
	$current_product_ref->{informers_tags} = $users_ref->{informers}{list};
	$current_product_ref->{correctors_tags} = $users_ref->{correctors}{list};
	$current_product_ref->{checkers_tags} = $users_ref->{checkers}{list};
	$current_product_ref->{weighers_tags} = $users_ref->{weighers}{list};

	compute_completeness_and_missing_tags($current_product_ref, \%current, \%last);

	$log->debug("compute_product_history_and_completeness - done", {code => $code, product_id => $product_id})
		if $log->is_debug();

	return;
}

# traverse the history to see if a particular user has removed values for tag fields
# add back the removed values

# NOT sure if this is useful, it's being used in one of the "obsolete" scripts
sub add_back_field_values_removed_by_user ($current_product_ref, $changes_ref, $field, $userid) {

	my $code = $current_product_ref->{code};
	my $path = product_path($current_product_ref);

	return if not defined $changes_ref;

	# Read all previous versions to see which fields have been added or edited

	my @fields
		= qw(lang product_name generic_name quantity packaging brands categories origins manufacturing_places labels emb_codes expiration_date purchase_places stores countries ingredients_text traces no_nutrition_data serving_size nutrition_data_per );

	my %previous = ();
	my %last = %previous;
	my %current;

	my $previous_tags_ref = {};
	my $current_tags_ref;

	my %removed_tags = ();

	my $revs = 0;

	foreach my $change_ref (@{$changes_ref}) {
		$revs++;
		my $rev = $change_ref->{rev};
		if (not defined $rev) {
			$rev = $revs;    # was not set before June 2012
		}
		my $product_ref = retrieve("$BASE_DIRS{PRODUCTS}/$path/$rev.sto");

		# if not found, we may be be updating the product, with the latest rev not set yet
		if ((not defined $product_ref) or ($rev == $current_product_ref->{rev})) {
			$product_ref = $current_product_ref;
			if (not defined $product_ref) {
				$log->warn("specified product revision was not found, using current product ref",
					{code => $code, revision => $rev})
					if $log->is_warn();
			}
		}

		if (defined $product_ref->{$field . "_tags"}) {

			$current_tags_ref = {map {$_ => 1} @{$product_ref->{$field . "_tags"}}};
		}
		else {
			$current_tags_ref = {};
		}

		if ((defined $change_ref->{userid}) and ($change_ref->{userid} eq $userid)) {

			foreach my $tagid (keys %{$previous_tags_ref}) {
				if (not exists $current_tags_ref->{$tagid}) {
					$log->info("user removed value for a field",
						{user_id => $userid, tagid => $tagid, field => $field, code => $code})
						if $log->is_info();
					$removed_tags{$tagid} = 1;
				}
			}
		}

		$previous_tags_ref = $current_tags_ref;

	}

	my $added = 0;
	my $added_countries = "";

	foreach my $tagid (sort keys %removed_tags) {
		if (not exists $current_tags_ref->{$tagid}) {
			$log->info("adding back removed tag", {tagid => $tagid, field => $field, code => $code}) if $log->is_info();

			# we do not know the language of the current value of $product_ref->{$field}
			# so regenerate it in the main language of the product
			my $value = display_tags_hierarchy_taxonomy($lc, $field, $current_product_ref->{$field . "_hierarchy"});
			# Remove tags
			$value =~ s/<(([^>]|\n)*)>//g;

			$current_product_ref->{$field} .= $value . ", $tagid";

			if ($current_product_ref->{$field} =~ /^, /) {
				$current_product_ref->{$field} = $';
			}

			compute_field_tags($current_product_ref, $current_product_ref->{lc}, $field);

			$added++;
			$added_countries .= " $tagid";
		}
	}

	if ($added > 0) {

		return $added . $added_countries;
	}
	else {
		return 0;
	}
}

sub normalize_search_terms ($term) {

	# plural?
	$term =~ s/s$//;
	return $term;
}

sub product_name_brand ($ref) {

	my $full_name = '';
	if ((defined $ref->{"product_name_$lc"}) and ($ref->{"product_name_$lc"} ne '')) {
		$full_name = $ref->{"product_name_$lc"};
	}
	elsif ((defined $ref->{product_name}) and ($ref->{product_name} ne '')) {
		$full_name = $ref->{product_name};
	}
	elsif ((defined $ref->{"generic_name_$lc"}) and ($ref->{"generic_name_$lc"} ne '')) {
		$full_name = $ref->{"generic_name_$lc"};
	}
	elsif ((defined $ref->{generic_name}) and ($ref->{generic_name} ne '')) {
		$full_name = $ref->{generic_name};
	}
	elsif ((defined $ref->{"abbreviated_product_name_$lc"}) and ($ref->{"abbreviated_product_name_$lc"} ne '')) {
		$full_name = $ref->{"abbreviated_product_name_$lc"};
	}
	elsif ((defined $ref->{abbreviated_product_name}) and ($ref->{abbreviated_product_name} ne '')) {
		$full_name = $ref->{abbreviated_product_name};
	}

	if (defined $ref->{brands}) {
		my $brand = $ref->{brands};
		$brand =~ s/,.*//;    # take the first brand
		my $brandid = '-' . get_string_id_for_lang($lc, $brand) . '-';
		my $full_name_id = '-' . get_string_id_for_lang($lc, $full_name) . '-';
		if (($brandid ne '') and ($full_name_id !~ /$brandid/i)) {
			$full_name .= lang("title_separator") . $brand;
		}
	}

	$full_name =~ s/^ - //;
	return $full_name;
}

# product full name is a combination of product name, first brand and quantity

sub product_name_brand_quantity ($ref) {

	my $full_name = product_name_brand($ref);
	my $full_name_id = '-' . get_string_id_for_lang($lc, $full_name) . '-';

	if (defined $ref->{quantity}) {
		my $quantity = $ref->{quantity};
		my $quantityid = '-' . get_string_id_for_lang($lc, $quantity) . '-';
		if (($quantity ne '') and ($full_name_id !~ /$quantityid/i)) {
			# Put non breaking spaces between numbers and units
			$quantity =~ s/(\d) (\w)/$1\xA0$2/g;
			$full_name .= lang("title_separator") . $quantity;
		}
	}

	$full_name =~ s/^ - //;
	return $full_name;
}

=head2 product_url ( $code_or_ref )

Returns a relative URL for a product on the website.

=head3 Parameters

=head4 Product code or reference to product object $code_or_ref

=cut

sub product_url ($code_or_ref) {

	my $code;
	my $ref;

	my $product_lc = $lc;

	if (ref($code_or_ref) eq 'HASH') {
		$ref = $code_or_ref;
		$code = $ref->{code};
		#if (defined $ref->{lc}) {
		#	$product_lc = $ref->{lc};
		#}
	}
	else {
		$code = $code_or_ref;
	}

	my $path = $tag_type_singular{products}{$product_lc};
	if (not defined $path) {
		$path = $tag_type_singular{products}{en};
	}

	my $titleid = '';
	if (defined $ref) {
		my $full_name = product_name_brand($ref);
		$titleid = get_url_id_for_lang($product_lc, $full_name);
		if ($titleid ne '') {
			$titleid = '/' . $titleid;
		}
	}

	$code = ($code // "");
	return get_owner_pretty_path($Owner_id) . "/$path/$code" . $titleid;
}

=head2 product_action_url ( $code, $action )

Returns a relative URL for an action on a product on the website.

This function is called by the web/panels/panel.tt.html template for knowledge panels that have associated actions.

=head3 Parameters

=head4 Product code or reference to product object $code_or_ref

=cut

my %actions_urls = (
	edit_product => "",
	add_categories => "#categories",
	add_ingredients_image => "#ingredients",
	add_ingredients_text => "#ingredients",
	add_nutrition_facts_image => "#nutrition",
	add_nutrition_facts => "#nutrition",
	add_packaging_image => "#packaging",
	add_packaging_text => "#packaging",
	add_packaging_components => "#packaging",
	add_origins => "#origins",
	add_quantity => "#product_characteristics",
	add_stores => "#stores",
	add_packager_codes_image => "#packager_codes",
	add_labels => "#labels",
	add_countries => "#countries",
	# this is for web rendering so source is web
	report_product_to_nutripatrol => "$nutripatrol_url/flag/product/?barcode=PRODUCT_CODE&source=web&flavor=$flavor"
);

sub product_action_url ($code, $action = "edit_product") {

	my $url;
	if (defined $actions_urls{$action}) {
		my $action_url = $actions_urls{$action};
		if (($action_url eq '') || ($action_url =~ /^#/)) {
			# link to the edit form
			$url = "/cgi/product.pl?type=edit&code=" . $code;
			$url .= $action_url;
		}
		else {
			# full url
			$url = $action_url;
			$url =~ s/PRODUCT_CODE/$code/;
		}
	}
	else {
		$log->error("unknown product action", {code => $code, action => $action});
	}

	return $url // "";
}

sub compute_keywords ($product_ref) {

	my @string_fields = qw(product_name generic_name);
	my @tag_fields = qw(brands categories origins labels);

	my %keywords;

	my $product_lc = $product_ref->{lc} || $lc;

	foreach my $field (@string_fields, @tag_fields) {
		if (defined $product_ref->{$field}) {
			foreach my $tag (split(/,|'|’|\s/, $product_ref->{$field})) {
				if (($field eq 'categories') or ($field eq 'labels') or ($field eq 'origins')) {
					$tag =~ s/^\w\w://;
				}

				my $tagid = get_string_id_for_lang($product_lc, $tag);
				if (length($tagid) >= 2) {
					$keywords{normalize_search_terms($tagid)} = 1;
				}
			}
		}
	}

	$product_ref->{_keywords} = [sort keys %keywords];

	return;
}

sub compute_codes ($product_ref) {

	my $code = $product_ref->{code};

	my @codes = ();

	push @codes, "code-" . length($code);

	my $ean = undef;

	# Note: we now normalize codes, so we should not have conflicts
	if (length($code) == 12) {
		$ean = '0' . $code;
		if (retrieve_product('0' . $code)) {
			push @codes, "conflict-with-ean-13";
		}
		elsif (retrieve_product('0' . $code), 1) {
			push @codes, "conflict-with-deleted-ean-13";
		}
	}

	if ((length($code) == 13) and ($code =~ /^0/)) {
		$ean = $code;
		my $upc = $code;
		$upc =~ s/^.//;
		if (retrieve_product($upc)) {
			push @codes, "conflict-with-upc-12";
		}
	}

	if ((defined $ean) and ($ean !~ /^0?2/)) {
		if (not $ean_check->is_valid($ean)) {
			push @codes, "invalid-ean";
		}
	}

	while ($code =~ /^\d/) {
		# only keep codes with 3 xx at the end
		if ($code =~ /xxx$/) {
			push @codes, $code;
		}
		$code =~ s/\d(x*)$/x$1/;
	}

	$product_ref->{codes_tags} = \@codes;

	return;
}

# set tags with info on languages shown on the package, using the languages taxonomy
# [en:french] -> language names
# [n] -> number of languages
# en:multi -> indicates n > 1

sub compute_languages ($product_ref) {

	my %languages = ();
	my %languages_codes = ();

	# check all the fields of the product
	foreach my $field (keys %{$product_ref}) {

		if (    ($field =~ /_([a-z]{2})$/)
			and (defined $language_fields{$`})
			and (defined $product_ref->{$field})
			and ($product_ref->{$field} ne ''))
		{
			my $language_code = $1;
			my $language = undef;
			if (defined $language_codes{$language_code}) {
				$language = $language_codes{$language_code};
			}
			else {
				$language = $language_code;
			}
			$languages{$language}++;
			$languages_codes{$language_code}++;
		}
	}

	if (defined $product_ref->{images}) {
		foreach my $id (keys %{$product_ref->{images}}) {

			if ($id =~ /^(front|ingredients|nutrition)_([a-z]{2})$/) {
				my $language_code = $2;
				my $language = undef;
				if (defined $language_codes{$language_code}) {
					$language = $language_codes{$language_code};
				}
				else {
					$language = $language_code;
				}
				$languages{$language}++;
				$languages_codes{$language_code}++;
			}
		}
	}

	my @languages = sort keys %languages;
	my $n = scalar(@languages);

	my @languages_hierarchy = @languages;    # without multilingual and count

	push @languages, "en:$n";
	if ($n > 1) {
		push @languages, "en:multilingual";
	}

	$product_ref->{languages} = \%languages;
	$product_ref->{languages_codes} = \%languages_codes;
	$product_ref->{languages_tags} = \@languages;
	$product_ref->{languages_hierarchy} = \@languages_hierarchy;

	return;
}

=head2 review_product_type ( $product_ref )

Reviews the product type based on the presence of specific tags in the categories field.
Updates the product type if necessary.

=head3 Arguments

=head4 Product reference $product_ref

A reference to a hash containing the product details.

=cut

sub review_product_type ($product_ref) {

	my $error;

	my $expected_type;
	if (has_tag($product_ref, "categories", "en:open-beauty-facts")) {
		$expected_type = "beauty";
	}
	elsif (has_tag($product_ref, "categories", "en:open-food-facts")) {
		$expected_type = "food";
	}
	elsif (has_tag($product_ref, "categories", "en:open-pet-food-facts")) {
		$expected_type = "petfood";
	}
	elsif (has_tag($product_ref, "categories", "en:open-products-facts")) {
		$expected_type = "product";
	}

	if ($expected_type and ($product_ref->{product_type} ne $expected_type)) {
		$error = change_product_type($product_ref, $expected_type);
	}

	if ($error) {
		$log->error("review_product_type - error", {error => $error, product_ref => $product_ref});
	}
	else {
		# We remove the tag en:incorrect-product-type and its children before the product is stored on the server of the new type
		remove_tag($product_ref, "categories", "en:incorrect-product-type");
		remove_tag($product_ref, "categories", "en:open-beauty-facts");
		remove_tag($product_ref, "categories", "en:open-food-facts");
		remove_tag($product_ref, "categories", "en:open-pet-food-facts");
		remove_tag($product_ref, "categories", "en:open-products-facts");
		remove_tag($product_ref, "categories", "en:non-food-products");
		remove_tag($product_ref, "categories", "en:non-pet-food-products");
		remove_tag($product_ref, "categories", "en:non-beauty-products");
	}

	return;
}

=head2 process_product_edit_rules ($product_ref)

Process the edit_rules (see C<@edit_rules> in in Config file).

=head3 where it applies

It applies in all API/form that edit the product.
It applies to apply an image crop.

It does not block image upload.

=head3 edit_rules structure

=over 1

=item * name: rule name to identify it in logs and describe it

=item * conditions: the conditions the product must match, a list of [field name, value]

=item * actions: the actions to take, a list, where each element is a list with a rule name, and eventual arguments

=item * notifications: also notify, list of email addresses or specific notification rules

=back

=head4 conditions

Each condition is either a match on C<user_id> or it's contrary C<user_id_not>,
or C<in_TAG_NAME_tags> for a tag field to match a specific tag id.

Note that conditions are checked before editing the product !

=head4 actions

C<ignore> alone, ignore every edits.

You can also have rules of the form
C<ignore_FIELD> and C<warn_FIELD> which will ignore (or notify) edits on the specific field.

Note that ignore rules also create a notification.

For nutriments use C<nutriments_NUTRIMENT_NAME> for C<FIELD>.

You can guard the rule on the field with a condition:
C<ignore_if_CONDITION_FIELD> or C<warn_if_CONDITION_FIELD>
This time it's to check the value the user want's to add.

C<CONDITION> is one of the following:

=over 1

=item * existing - user tries to edit this field with a non empty value

=item * 0 - user tries to put numerical value 0 in the field

=item * equal / lesser / greater - comparison of numeric value (requires a value as argument)

=item * match - comparison to a string (equality, requires a value as argument)

=item * regexp_match - match against a regexp (requires a regexp value as argument)

=back

=head4 notifications

Notifications are email addresses to send emails,
or "slack_CHANNEL_NAME" (B<warning> currently channel name is ignored, we post to I<edit-alerts>)

=head4 Example of an edit rule

=begin text

{
	name => "App XYZ",
	conditions => [
		["user_id", "xyz"],
	],
	actions => [
		["ignore_if_existing_ingredients_text_fr"],
		["ignore_if_0_nutriment_fruits-vegetables-nuts"],
		["warn_if_match_nutriment_fruits-vegetables-nuts", 100],
		["ignore_if_regexp_match_packaging", "^(artikel|produit|producto|produkt|produkte)$"],
	],
	notifications => qw (
		stephane@openfoodfacts.org
		slack_channel_edit-alert
		slack_channel_edit-alert-test
	),
},

=end text

=cut

sub preprocess_product_field ($field, $value) {

	$value = remove_tags_and_quote($value);
	if ($field ne 'customer_service' && $field ne 'other_information') {
		$value = remove_email($value);
	}
	return $value;
}

sub process_product_edit_rules ($product_ref) {

	my $code = $product_ref->{code};

	local $log->context->{user_id} = $User_id;
	local $log->context->{code} = $code;

	# return value to indicate if the edit should proceed
	my $proceed_with_edit = 1;

	foreach my $rule_ref (@edit_rules) {

		local $log->context->{rule} = $rule_ref->{name};
		$log->debug("checking edit rule") if $log->is_debug();

		# Check the conditions

		my $conditions = 1;    # we first imagine conditions are met

		if (defined $rule_ref->{conditions}) {
			foreach my $condition_ref (@{$rule_ref->{conditions}}) {
				if (($condition_ref->[0] eq 'user_id')) {
					if ((not defined $User_id) or ($condition_ref->[1] ne $User_id)) {
						$conditions = 0;
						$log->debug("condition does not match value",
							{condition => $condition_ref->[0], expected => $condition_ref->[1], actual => $User_id})
							if $log->is_debug();
						last;
					}
				}
				elsif ($condition_ref->[0] eq 'user_id_not') {
					if ((defined $User_id) and ($condition_ref->[1] eq $User_id)) {
						$conditions = 0;
						$log->debug("condition does not match value",
							{condition => $condition_ref->[0], expected => $condition_ref->[1], actual => $User_id})
							if $log->is_debug();
						last;
					}
				}
				elsif ($condition_ref->[0] =~ /in_(.*)_tags/) {
					my $tagtype = $1;
					my $condition = 0;    # condition is not met, but if we have a match
					if (defined $product_ref->{$tagtype . "_tags"}) {
						foreach my $tagid (@{$product_ref->{$tagtype . "_tags"}}) {
							if ($tagid eq $condition_ref->[1]) {
								$condition = 1;
								last;
							}
						}
					}
					if (not $condition) {
						$conditions = 0;
						$log->debug("condition does not match value",
							{condition => $condition_ref->[0], expected => $condition_ref->[1]})
							if $log->is_debug();
						last;
					}
				}
				else {
					$log->debug("unrecognized condition", {condition => $condition_ref->[0]}) if $log->is_debug();
				}
			}
		}

		# If conditions match, process actions and notifications
		if ($conditions) {

			# 	actions => {
			# 		["ignore_if_existing_ingredients_texts_fr"],
			# 		["ignore_if_0_nutriments_fruits-vegetables-nuts"],
			# 		["warn_if_equal_nutriments_fruits-vegetables-nuts", 100],
			# 		["ignore_if_regexp_match_packaging", "^(artikel|produit|producto|produkt|produkte)$"],
			# 	},

			if (defined $rule_ref->{actions}) {
				foreach my $action_ref (@{$rule_ref->{actions}}) {
					my $action = $action_ref->[0];
					my $value = $action_ref->[1];
					not defined $value and $value = '';

					local $log->context->{action} = $action;
					local $log->context->{value} = $value;
					$log->debug("evaluating actions") if $log->is_debug();

					my $condition_ok = 1;

					my $action_log = "";

					# the simplest rule: ignore everything
					if ($action eq "ignore") {
						$log->debug("ignore action => do not proceed with edits") if $log->is_debug();
						$proceed_with_edit = 0;
					}
					# rules with conditions
					elsif ($action =~ /^(ignore|warn)(_if_(existing|0|greater|lesser|equal|match|regexp_match)_)?(.*)$/)
					{
						my ($type, $condition, $field) = ($1, $3, $4);
						my $default_field = $field;

						my $condition_ok = 1;    # consider condition is met

						my $action_log = "";

						local $log->context->{type} = $type;
						local $log->context->{action} = $field;
						local $log->context->{field} = $field;

						if (defined $condition) {

							my $param_field = undef;
							if (defined single_param($field)) {
								# param_field is the new value defined by edit
								$param_field = remove_tags_and_quote(decode utf8 => single_param($field));
							}
							if ($field =~ /_(\w\w)$/) {
								# localized field ? remove language to get value in request
								$default_field = $`;
								if ((!defined $param_field) && (defined single_param($default_field))) {
									$param_field = remove_tags_and_quote(decode utf8 => single_param($default_field));
								}
							}

							# if field is not passed, skip rule
							if (not defined $param_field) {
								$log->debug("no value passed -> skip edit rule") if $log->is_debug();
								next;
							}

							my $current_value = $product_ref->{$field};
							# specific rule for nutriments, take the nutriment_name_100g
							if ($field =~ /^nutriment_(.*)/) {
								my $nid = $1;
								$current_value = $product_ref->{nutriments}{$nid . "_100g"};
							}

							local $log->context->{current_value} = $current_value;
							local $log->context->{param_field} = $param_field;

							$log->debug("start field comparison") if $log->is_debug();

							# if there is an existing value equal to the passed value, just skip the rule
							if ((defined $current_value) and ($current_value eq $param_field)) {
								$log->debug("current value equals new value -> skip edit rule") if $log->is_debug();
								next;
							}

							$condition_ok = 0;

							if ($condition eq 'existing') {
								if ((defined $current_value) and ($current_value ne '')) {
									$condition_ok = 1;
								}
							}
							elsif ($condition eq '0') {
								if ((defined single_param($field)) and ($param_field == 0)) {
									$condition_ok = 1;
								}
							}
							elsif ($condition eq 'equal') {
								if ((defined single_param($field)) and ($param_field == $value)) {
									$condition_ok = 1;
								}
							}
							elsif ($condition eq 'lesser') {
								if ((defined single_param($field)) and ($param_field < $value)) {
									$condition_ok = 1;
								}
							}
							elsif ($condition eq 'greater') {
								if ((defined single_param($field)) and ($param_field > $value)) {
									$condition_ok = 1;
								}
							}
							elsif ($condition eq 'match') {
								if ((defined single_param($field)) and ($param_field eq $value)) {
									$condition_ok = 1;
								}
							}
							elsif ($condition eq 'regexp_match') {
								if ((defined single_param($field)) and ($param_field =~ /$value/i)) {
									$condition_ok = 1;
								}
							}
							else {
							}

							if (not $condition_ok) {
								$log->debug("condition does not match") if $log->is_debug();
							}
							else {
								$log->debug("condition matches") if $log->is_debug();
								$action_log
									= "product code $code - https://world.$server_domain/product/$code - edit rule $rule_ref->{name} - type: $type - condition: $condition - field: $field current(field): "
									. ($current_value // "")
									. " - param(field): "
									. $param_field . "\n";
							}
						}
						else {
							$action_log
								= "product code $code - https://world.$server_domain/product/$code - edit rule $rule_ref->{name} - type: $type - condition: $condition \n";
						}

						if ($condition_ok) {

							# Process action
							$log->debug("executing edit rule action") if $log->is_debug();

							# Delete the parameters

							if ($type eq 'ignore') {
								Delete($field);
								if ($default_field ne $field) {
									Delete($default_field);
								}
							}
						}

					}
					else {
						$log->debug("unrecognized action", {action => $action}) if $log->is_debug();
					}

					if ($condition_ok) {

						$log->debug("executing edit rule action") if $log->is_debug();

						if (defined $rule_ref->{notifications}) {
							foreach my $notification (@{$rule_ref->{notifications}}) {

								$log->info("sending notification", {notification_recipient => $notification})
									if $log->is_info();

								if ($notification =~ /\@/) {
									# e-mail

									my $user_ref = {name => $notification, email => $notification};

									send_email($user_ref, "Edit rule " . $rule_ref->{name}, $action_log);
								}
								elsif ($notification =~ /slack_/) {
									# slack

									my $channel = $';

									# we need a slack bot with the Web api to post to multiple channel
									# use the simpler incoming webhook api, and post only to edit-alerts for now

									$channel = "edit-alerts";

									my $emoji = ":lemon:";
									if ($action eq 'warn') {
										$emoji = ":pear:";
									}

									my $ua = LWP::UserAgent->new;
									my $server_endpoint
										= "https://hooks.slack.com/services/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";

									my $msg = $action_log;

									# set custom HTTP request header fields
									my $req = HTTP::Request->new(POST => $server_endpoint);
									$req->header('content-type' => 'application/json');

									# add POST data to HTTP request body
									my $post_data
										= '{"channel": "#'
										. $channel
										. '", "username": "editrules", "text": "'
										. $msg
										. '", "icon_emoji": "'
										. $emoji . '" }';
									$req->content_type("text/plain; charset='utf8'");
									$req->content(Encode::encode_utf8($post_data));

									my $resp = $ua->request($req);
									if ($resp->is_success) {
										my $message = $resp->decoded_content;
										$log->info("Notification sent to Slack successfully", {response => $message})
											if $log->is_info();
									}
									else {
										$log->warn(
											"Notification could not be sent to Slack",
											{code => $resp->code, response => $resp->message}
										) if $log->is_warn();
									}

								}
							}
						}
					}
				}
			}

		}
	}

	return $proceed_with_edit;
}

sub log_change ($product_ref, $change_ref) {

	my $change_document = {
		code => $product_ref->{code},
		countries_tags => $product_ref->{countries_tags},
		userid => $change_ref->{userid},
		ip => $change_ref->{ip},
		t => $change_ref->{t},
		comment => $change_ref->{comment},
		rev => $change_ref->{rev},
		diffs => $change_ref->{diffs}
	};
	get_recent_changes_collection()->insert_one($change_document);

	return;
}

=head2 compute_changes_diff_text ( $change_ref )

Generates a text that describes the changes made. The text is displayed in the edit history of products.

=head3 Arguments

$change_ref: reference to a change record

=cut

sub compute_changes_diff_text ($change_ref) {

	my $diffs = '';
	if (defined $change_ref->{diffs}) {
		my %diffs = %{$change_ref->{diffs}};
		foreach my $group ('uploaded_images', 'selected_images', 'fields', 'nutriments') {
			if (defined $diffs{$group}) {
				$diffs .= lang("change_$group") . " ";

				foreach my $diff ('add', 'change', 'delete') {
					if (defined $diffs{$group}{$diff}) {
						$diffs .= "(" . lang("diff_$diff") . ' ';
						my @diffs = @{$diffs{$group}{$diff}};
						$diffs .= join(", ", @diffs);
						$diffs .= ") ";
					}
				}

				$diffs .= "-- ";
			}
		}
		$diffs =~ s/-- $//;
	}

	return $diffs;

}

=head2 add_user_teams ( $product_ref )

If the user who add or edits the product belongs to one or more teams, add them to the teams_tags array.

=head3 Parameters

$product_ref

=cut

sub add_user_teams ($product_ref) {

	if (defined $User_id) {

		for (my $i = 1; $i <= 3; $i++) {

			my $added_teams = 0;

			if (defined $User{"team_" . $i}) {

				my $teamid = get_string_id_for_lang("no_language", $User{"team_" . $i});
				if ($teamid ne "") {
					add_tag($product_ref, "teams", $teamid);
					$added_teams++;
				}
			}

			if ($added_teams) {
				$product_ref->{teams} = join(',', @{$product_ref->{teams_tags}});
			}
		}
	}

	return;
}

=head2 product_data_is_protected ( $product_ref )

Checks if the product data should be protected from edits.
e.g. official producer data that should not be changed by anonymous users through the API

Product data is protected if it has an owner and if the corresponding organization has
the "protect data" checkbox checked.

=head3 Parameters

=head4 $product_ref

=head3 Return values

- 1 if the data is protected
- 0 if the data is not protected

=cut

sub product_data_is_protected ($product_ref) {

	my $protected_data = 0;
	if ((defined $product_ref->{owner}) and ($product_ref->{owner} =~ /^org-(.+)$/)) {
		my $org_id = $1;
		my $org_ref = retrieve_org($org_id);
		if ((defined $org_ref) and ($org_ref->{protect_data})) {
			$protected_data = 1;
		}
	}
	return $protected_data;
}

=head2 delete_fields ($product_ref, $fields_ref)

Utility function to delete fields from a product_ref or a subfield.

=head3 Parameters

=head4 $product_ref

Reference to a complete product a subfield.

=head4 $fields_ref

An array of field names to remove.

=cut

sub remove_fields ($product_ref, $fields_ref) {

	foreach my $field (@$fields_ref) {
		delete $product_ref->{$field};
	}
	return;
}

=head2 add_images_urls_to_product ($product_ref, $target_lc, $specific_imagetype = undef)

Add fields like image_[front|ingredients|nutrition|packaging]_[url|small_url|thumb_url] to a product object.

If it exists, the image for the target language will be returned, otherwise we will return the image
in the main language of the product.

=head3 Parameters

=head4 $product_ref

Reference to a complete product a subfield.

=head4 $target_lc

2 language code of the preferred language for the product images.

=head4 $specific_imagetype

Optional parameter to specify the type of image to add. Default is to add all types.

=cut

sub add_images_urls_to_product ($product_ref, $target_lc, $specific_imagetype = undef) {

	my $images_subdomain = format_subdomain('images');

	my $path = product_path($product_ref);

	# If $imagetype is specified (e.g. "front" when we display a list of products), only compute the image for this type
	my @imagetypes;
	if (defined $specific_imagetype) {
		@imagetypes = ($specific_imagetype);
	}
	else {
		@imagetypes = ('front', 'ingredients', 'nutrition', 'packaging');
	}

	foreach my $imagetype (@imagetypes) {

		my $size = $display_size;

		# first try the requested language
		my @display_ids = ($imagetype . "_" . $target_lc);

		# next try the main language of the product
		if (defined($product_ref->{lc}) && $product_ref->{lc} ne $target_lc) {
			push @display_ids, $imagetype . "_" . $product_ref->{lc};
		}

		# last try the field without a language (for old products without updated images)
		push @display_ids, $imagetype;

		foreach my $id (@display_ids) {

			if (    (defined $product_ref->{images})
				and (defined $product_ref->{images}{$id})
				and (defined $product_ref->{images}{$id}{sizes})
				and (defined $product_ref->{images}{$id}{sizes}{$size}))
			{

				$product_ref->{"image_" . $imagetype . "_url"}
					= "$images_subdomain/images/products/$path/$id."
					. $product_ref->{images}{$id}{rev} . '.'
					. $display_size . '.jpg';
				$product_ref->{"image_" . $imagetype . "_small_url"}
					= "$images_subdomain/images/products/$path/$id."
					. $product_ref->{images}{$id}{rev} . '.'
					. $small_size . '.jpg';
				$product_ref->{"image_" . $imagetype . "_thumb_url"}
					= "$images_subdomain/images/products/$path/$id."
					. $product_ref->{images}{$id}{rev} . '.'
					. $thumb_size . '.jpg';

				if ($imagetype eq 'front') {
					# front image is product image
					$product_ref->{image_url} = $product_ref->{"image_" . $imagetype . "_url"};
					$product_ref->{image_small_url} = $product_ref->{"image_" . $imagetype . "_small_url"};
					$product_ref->{image_thumb_url} = $product_ref->{"image_" . $imagetype . "_thumb_url"};
				}

				last;
			}
		}

		if (defined $product_ref->{languages_codes}) {
			# compute selected image for each product language
			foreach my $key (keys %{$product_ref->{languages_codes}}) {
				my $id = $imagetype . '_' . $key;
				if (    (defined $product_ref->{images})
					and (defined $product_ref->{images}{$id})
					and (defined $product_ref->{images}{$id}{sizes})
					and (defined $product_ref->{images}{$id}{sizes}{$size}))
				{

					$product_ref->{selected_images}{$imagetype}{display}{$key}
						= "$images_subdomain/images/products/$path/$id."
						. $product_ref->{images}{$id}{rev} . '.'
						. $display_size . '.jpg';
					$product_ref->{selected_images}{$imagetype}{small}{$key}
						= "$images_subdomain/images/products/$path/$id."
						. $product_ref->{images}{$id}{rev} . '.'
						. $small_size . '.jpg';
					$product_ref->{selected_images}{$imagetype}{thumb}{$key}
						= "$images_subdomain/images/products/$path/$id."
						. $product_ref->{images}{$id}{rev} . '.'
						. $thumb_size . '.jpg';
				}
			}
		}
	}

	return;
}

=head2 analyze_and_enrich_product_data ($product_ref, $response_ref)

This function processes product raw data to analyze it and enrich it.
For instance to analyze ingredients and compute scores such as Nutri-Score and Environmental-Score.

=head3 Parameters

=head4 $product_ref (input)

Reference to a product.

=head4 $response_ref (output)

Reference to a response object to which we can add errors and warnings.

=cut

sub analyze_and_enrich_product_data ($product_ref, $response_ref) {

	$log->debug("analyze_and_enrich_product_data - start") if $log->is_debug();

	# Initialiaze the misc_tags, they will be populated by functions called by this function
	$product_ref->{misc_tags} = [];

	if (    (defined $product_ref->{nutriments}{"carbon-footprint"})
		and ($product_ref->{nutriments}{"carbon-footprint"} ne ''))
	{
		push @{$product_ref->{"labels_hierarchy"}}, "en:carbon-footprint";
		push @{$product_ref->{"labels_tags"}}, "en:carbon-footprint";
	}

	if ((defined $product_ref->{nutriments}{"glycemic-index"}) and ($product_ref->{nutriments}{"glycemic-index"} ne ''))
	{
		push @{$product_ref->{"labels_hierarchy"}}, "en:glycemic-index";
		push @{$product_ref->{"labels_tags"}}, "en:glycemic-index";
	}

	# For fields that can have different values in different languages, copy the main language value to the non suffixed field

	foreach my $field (keys %language_fields) {
		if ($field !~ /_image/) {
			if (defined $product_ref->{$field . "_$product_ref->{lc}"}) {
				$product_ref->{$field} = $product_ref->{$field . "_$product_ref->{lc}"};
			}
		}
	}

	# Normalize the product quantity and serving size fields
	# Needed before we analyze packaging data in order to compute packaging weights per 100g of product
	normalize_product_quantity_and_serving_size($product_ref);

	# We need packaging analysis before calling the Environmental-Score for food products
	analyze_and_combine_packaging_data($product_ref, $response_ref);

	compute_languages($product_ref);    # need languages for allergens detection and cleaning ingredients

	# change the product type of non-food categorized products (issue #11094)
	if (has_tag($product_ref, "categories", "en:incorrect-product-type")) {
		review_product_type($product_ref);
	}

	# Run special analysis, score calculations that it specific to the product type

	if (($options{product_type} eq "food")) {
		specific_processes_for_food_product($product_ref);
	}
	elsif (($options{product_type} eq "petfood")) {
		specific_processes_for_pet_food_product($product_ref);
	}
	elsif (($options{product_type} eq "beauty")) {
		specific_processes_for_beauty_product($product_ref);
	}

	ProductOpener::DataQuality::check_quality($product_ref);

	if (defined $taxonomy_fields{'ingredients'}) {
		check_ingredients_between_languages($product_ref);
	}

	# Sort misc_tags in order to have a consistent order
	if (defined $product_ref->{misc_tags}) {
		$product_ref->{misc_tags} = [sort @{$product_ref->{misc_tags}}];
	}

	return;
}

=head2 is_owner_field($product_ref, $field)

Return 1 if the field value was provided by the owner (producer) and the field is not a tag field.

=cut

sub is_owner_field ($product_ref, $field) {

	if (
		(defined $product_ref->{owner_fields})
		and (
			(defined $product_ref->{owner_fields}{$field})
			# If the producer sent a field value for salt or sodium, the other value was automatically computed
			or (($field =~ /^salt/) and (defined $product_ref->{owner_fields}{"sodium" . $'}))
			or (($field =~ /^sodium/) and (defined $product_ref->{owner_fields}{"salt" . $'}))
		)
		# Even if the producer sent a tag field value, it was merged with existing values,
		# and may have been updated by a contributor (e.g. to add a more precise category)
		# So we don't consider them to be owner fields
		and (not defined $tags_fields{$field})
		)
	{
		return 1;
	}
	return 0;
}
