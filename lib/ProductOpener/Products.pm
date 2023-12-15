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
		&normalize_code
		&normalize_code_with_gs1_ai
		&assign_new_code
		&split_code
		&product_id_for_owner
		&server_for_product_id
		&data_root_for_product_id
		&www_root_for_product_id
		&product_path
		&product_path_from_id
		&product_id_from_path
		&product_exists
		&product_exists_on_other_server
		&get_owner_id
		&init_product
		&retrieve_product
		&retrieve_product_or_deleted_product
		&retrieve_product_rev
		&store_product
		&send_notification_for_product_change
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
		&compute_changes_diff_text
		&compute_data_sources
		&compute_sort_keys

		&add_back_field_values_removed_by_user

		&process_product_edit_rules
		&preprocess_product_field
		&product_data_is_protected

		&make_sure_numbers_are_stored_as_numbers
		&change_product_server_or_code

		&find_and_replace_user_id_in_products

		&add_users_team

		&remove_fields

		&add_images_urls_to_product

		&analyze_and_enrich_product_data

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Orgs qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::URL qw/:all/;
use ProductOpener::Data qw/:all/;
use ProductOpener::MainCountries qw/:all/;
use ProductOpener::Text qw/:all/;
use ProductOpener::Display qw/single_param/;
use ProductOpener::Redis qw/push_to_redis_stream/;

# needed by analyze_and_enrich_product_data()
# may be moved to another module at some point
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Nutriscore qw/:all/;
use ProductOpener::Ecoscore qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;
use ProductOpener::Packaging qw/:all/;
use ProductOpener::DataQuality qw/:all/;

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
	}
	return $code;
}

=head2 normalize_code_with_gs1_ai()

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

		# Add a leading 0 to valid UPC-12 codes
		# invalid 12 digit codes may be EAN-13s with a missing number
		if ((length($code) eq 12) and ($ean_check->is_valid('0' . $code))) {
			$code = '0' . $code;
		}

		# Remove leading 0 for codes with 14 digits
		if ((length($code) eq 14) and ($code =~ /^0/)) {
			$code = $';
		}

		# Remove 5 or 6 leading 0s for EAN8
		# 00000080050100 (from Ferrero)
		if ((length($code) eq 14) and ($code =~ /^000000/)) {
			$code = $';
		}
		if ((length($code) eq 13) and ($code =~ /^00000/)) {
			$code = $';
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
		$log->warn("GS1Parser error", {error => $@}) if $log->is_warn();
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
	if ($code !~ /^\d{4,24}$/) {

		$log->info("invalid code", {code => $code}) if $log->is_info();
		return "invalid";
	}

	# First splits into 3 sections of 3 numbers and the ast section with the remaining numbers
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

The product id can be prefixed by a server id to indicate that is is on another server
(e.g. Open Food Facts, Open Beauty Facts, Open Products Facts or Open Pet Food Facts)
e.g. off:[code]

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

	if ((defined $server_options{private_products}) and ($server_options{private_products})) {
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

=head2 server_for_product_id ( $product_id )

Returns the server for the product, if it is not on the current server.

=head3 Parameters

=head4 $product_id

Product id of the form [code], [owner-id]/[code], or [server-id]:[code] or [server-id]:[owner-id]/[code]

=head3 Return values

undef is the product is on the current server, or server id of the server of the product otherwise.

=cut

sub server_for_product_id ($product_id) {

	if ($product_id =~ /:/) {

		my $server = $`;

		return $server;
	}

	return;
}

=head2 data_root_for_product_id ( $product_id )

Returns the data root for the product, possibly on another server.

=head3 Parameters

=head4 $product_id

Product id of the form [code], [owner-id]/[code], or [server-id]:[code]

=head3 Return values

The data root for the product.

=cut

sub data_root_for_product_id ($product_id) {

	if ($product_id =~ /:/) {

		my $server = $`;

		if ((defined $options{other_servers}) and (defined $options{other_servers}{$server})) {
			return $options{other_servers}{$server}{data_root};
		}
	}

	return $data_root;
}

=head2 www_root_for_product_id ( $product_id )

Returns the www root for the product, possibly on another server.

=head3 Parameters

=head4 $product_id

Product id of the form [code], [owner-id]/[code], or [server-id]:[code]

=head3 Return values

The www root for the product.

=cut

sub www_root_for_product_id ($product_id) {

	if ($product_id =~ /:/) {

		my $server = $`;

		if ((defined $options{other_servers}) and (defined $options{other_servers}{$server})) {
			return $options{other_servers}{$server}{www_root};
		}
	}

	return $www_root;
}

=head2 product_path_from_id ( $product_id )

Returns the relative path for the product.

=head3 Parameters

=head4 $product_id

Product id of the form [code], [owner-id]/[code], or [server-id]:[code]

=head3 Return values

The relative path for the product.

=cut

sub product_path_from_id ($product_id) {

	my $product_id_without_server = $product_id;
	$product_id_without_server =~ s/(.*)://;

	if (    (defined $server_options{private_products})
		and ($server_options{private_products})
		and ($product_id_without_server =~ /\//))
	{
		return $` . "/" . split_code($');
	}
	else {
		return split_code($product_id_without_server);
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

	if ((defined $server_options{private_products}) and ($server_options{private_products})) {
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

sub product_exists ($product_id) {

	# deprecated, just use retrieve_product()

	my $product_ref = retrieve_product($product_id);

	if (not defined $product_ref) {
		return 0;
	}
	else {
		return $product_ref;
	}
}

sub product_exists_on_other_server ($server, $id) {

	if (not((defined $options{other_servers}) and (defined $options{other_servers}{$server}))) {
		return 0;
	}

	my $server_data_root = $options{other_servers}{$server}{data_root};

	my $path = product_path_from_id($id);

	$log->debug("product_exists_on_other_server",
		{id => $id, server => $server, server_data_root => $server_data_root, path => $path})
		if $log->is_debug();

	if (-e "$server_data_root/products/$path") {

		my $product_ref = retrieve("$server_data_root/products/$path/product.sto");
		if ((not defined $product_ref) or ($product_ref->{deleted})) {
			return 0;
		}
		else {
			return $product_ref;
		}
	}
	else {
		return 0;
	}
}

sub get_owner_id ($userid, $orgid, $ownerid) {

	if ((defined $server_options{private_products}) and ($server_options{private_products})) {

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
	};

	if (defined $server) {
		$product_ref->{server} = $server;
	}

	if ((defined $server_options{private_products}) and ($server_options{private_products})) {
		my $ownerid = get_owner_id($userid, $orgid, $Owner_id);

		$product_ref->{owner} = $ownerid;
		$product_ref->{_id} = $ownerid . "/" . $code;

		$log->debug(
			"init_product - private_products enabled",
			{userid => $userid, orgid => $orgid, code => $code, ownerid => $ownerid, product_id => $product_ref->{_id}}
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

=head2 send_notification_for_product_change ( $user_id, $product_ref, $action, $comment, $diffs )

Notify Robotoff when products are updated or deleted.

=head3 Parameters

=head4 $user_id

ID of the user that triggered the update/deletion (String, may be undefined)

=head4 $product_ref

Reference to the updated/deleted product.

=head4 $action

The action performed, either `deleted` or `updated` (String).

=head4 $comment

The update comment (String)

=head4 $diffs

The `diffs` of the update (Hash)

=cut

sub send_notification_for_product_change ($user_id, $product_ref, $action, $comment, $diffs) {

	if ((defined $robotoff_url) and (length($robotoff_url) > 0)) {
		my $ua = LWP::UserAgent->new();
		my $endpoint = "$robotoff_url/api/v1/webhook/product";
		$ua->timeout(2);
		my $diffs_json_text = encode_json($diffs);

		$log->debug(
			"send_notif_robotoff_product_update",
			{
				endpoint => $endpoint,
				barcode => $product_ref->{code},
				action => $action,
				server_domain => "api." . $server_domain,
				user_id => $user_id,
				comment => $comment,
				diffs => $diffs_json_text
			}
		) if $log->is_debug();
		my $response = $ua->post(
			$endpoint,
			{
				'barcode' => $product_ref->{code},
				'action' => $action,
				'server_domain' => "api." . $server_domain,
				'user_id' => $user_id,
				'comment' => $comment,
				'diffs' => $diffs_json_text
			}
		);
		$log->debug(
			"send_notif_robotoff_product_update",
			{
				endpoint => $endpoint,
				is_success => $response->is_success,
				code => $response->code,
				status_line => $response->status_line
			}
		) if $log->is_debug();
	}

	return;
}

sub retrieve_product ($product_id) {

	my $path = product_path_from_id($product_id);
	my $product_data_root = data_root_for_product_id($product_id);

	my $full_product_path = "$product_data_root/products/$path/product.sto";

	$log->debug(
		"retrieve_product",
		{
			product_id => $product_id,
			product_data_root => $product_data_root,
			path => $path,
			full_product_path => $full_product_path
		}
	) if $log->is_debug();

	my $product_ref = retrieve($full_product_path);

	# If the product is on another server, set the server field so that it will be saved in the other server if we save it
	my $server = server_for_product_id($product_id);

	if (not defined $product_ref) {
		$log->debug("retrieve_product - product does not exist",
			{product_id => $product_id, product_data_root => $product_data_root, path => $path, server => $server})
			if $log->is_debug();
	}
	else {
		if (defined $server) {
			$product_ref->{server} = $server;
			$log->debug(
				"retrieve_product - product on another server",
				{product_id => $product_id, product_data_root => $product_data_root, path => $path, server => $server}
			) if $log->is_debug();
		}

		if ($product_ref->{deleted}) {
			$log->debug(
				"retrieve_product - deleted product",
				{product_id => $product_id, product_data_root => $product_data_root, path => $path, server => $server}
			) if $log->is_debug();
			return;
		}
	}

	return $product_ref;
}

sub retrieve_product_or_deleted_product ($product_id, $deleted_ok = 1) {

	my $path = product_path_from_id($product_id);
	my $product_data_root = data_root_for_product_id($product_id);

	my $product_ref = retrieve("$product_data_root/products/$path/product.sto");

	# If the product is on another server, set the server field so that it will be saved in the other server if we save it
	my $server = server_for_product_id($product_id);
	if ((defined $product_ref) and (defined $server)) {
		$product_ref->{server} = $server;
	}

	if (    (defined $product_ref)
		and ($product_ref->{deleted})
		and (not $deleted_ok))
	{
		return;
	}

	return $product_ref;
}

sub retrieve_product_rev ($product_id, $rev) {

	if ($rev !~ /^\d+$/) {
		return;
	}

	my $path = product_path_from_id($product_id);
	my $product_data_root = data_root_for_product_id($product_id);

	my $product_ref = retrieve("$product_data_root/products/$path/$rev.sto");

	# If the product is on another server, set the server field so that it will be saved in the other server if we save it
	my $server = server_for_product_id($product_id);
	if ((defined $product_ref) and (defined $server)) {
		$product_ref->{server} = $server;
	}

	if ((defined $product_ref) and ($product_ref->{deleted})) {
		return;
	}

	return $product_ref;
}

sub change_product_server_or_code ($product_ref, $new_code, $errors_ref) {

	# Currently only called by admins, can cause issues because of bug #677

	my $code = $product_ref->{code};
	my $new_server = "";
	my $new_data_root = $data_root;

	if ($new_code =~ /^([a-z]+)$/) {
		$new_server = $1;
		if (    (defined $options{other_servers})
			and (defined $options{other_servers}{$new_server})
			and ($options{other_servers}{$new_server}{data_root} ne $data_root))
		{
			$new_code = $code;
			$new_data_root = $options{other_servers}{$new_server}{data_root};
		}
	}

	$new_code = normalize_code($new_code);
	if ($new_code !~ /^\d{4,24}$/) {
		push @$errors_ref, lang("invalid_barcode");
	}
	else {
		# check that the new code is available
		if (-e "$new_data_root/products/" . product_path_from_id($new_code)) {
			push @{$errors_ref}, lang("error_new_code_already_exists");
			$log->warn(
				"cannot change product code, because the new code already exists",
				{code => $code, new_code => $new_code, new_server => $new_server}
			) if $log->is_warn();
		}
		else {
			$product_ref->{old_code} = $code;
			$code = $new_code;
			$product_ref->{code} = $code;
			if ($new_server ne '') {
				$product_ref->{new_server} = $new_server;
			}
			$log->info("changing code",
				{old_code => $product_ref->{old_code}, code => $code, new_server => $new_server})
				if $log->is_info();
		}
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

=head2 store_product ($user_id, $product_ref, $comment, $client_id = undef)

Save changes of a product:
- in a new .sto file on the disk
- in MongoDB (in the products collection, or products_obsolete collection if the product is obsolete)

Before saving, some field values are computed, and product history and completeness is computed.

=cut

sub store_product ($user_id, $product_ref, $comment, $client_id = undef) {

	my $code = $product_ref->{code};
	my $product_id = $product_ref->{_id};
	my $path = product_path($product_ref);
	my $rev = $product_ref->{rev};

	$log->debug(
		"store_product - start",
		{
			code => $code,
			product_id => $product_id,
			obsolete => $product_ref->{obsolete},
			was_obsolete => $product_ref->{was_obsolete}
		}
	) if $log->is_debug();

	# In case we need to move a product from OFF to OBF etc.
	# the "new_server" value will be set to off, obf etc.
	# we first move the existing files (product and images)
	# and then store the product with a comment.

	# if we have a "server" value (e.g. from an import),
	# we save the product on the corresponding server but we don't need to move an existing product

	my $new_data_root = $data_root;
	my $new_www_root = $www_root;

	# We use the was_obsolete flag so that we can remove the product from its old collection
	# (either products or products_obsolete) if its obsolete status has changed
	my $previous_products_collection = get_products_collection({obsolete => $product_ref->{was_obsolete}});
	my $new_products_collection = get_products_collection({obsolete => $product_ref->{obsolete}});
	my $delete_from_previous_products_collection = 0;

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
	}
	delete $product_ref->{was_obsolete};

	if (    (defined $product_ref->{server})
		and (defined $options{other_servers})
		and (defined $options{other_servers}{$product_ref->{server}}))
	{
		my $server = $product_ref->{server};
		$new_data_root = $options{other_servers}{$server}{data_root};
		$new_www_root = $options{other_servers}{$server}{www_root};
		$new_products_collection = get_products_collection(
			{database => $options{other_servers}{$server}{mongodb}, obsolete => $product_ref->{obsolete}});
	}

	if (defined $product_ref->{old_code}) {

		my $old_code = $product_ref->{old_code};
		my $old_path = product_path_from_id($old_code);

		if (defined $product_ref->{new_server}) {
			my $new_server = $product_ref->{new_server};
			$new_data_root = $options{other_servers}{$new_server}{data_root};
			$new_www_root = $options{other_servers}{$new_server}{www_root};
			$new_products_collection = get_products_collection(
				{database => $options{other_servers}{$new_server}{mongodb}, obsolete => $product_ref->{obsolete}});
			$product_ref->{server} = $product_ref->{new_server};
			delete $product_ref->{new_server};
		}

		$log->info("moving product", {old_code => $old_code, code => $code, new_data_root => $new_data_root})
			if $log->is_info();

		# Move directory

		my $prefix_path = $path;
		$prefix_path =~ s/\/[^\/]+$//;    # remove the last subdir: we'll move it
		if ($path eq $prefix_path) {
			# short barcodes with no prefix
			$prefix_path = '';
		}

		$log->debug("creating product directories", {path => $path, prefix_path => $prefix_path}) if $log->is_debug();
		# Create the directories for the product
		ensure_dir_created_or_die("$new_data_root/products/$prefix_path");
		ensure_dir_created_or_die("$new_www_root/images/products/$prefix_path");

		if (    (!-e "$new_data_root/products/$path")
			and (!-e "$new_www_root/images/products/$path"))
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
			dirmove("$BASE_DIRS{PRODUCTS}/$old_path", "$new_data_root/products/$path")
				or $log->error(
				"could not move product data",
				{source => "$BASE_DIRS{PRODUCTS}/$old_path", destination => "$BASE_DIRS{PRODUCTS}/$path", error => $!}
				);

			$log->debug(
				"moving product images",
				{
					source => "$BASE_DIRS{PRODUCTS_IMAGES}/$old_path",
					destination => "$new_www_root/images/products/$path"
				}
			) if $log->is_debug();
			dirmove("$BASE_DIRS{PRODUCTS_IMAGES}/$old_path", "$new_www_root/images/products/$path")
				or $log->error(
				"could not move product images",
				{
					source => "$BASE_DIRS{PRODUCTS_IMAGES}/$old_path",
					destination => "$new_www_root/images/products/$path",
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
			(-e "$new_data_root/products/$path")
				and $log->error("cannot move product data, because the destination already exists",
				{source => "$BASE_DIRS{PRODUCTS}/$old_path", destination => "$BASE_DIRS{PRODUCTS}/$path"});
			(-e "$new_www_root/products/$path")
				and $log->error(
				"cannot move product images data, because the destination already exists",
				{
					source => "$BASE_DIRS{PRODUCTS_IMAGES}/$old_path",
					destination => "$new_www_root/images/products/$path"
				}
				);
		}

		$comment .= " - barcode changed from $old_code to $code by $user_id";
	}

	if ($rev < 1) {
		# Create the directories for the product
		ensure_dir_created_or_die("$new_data_root/products/$path");
		ensure_dir_created_or_die("$new_www_root/images/products/$path");
	}

	# Check lock and previous version
	my $changes_ref = retrieve("$new_data_root/products/$path/changes.sto");
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
	$product_ref->{last_modified_by} = $user_id;
	$product_ref->{last_modified_by_client} = $client_id;
	$product_ref->{last_modified_t} = time() + 0;
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
		clientid => $client_id,
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

	compute_product_history_and_completeness($new_data_root, $product_ref, $changes_ref, $blame_ref);

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
	store("$new_data_root/products/$path/$rev.sto", $product_ref);

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
	my $link = "$new_data_root/products/$path/product.sto";
	if (-l $link) {
		unlink($link) or $log->error("could not unlink old product.sto", {link => $link, error => $!});
	}

	symlink("$rev.sto", $link)
		or $log->error("could not symlink to new revision",
		{source => "$new_data_root/products/$path/$rev.sto", link => $link, error => $!});

	store("$new_data_root/products/$path/changes.sto", $changes_ref);
	log_change($product_ref, $change_ref);

	$log->debug("store_product - done", {code => $code, product_id => $product_id}) if $log->is_debug();

	my $update_type = $product_ref->{deleted} ? "deleted" : "updated";
	# Publish information about update on Redis stream
	push_to_redis_stream($user_id, $product_ref, $update_type, $comment, $diffs);

	# Notify Robotoff
	send_notification_for_product_change($user_id, $product_ref, $update_type, $comment, $diffs);

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

sub compute_completeness_and_missing_tags ($product_ref, $current_ref, $previous_ref) {

	my $lc = $product_ref->{lc};
	if (not defined $lc) {
		# Try lang field
		if (defined $product_ref->{lang}) {
			$lc = $product_ref->{lang};
		}
		else {
			$lc = "en";
			$product_ref->{lang} = "en";
		}
		$product_ref->{lc} = $lc;
	}

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
	if ((defined $server_options{private_products}) and ($server_options{private_products})) {
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

sub compute_product_history_and_completeness ($product_data_root, $current_product_ref, $changes_ref, $blame_ref) {

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
		my $product_ref = retrieve("$product_data_root/products/$path/$rev.sto");

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

					$packagings_data_signature .= "number_of_units:" . $number_of_units . ',';
					foreach my $property (qw(shape material recycling quantity_per_unit)) {
						$packagings_data_signature .= $property . ":" . ($packagings_ref->{$property} || '') . ',';
					}
					$packagings_data_signature .= "\n";
					$packagings_weights_signature .= ($weight_measured || '') . "\n";
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
				@ids = @{$nutriments_lists{europe}};
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
	return "/$path/$code" . $titleid;
}

=head2 product_action_url ( $code, $action )

Returns a relative URL for an action on a product on the website.

This function is called by the web/panels/panel.tt.html template for knowledge panels that have associated actions.

=head3 Parameters

=head4 Product code or reference to product object $code_or_ref

=cut

sub product_action_url ($code, $action) {

	my $url = "/cgi/product.pl?type=edit&code=" . $code;

	if ($action eq "add_categories") {
		$url .= "#categories";
	}
	elsif ($action eq "add_ingredients_image") {
		$url .= "#ingredients";
	}
	elsif ($action eq "add_ingredients_text") {
		$url .= "#ingredients";
	}
	elsif ($action eq "add_nutrition_facts_image") {
		$url .= "#nutrition";
	}
	elsif ($action eq "add_nutrition_facts") {
		$url .= "#nutrition";
	}
	elsif ($action eq "add_packaging_image") {
		$url .= "#packaging";
	}
	elsif ($action eq "add_packaging_text") {
		$url .= "#packaging";
	}
	elsif ($action eq "add_packaging_components") {
		$url .= "#packaging";
	}
	# Note: 27/11/2022 - Pierre - The following HTML anchors links will do nothing unless a matching custom HTML anchor is added in the future to the product edition template
	elsif ($action eq "add_origins") {
		$url .= "#origins";
	}
	elsif ($action eq "add_quantity") {
		$url .= "#product_characteristics";
	}
	elsif ($action eq "add_stores") {
		$url .= "#stores";
	}
	elsif ($action eq "add_packager_codes_image") {
		$url .= "#packager_codes";
	}
	elsif ($action eq "add_labels") {
		$url .= "#labels";
	}
	elsif ($action eq "add_countries") {
		$url .= "#countries";
	}
	# END will do nothing unless a custom section is added
	else {
		$log->error("unknown product action", {code => $code, action => $action});
	}

	return $url;
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

	if (length($code) == 12) {
		$ean = '0' . $code;
		if (product_exists('0' . $code)) {
			push @codes, "conflict-with-ean-13";
		}
		elsif (-e ("$BASE_DIRS{PRODUCTS}/" . product_path_from_id("0" . $code))) {
			push @codes, "conflict-with-deleted-ean-13";
		}
	}

	if ((length($code) == 13) and ($code =~ /^0/)) {
		$ean = $code;
		my $upc = $code;
		$upc =~ s/^.//;
		if (product_exists($upc)) {
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

=head2 process_product_edit_rules ($product_ref)

Process the edit_rules (see C<@edit_rules> in in Config file).

=head3 where it applies

It applies in all API/form that edit the product.
It applies to apply an image crop.

It does not block image upload.

=head3 edit_rules structure

=over 1
=item * name: rule name to identify it in logs and describe it
=item * conditions: the conditions the product must match, a list of [fieldname, value]
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

=head2 add_images_urls_to_product ($product_ref, $target_lc)

Add fields like image_[front|ingredients|nutrition|packaging]_[url|small_url|thumb_url] to a product object.

If it exists, the image for the target language will be returned, otherwise we will return the image
in the main language of the product.

=head3 Parameters

=head4 $product_ref

Reference to a complete product a subfield.

=head4 $target_lc

2 language code of the preferred language for the product images.

=cut

sub add_images_urls_to_product ($product_ref, $target_lc) {

	my $images_subdomain = format_subdomain('images');

	my $path = product_path($product_ref);

	foreach my $imagetype ('front', 'ingredients', 'nutrition', 'packaging') {

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
For instance to analyze ingredients and compute scores such as Nutri-Score and Eco-Score.

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

	compute_languages($product_ref);    # need languages for allergens detection and cleaning ingredients

	# Ingredients classes
	# Select best language to parse ingredients
	$product_ref->{ingredients_lc} = select_ingredients_lc($product_ref);
	clean_ingredients_text($product_ref);
	extract_ingredients_from_text($product_ref);
	extract_ingredients_classes_from_text($product_ref);
	detect_allergens_from_text($product_ref);

	# Food category rules for sweetened/sugared beverages
	# French PNNS groups from categories

	if ((defined $options{product_type}) and ($options{product_type} eq "food")) {
		ProductOpener::Food::special_process_product($product_ref);
	}

	# Compute nutrition data per 100g and per serving

	$log->debug("compute nutrition data") if $log->is_debug();

	fix_salt_equivalent($product_ref);

	compute_serving_size_data($product_ref);

	compute_estimated_nutrients($product_ref);

	compute_nutriscore($product_ref);

	compute_nova_group($product_ref);

	compute_nutrient_levels($product_ref);

	compute_unknown_nutrients($product_ref);

	analyze_and_combine_packaging_data($product_ref, $response_ref);

	if ((defined $options{product_type}) and ($options{product_type} eq "food")) {
		compute_ecoscore($product_ref);
		compute_forest_footprint($product_ref);
	}

	ProductOpener::DataQuality::check_quality($product_ref);

	return;
}

1;
