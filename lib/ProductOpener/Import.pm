# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

ProductOpener::Import - import products data in CSV format and products photos

=head1 SYNOPSIS

C<ProductOpener::Import> is used to import product data in the Open Food Facts CSV format
and associated product photos.

    use ProductOpener::Import qw/:all/;
	import_csv_file( {
		user_id => "user",
		org_id => "organization",
		csv_file => "/path/to/product_data.csv",
	});

This module is used to import product data provided by manufacturers on the producers platform:
the data from manufacturers (in CSV or Excel files) is first converted to the Open Food Facts
CSV format, then imported with C<import_csv_file>.

It is also used to export product data from the producers platform to the public database.
The data is first exported from the producers platform with the C<ProductOpener::Export> module,
and then imported in the public database with the C<import_csv_file> function.

In the producers platform, the C<import_csv_file> function is executed through a Minion worker.

It is also used in the C<scripts/import_csv_file.pl> script.

=head1 DESCRIPTION

..

=cut

package ProductOpener::Import;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

use Log::Any qw($log);

use Storable qw(dclone);
use Text::Fuzzy;

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&import_csv_file
		&import_products_categories_from_public_database

		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::DataQuality qw/:all/;
use ProductOpener::Data qw/:all/;
use ProductOpener::ImportConvert qw/clean_fields clean_weights assign_quantity_from_field/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Orgs qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use Data::Dumper;
use Text::CSV;

=head1 FUNCTIONS

=head2 import_csv_file ( ARGUMENTS )

C<import_csv_file()> imports product data in the Open Food Facts CSV format
and associated product photos.

=head3 Arguments

Arguments are passed through a single hash reference with the following keys:

=head4 user_id - required

User id to which the changes (new products, added or changed values, new images)
will be attributed.

=head4 org_id - optional

Organisation id to which the changes (new products, added or changed values, new images)
will be attributed.

=head4 owner_id - optional

For databases with private products, owner (user or org) that the products belong to.
Values are of the form user-[user id] or org-[organization id].

If not set, for databases with private products, it will be constructed from the user_id
and org_id parameters.

The owner can be overriden if the CSV file contains a org_name field.
In that case, the owner is set to the value of the org_name field, and
a new org is created if it does not exist yet.

=head4 csv_file - required

Path and file name of the CSV file to import.

The CSV file needs to be in the Open Food Facts CSV format, encoded in UTF-8
with tabs as separators.

=head4 global_values - optional

Hash ref that specifies fields and values that will be used as default values.

If the CSV contains a non-empty value for a field, the value from the CSV file is used.

=head4 images_dir - optional

Path to a directory that contains images for the products.

=head4 comment - optional

Comment that will be saved in the product history.

=head4 no_source - optional

Indicates that there should not be a data source attribution.

=head4 source_id - required (unless no_source is indicated)

Source id for the data and images.

=head4 source_name - required (unless no_source is indicated)

Name of the source.

=head4 source_url - required (unless no_source is indicated)

URL for the source.

=head4 source_licence - optional (unless no_source is indicated)

Licence that the source data is available in.

=head4 source_licence_url - optional (unless no_source is indicated)

URL for the licence.

=head4 manufacturer - optional

A positive value indicates that the data is imported from the manufacturer of the products.

=head4 test - optional

Compute statistics on the number of products the import would add or change,
but do not actually import and save the changes.

=head4 skip_if_not_code - optional

Only import one product with the corresponding code.

=head4 skip_not_existing_products - optional

Only import product data if the product already exists in the database.
This can be useful when we have very sparse data to import
(e.g. a list of codes of products sold in a given store chain), and we do not want
to create products when we have no other existing data.

=head4 skip_products_without_info - optional

Do not import products when we do not have info (product name or brands)

=head4 skip_products_without_images - optional

Do not import products if there are no corresponding images in the directory
specified by the images_dir argument/

=head4 skip_existing_values - optional

If a product already has existing values for some fields, do not overwrite it with
values from the CSV file.

=head4 only_select_not_existing_images - optional

If the product already has an image for front, ingredients or nutrition in a given
language, do not overwrite it with an image from the import. The image will still be
uploaded and added to the product, but it will not be selected.

=cut

sub import_csv_file($) {

	my $args_ref = shift;

	$User_id = $args_ref->{user_id};
	$Org_id = $args_ref->{org_id};
	$Owner_id = get_owner_id($User_id, $Org_id, $args_ref->{owner_id});

	$log->debug("starting import_csv_file", { User_id => $User_id, Org_id => $Org_id, Owner_id => $Owner_id }) if $log->is_debug();

	my %global_values = ();
	if (defined $args_ref->{global_values}) {
		%global_values = %{$args_ref->{global_values}};
	}

	my %stats = (
	'products_in_file' => {},
	'products_already_existing' => {},
	'products_created' => {},
	'products_data_updated' => {},
	'products_data_not_updated' => {},
	'products_info_added' => {},
	'products_info_changed' => {},
	'products_info_updated' => {},
	'products_info_not_updated' => {},
	'products_nutrition_added' => {},
	'products_nutrition_changed' => {},
	'products_nutrition_updated' => {},
	'products_nutrition_not_updated' => {},
	'products_images_added' => {},
	'products_with_images' => {},
	'products_with_data' => {},
	'products_with_info' => {},
	'products_with_ingredients' => {},
	'products_with_nutrition' => {},
	'products_without_images' => {},
	'products_without_data' => {},
	'products_without_info' => {},
	'products_without_info' => {},
	'products_without_nutrition' => {},
	'products_updated' => {},

	);

	my $csv = Text::CSV->new ( { binary => 1 , sep_char => "\t" } )  # should set binary attribute.
					 or die "Cannot use CSV: ".Text::CSV->error_diag ();

	my $time = time();

	my $i = 0;
	my $j = 0;
	my $existing = 0;
	my $new = 0;
	my $differing = 0;
	my %differing_fields = ();
	my @edited = ();
	my %edited = ();
	my %nutrients_edited = ();

	# Read images if supplied

	my @sorted_nutriments = sort keys %Nutriments;

	my $images_ref = {};

	if ((defined $args_ref->{images_dir}) and ($args_ref->{images_dir} ne '')) {

		if (not -d $args_ref->{images_dir}) {
			die("images_dir $args_ref->{images_dir} is not a directory\n");
		}

		# images rules to assign front/ingredients/nutrition image ids

		my @images_rules = ();

		if (-e "$args_ref->{images_dir}/images.rules") {

			$log->debug("found images.rules in images_dir", { images_dir => $args_ref->{images_dir} }) if $log->is_debug();

			open (my $in, '<', "$args_ref->{images_dir}/images.rules") or die "Could not open $args_ref->{images_dir}/images.rules : $!\n";
			my $line_number = 0;
			while (<$in>) {

				my $line = $_;
				chomp($line);

				$line_number++;

				if ($line =~ /^#/) {
					next;
				}
				elsif ($line =~ /^([^\t]+)\t([^\t]+)/) {
					push @images_rules, [$1, $2];
					print STDERR "adding rule - find: $1 - replace: $2\n";
					$log->debug("adding rule", { find => $1, replace => $2 }) if $log->is_debug();
				}
				else {
					die("Unrecognized line number $i: $line_number\n");
				}
			}
		}
		else {
			$log->debug("did not find images.rules in images_dir", { images_dir => $args_ref->{images_dir} }) if $log->is_debug();
		}

		$log->debug("opening images_dir", { images_dir => $args_ref->{images_dir} }) if $log->is_debug();

		if (opendir (DH, "$args_ref->{images_dir}")) {
			foreach my $file (sort { $a cmp $b } readdir(DH)) {

				# apply image rules to the file name to assign front/ingredients/nutrition
				my $file2 = $file;

				foreach my $images_rule_ref (@images_rules) {
					my $find = $images_rule_ref->[0];
					my $replace = $images_rule_ref->[1];
					#$file2 =~ s/$find/$replace/e;
					# above line does not work

					my $str = $file2;
					my $pat = $find;
					my $repl = $replace;

					# make $repl safe to eval
					$repl =~ tr/\0//d;
					$repl =~ s/([^A-Za-z0-9\$])/\\$1/g;
					$repl = '"' . $repl . '"';
					$str =~ s/$pat/$repl/eeg;

					$file2 = $str;

					if ($file2 ne $file) {
						$log->debug("applied rule", { find => $find, replace => $replace, file => $file, file2 => $file2 }) if $log->is_debug();
					}
				}

				if ($file2 =~ /(\d+)(_|-|\.)?([^\.-]*)?((-|\.)(.*))?\.(jpg|jpeg|png)/i) {

					if ((-s $args_ref->{images_dir} . "/" . "$file") < 10000) {
						$log->debug("skipping too small image file", { file => $file, size => (-s $file)}) if $log->is_debug();
						next;
					}

					my $code = $1;
					$code = normalize_code($code);
					my $imagefield = $3;    # front / ingredients / nutrition , optionnaly with _[language code] suffix

					if ((not defined $imagefield) or ($imagefield eq '')) {
						$imagefield = "front";
					}

					$stats{products_with_images_even_if_no_data}{$code} = 1;

					$log->debug("found image", { code => $code, imagefield => $imagefield, file => $file, file2 => $file2 }) if $log->is_debug();

					# skip jpg and keep png for front product image

					defined $images_ref->{$code} or $images_ref->{$code} = {};

					# push @{$images_ref->{$code}}, $file;
					# keep jpg if there is also a png
					if (not defined $images_ref->{$code}{$imagefield}) {
						$images_ref->{$code}{$imagefield} = $args_ref->{images_dir} . "/" . $file;
					}
				}
			}
		}
		else {
			die ("Could not open images_dir $args_ref->{images_dir} : $!\n");
		}
	}

	$log->debug("importing products", { }) if $log->is_debug();

	open (my $io, '<:encoding(UTF-8)', $args_ref->{csv_file}) or die("Could not open " . $args_ref->{csv_file} . ": $!");

	my $columns_ref = $csv->getline ($io);

	# We may have duplicate columns (e.g. image_other_url),
	# turn them to image_other_url.2 etc.

	my %seen_columns = ();
	my @column_names = ();

	foreach my $column (@{$columns_ref}) {
		if (defined $seen_columns{$column}) {
			$seen_columns{$column}++;
			push @column_names, $column . "." . $seen_columns{$column};
		}
		else {
			$seen_columns{$column} = 1;
			push @column_names, $column;
		}
	}

	$csv->column_names (@column_names);

	my $skip_not_existing = 0;
	my $skip_no_images = 0;

	while (my $imported_product_ref = $csv->getline_hr ($io)) {

		$i++;

		my $modified = 0;

		# Keep track of fields that have been modified, so that we don't import products that have not been modified
		my @modified_fields;

		my @images_ids;
				
		# If the CSV includes an org_name (e.g. from GS1 partyName field)
		# set the owner of the product to the org_name
		
		if ((defined $imported_product_ref->{org_name}) and ($imported_product_ref->{org_name} ne "")) {
			my $org_id = get_string_id_for_lang("no_language", $imported_product_ref->{org_name});
			if ($org_id ne "") {
				$Org_id = $org_id;
				$Owner_id = "org-" . $org_id;
				
				# Create the org if it does not exist yet
				if (not defined retrieve_org($org_id)) {
					
					my $org_ref = create_org($User_id, $imported_product_ref->{org_name});
			
					store_org($org_ref);
					
					my $admin_mail_body = <<EMAIL
user_id: $User_id
org_id: $org_id
org_name: $imported_product_ref->{org_name}
EMAIL
;
					send_email_to_admin("Import - Created org - user: $User_id - org: " . $Org_id, $admin_mail_body);
				}
			}
		}
		

		my $code = $imported_product_ref->{code};
		$code = normalize_code($code);
		my $product_id = product_id_for_owner($Owner_id, $code);

		if ((defined $args_ref->{skip_if_not_code}) and ($code ne $args_ref->{skip_if_not_code})) {
			next;
		}

		$log->debug("importing product", { i => $i, code => $code, product_id => $product_id }) if $log->is_debug();

		if ($code eq '') {
			$log->error("Error - empty code", { i => $i, code => $code, product_id => $product_id, imported_product_ref => $imported_product_ref }) if $log->is_error();
			next;
		}

		if ($code !~ /^\d\d\d\d\d\d\d\d(\d*)$/) {
			$log->error("Error - code not a number with 8 or more digits", { i => $i, code => $code, product_id => $product_id, imported_product_ref => $imported_product_ref }) if $log->is_error();
			next;
		}

		$stats{products_in_file}{$code} = 1;

		# apply global field values
		foreach my $field (keys %global_values) {
			if ((not defined $imported_product_ref->{$field}) or ($imported_product_ref->{$field} eq ""))  {
				$imported_product_ref->{$field} = $global_values{$field};
			}
		}

		if (not defined $imported_product_ref->{lc})  {
			$log->error("Error - missing language code lc in csv file or global field values", { i => $i, code => $code, product_id => $product_id, imported_product_ref => $imported_product_ref }) if $log->is_error();
			next;
		}

		if ($imported_product_ref->{lc} !~ /^\w\w$/) {
			$log->error("Error - lc is not a 2 letter language code", { lc => $lc, i => $i, code => $code, product_id => $product_id, imported_product_ref => $imported_product_ref }) if $log->is_error();
			next;
		}
		
		# Set the $lang field to $lc
		$imported_product_ref->{lang} = $imported_product_ref->{lc};

		# Clean the input data, populate some fields from other fields (e.g. split quantity found in product name)

		clean_fields($imported_product_ref);

		# image paths can be passed in fields image_front / nutrition / ingredients / other
		# several values can be passed in others

		foreach my $imagefield ("front", "ingredients", "nutrition", "other") {
			my $k = 0;
			if (defined $imported_product_ref->{"image_" . $imagefield}) {
				foreach my $file (split(/,/, $imported_product_ref->{"image_" . $imagefield})) {
					$file =~ s/^\s+//;
					$file =~ s/\s+$//;

					defined $images_ref->{$code} or $images_ref->{$code} = {};
					if ($imagefield ne "other") {
						$images_ref->{$code}{$imagefield} = $file;
					}
					else {
						$k++;
						$images_ref->{$code}{$imagefield . "_$k"} = $file;

						# No front image?
						if (not (defined $images_ref->{$code}{front})) {
							$images_ref->{$code}{front} = $file;
						}

						if (    ((defined $images_ref->{$code}{front}) and ($images_ref->{$code}{front} eq $images_ref->{$code}{$imagefield . "_$k"}))
							or  ((defined $images_ref->{$code}{ingredients}) and ($images_ref->{$code}{ingredients} eq $images_ref->{$code}{$imagefield . "_$k"}))
							or  ((defined $images_ref->{$code}{nutrition}) and ($images_ref->{$code}{nutrition} eq $images_ref->{$code}{$imagefield . "_$k"})) ) {
							# File already selected
							delete $images_ref->{$code}{$imagefield . "_$k"};
						}
					}
				}
			}
		}

		if ($args_ref->{skip_products_without_images}) {

			print STDERR "PRODUCT LINE NUMBER $i - CODE $code\n";

			if (not defined $images_ref->{$code}) {
				print STDERR "MISSING IMAGES ALL - PRODUCT CODE $code\n";
			}
			if (not defined $images_ref->{$code}{front}) {
				print STDERR "MISSING IMAGES FRONT - PRODUCT CODE $code\n";
			}
			if (not defined $images_ref->{$code}{ingredients}) {
				print STDERR "MISSING IMAGES INGREDIENTS - PRODUCT CODE $code\n";
			}
			if (not defined $images_ref->{$code}{nutrition}) {
				print STDERR "MISSING IMAGES NUTRITION - PRODUCT CODE $code\n";
			}

			if ((not defined $images_ref->{$code}) or (not defined $images_ref->{$code}{front})
				or ((not defined $images_ref->{$code}{ingredients}))) {
				print STDERR "MISSING IMAGES SOME - PRODUCT CODE $code\n";
				$skip_no_images++;
				next;
			}
		}
		
		# If we are importing on the public platform, check if the product exists on other servers
		# (e.g. Open Beauty Facts, Open Products Facts)
		
		my $product_ref;
		
		if ((defined $options{other_servers})
			and not ((defined $server_options{private_products}) and ($server_options{private_products}))) {
			foreach my $server (sort keys %{$options{other_servers}}) {
				next if ($server eq $options{current_server});
								
				$product_ref = product_exists_on_other_server($server, $product_id);
				if ($product_ref) {
					# Indicate to store_product() that the product is on another server
					$product_ref->{server} = $server;
					# Indicate to Images.pm functions that the product is on another server
					$product_id = $server . ":" . $product_id;
					$log->debug("product exists on another server", { code => $code, server => $server, product_id => $product_id }) if $log->is_debug();
					last;
				}
			}
		}

		if (not $product_ref) {
			$product_ref = product_exists($product_id); # returns 0 if not
		}

		my $product_comment = $args_ref->{comment};
		if ((defined $imported_product_ref->{comment}) and ($imported_product_ref->{comment} ne "")) {
			$product_comment .= " - " . $imported_product_ref->{comment};
		}

		if (not $product_ref) {
			$log->debug("product does not exist yet", { code => $code, product_id => $product_id }) if $log->is_debug();

			if ($args_ref->{skip_not_existing_products}) {
				$log->debug("skip not existing product", { code => $code, product_id => $product_id }) if $log->is_debug();
				$skip_not_existing++;
				next;
			}

			$new++;
			if (1 and (not $product_ref)) {
				$log->debug("creating not existing product", { code => $code, product_id => $product_id }) if $log->is_debug();

				$stats{products_created}{$code} = 1;

				$product_ref = init_product($args_ref->{user_id}, $args_ref->{org_id}, $code, undef);
				$product_ref->{interface_version_created} = "import_csv_file - version 2019/09/17";

				$product_ref->{lc} = $imported_product_ref->{lc};
				$product_ref->{lang} = $imported_product_ref->{lc};

				delete $product_ref->{countries};
				delete $product_ref->{countries_tags};
				delete $product_ref->{countries_hierarchy};
				if (not $args_ref->{test}) {
					# store_product($product_ref, "Creating product - " . $product_comment );
				}
			}
		}
		else {
			$log->debug("product already exists", { code => $code, product_id => $product_id }) if $log->is_debug();
			$existing++;
			$stats{products_already_existing}{$code} = 1;
		}

		# First load the global params, then apply the product params on top
		my %params = %global_values;

		# Create or update fields

		my %param_langs = ();

		foreach my $field (keys %{$imported_product_ref}) {
			if (($field =~ /^(.*)_(\w\w)$/) and (defined $language_fields{$1})) {
				$param_langs{$2} = 1;
			}
		}

		my @param_sorted_langs = sort keys %param_langs;

		my @param_fields = ();

		foreach my $field ('owner', 'lc', 'lang', 'product_name', 'generic_name',
			@ProductOpener::Config::product_fields, @ProductOpener::Config::product_other_fields,
			'obsolete', 'obsolete_since_date',
			'no_nutrition_data', 'nutrition_data_per', 'nutrition_data_prepared_per', 'serving_size', 'allergens', 'traces', 'ingredients_text', 'data_sources', 'imports') {

			if (defined $language_fields{$field}) {
				foreach my $display_lc (@param_sorted_langs) {
					push @param_fields, $field . "_" . $display_lc;
				}
			}
			else {
				push @param_fields, $field;
			}
		}

		# Record fields that are set by the owner, when the owner is a producer org
		# (and not an app, a database or label org)
		if ((defined $Owner_id) and ($Owner_id =~ /^org-/)
			and ($Owner_id !~ /^org-app-/)
			and ($Owner_id !~ /^org-database-/)
			and ($Owner_id !~ /^org-label-/) ) {
			defined $product_ref->{owner_fields} or $product_ref->{owner_fields} = {};
			$product_ref->{owner} = $Owner_id;
			$product_ref->{owners_tags} = $product_ref->{owner};
		}

		# We can have source specific fields of the form : sources_fields:org-database-usda:fdc_category
		# Transfer them directly
		foreach my $field (sort keys %{$imported_product_ref}) {
			if ($field =~ /^sources_fields:([a-z0-9-]+):/) {
				my $source_id = $1;
				my $source_field = $';
				defined $product_ref->{sources_fields} or $product_ref->{sources_fields} = {};
				defined $product_ref->{sources_fields}{$source_id} or $product_ref->{sources_fields}{$source_id} = {};
				if ($imported_product_ref->{$field} ne $product_ref->{sources_fields}{$source_id}{$source_field}) {
					$product_ref->{sources_fields}{$source_id}{$source_field} = $imported_product_ref->{$field};
					$modified++;
				}
			}
		}

		# Go through all the possible fields that can be imported
		foreach my $field (@param_fields) {

			# fields suffixed with _if_not_existing are loaded only if the product does not have an existing value

			if (not ((defined $product_ref->{$field}) and ($product_ref->{$field} !~ /^\s*$/))
				and ((defined $imported_product_ref->{$field . "_if_not_existing"}) and ($imported_product_ref->{$field . "_if_not_existing"} !~ /^\s*$/))) {
				print STDERR "no existing value for $field, using value from ${field}_if_not_existing: " . $imported_product_ref->{$field . "_if_not_existing"} . "\n";
				$imported_product_ref->{$field} = $imported_product_ref->{$field . "_if_not_existing"};
			}

			if (defined $tags_fields{$field}) {
				foreach my $subfield (sort keys %{$imported_product_ref}) {
					
					next if ((not defined $imported_product_ref->{$subfield}) or ($imported_product_ref->{$subfield} eq "")); 
					
					# For labels and categories, we can have columns like labels:Bio with values like 1, Y, Yes
					# concatenate them to the labels field
					
					if ($subfield =~ /^$field:/) {
						my $tag_name = $';
						my $tag_to_add;
						
						$log->debug("specific field", { field => $field, tag_name => $tag_name, value => $imported_product_ref->{$subfield} } ) if $log->is_debug();
						
						if ($imported_product_ref->{$subfield} =~ /^\s*(1|y|yes|o|oui)\s*$/i) {
							$tag_to_add = $tag_name;
						}
						
						# If we have a value like 0, N, No and an opposite entry exists in the taxonomy
						# then add the negative entry
						elsif ($imported_product_ref->{$subfield} =~ /^\s*(0|n|no|not|non)\s*$/i) {
							
							my $tagid = canonicalize_taxonomy_tag($imported_product_ref->{lc}, $field, $tag_name);
							
							$log->debug("opposite value for specific field", { field => $field, value => $imported_product_ref->{$subfield},
								tag_name => $tag_name, tagid => $tagid, opposite_tagid => get_property($field, $tagid, "opposite:en") } ) if $log->is_debug();
							
							if (exists_taxonomy_tag($field, $tagid)) {
								my $opposite_tagid = get_property($field, $tagid, "opposite:en");
								if (defined $opposite_tagid) {
									$tag_to_add = $opposite_tagid;
								}
							}
						}
						
						if (defined $tag_to_add) {
							if (defined $imported_product_ref->{$field}) {
								$imported_product_ref->{$field} .= "," . $tag_to_add;
							}
							else {
								$imported_product_ref->{$field} = $tag_to_add;
							}
						}
					}
					
					# [tags type]_if_match_in_taxonomy : contains candidate values that we import
					# only if we have a matching taxonomy entry
					# there may be multiple columns for the same field: [tags type]_if_match_in_taxonomy.2 etc.
					
					if (($subfield =~ /^${field}_if_match_in_taxonomy/)
						and (exists_taxonomy_tag($field,
							canonicalize_taxonomy_tag($imported_product_ref->{lc}, $field, $imported_product_ref->{$subfield})))) {
						if (defined $imported_product_ref->{$field}) {
							$imported_product_ref->{$field} .= "," . $imported_product_ref->{$subfield};
						}
						else {
							$imported_product_ref->{$field}
								= $imported_product_ref->{$subfield};
						}
					}
				}
			}

			if ((defined $imported_product_ref->{$field}) and ($imported_product_ref->{$field} !~ /^\s*$/)) {

				$log->debug("defined and non empty value for field", { field => $field, value => $imported_product_ref->{$field} }) if $log->is_debug();

				if (($field =~ /product_name/) or ($field eq "brands")) {
					$stats{products_with_info}{$code} = 1;
				}

				if ($field =~ /^ingredients/) {
					$stats{products_with_ingredients}{$code} = 1;
				}

				if (    ( defined $Owner_id )
					and ( $Owner_id =~ /^org-/ )
					and ( $field ne "imports" )    # "imports" contains the timestamp of each import
					)
				{

					# Don't set owner_fields for apps, labels and databases, only for producers
					if (($Owner_id !~ /^org-app-/)
						and ($Owner_id !~ /^org-database-/)
						and ($Owner_id !~ /^org-label-/)) {
						$product_ref->{owner_fields}{$field} = $time;
					}

					# Save the imported value, before it is cleaned etc. so that we can avoid reimporting data that has been manually changed afterwards
					if ((not defined $product_ref->{$field . "_imported"}) or ($product_ref->{$field . "_imported"} ne $imported_product_ref->{$field})) {
						$log->debug("setting _imported field value", { field => $field, imported_value => $imported_product_ref->{$field}, current_value => $product_ref->{$field} }) if $log->is_debug();
						$product_ref->{$field . "_imported"} = $imported_product_ref->{$field};
						$modified++;
					}

					# Skip data that we have already imported before (even if it has been changed)
					elsif ((defined $product_ref->{$field . "_imported"}) and ($product_ref->{$field . "_imported"} eq $imported_product_ref->{$field})) {
						$log->debug("skipping field that was already imported", { field => $field, imported_value => $imported_product_ref->{$field}, current_value => $product_ref->{$field} }) if $log->is_debug();
						next;
					}
				}

				# for tag fields, only add entries to it, do not remove other entries

				if (defined $tags_fields{$field}) {

					my $current_field = $product_ref->{$field};

					# we may want to replace brands completely at some point
					# disabling for now

					#if ($field eq 'brands') {
					#	$product_ref->{$field} = "";
					#	delete $product_ref->{$field . "_tags"};
					#}

					# If we are on the producers platform, remove existing values for brands
					if (($server_options{producers_platform}) and ($field eq "brands")) {
						$product_ref->{$field} = "";
						delete $product_ref->{$field . "_tags"};
					}

					my %existing = ();
						if (defined $product_ref->{$field . "_tags"}) {
						foreach my $tagid (@{$product_ref->{$field . "_tags"}}) {
							$existing{$tagid} = 1;
						}
					}

					foreach my $tag (split(/,/, $imported_product_ref->{$field})) {

						my $tagid;

						next if $tag =~ /^(\s|,|-|\%|;|_|°)*$/;
						next if $tag =~ /^\s*((n(\/|\.)?a(\.)?)|(not applicable)|unknown|inconnu|inconnue|non renseigné|non applicable|nr|n\/r)\s*$/i;

						$tag =~ s/^\s+//;
						$tag =~ s/\s+$//;

						if ($field eq 'emb_codes') {
							$tag = normalize_packager_codes($tag);
						}

						if (defined $taxonomy_fields{$field}) {
							$tagid = get_taxonomyid($imported_product_ref->{lc}, canonicalize_taxonomy_tag($imported_product_ref->{lc}, $field, $tag));
						}
						else {
							$tagid = get_string_id_for_lang("no_language", $tag);
						}

						if (not exists $existing{$tagid}) {
							$log->debug("adding tagid to field", { field => $field, tagid => $tagid }) if $log->is_debug();
							$product_ref->{$field} .= ", $tag";
							$existing{$tagid} = 1;
						}
						else {
							#print "- $tagid already in $field\n";
							# update the case (e.g. for brands)
							if ($field eq "brands") {
								my $regexp = $tag;
								$regexp =~ s/( |-)/\( \|-\)/g;
								$product_ref->{$field} =~ s/\b$tagid\b/$tag/i;
								$product_ref->{$field} =~ s/\b$regexp\b/$tag/i;
							}
						}
					}

					if ((defined $product_ref->{$field}) and ($product_ref->{$field} =~ /^, /)) {
						$product_ref->{$field} = $';
					}

					my $tag_lc = $product_ref->{lc};

					# If an import_lc was passed as a parameter, assume the imported values are in the import_lc language
					if (defined $args_ref->{import_lc}) {
						$tag_lc = $args_ref->{import_lc};
					}

					if ($field eq 'emb_codes') {
						# French emb codes
						$product_ref->{emb_codes_orig} = $product_ref->{emb_codes};
						$product_ref->{emb_codes} = normalize_packager_codes($product_ref->{emb_codes});
					}
					if (not defined $current_field) {
						$log->debug("added value to field", { field => $field, value => $product_ref->{$field} }) if $log->is_debug();
						compute_field_tags($product_ref, $tag_lc, $field);
						push @modified_fields, $field;
						$modified++;
						$stats{products_info_added}{$code} = 1;
					}
					elsif ($current_field ne $product_ref->{$field}) {
						$log->debug("changed value for field", { field => $field, value => $product_ref->{$field}, old_value => $current_field }) if $log->is_debug();
						compute_field_tags($product_ref, $tag_lc, $field);
						push @modified_fields, $field;
						$modified++;
						$stats{products_info_changed}{$code} = 1;
					}
					elsif ( $field eq "brands" ) {    # we removed it earlier
						compute_field_tags( $product_ref, $tag_lc, $field );
					}
				}
				else {
					# non-tag field
					my $new_field_value = $imported_product_ref->{$field};

					next if not defined $new_field_value;

					$new_field_value =~ s/\s+$//;
					$new_field_value =~ s/^\s+//;

					next if $new_field_value eq "";

					if (($field eq 'quantity') or ($field eq 'serving_size')) {

							# openfood.ch now seems to round values to the 1st decimal, e.g. 28.0 g
							$new_field_value =~ s/\.0 / /;

							# 6x90g
							$new_field_value =~ s/(\d)(\s*)x(\s*)(\d)/$1 x $4/i;

							$new_field_value =~ s/(\d)( )?(g|gramme|grammes|gr)(\.)?/$1 g/i;
							$new_field_value =~ s/(\d)( )?(ml|millilitres)(\.)?/$1 ml/i;
							$new_field_value =~ s/litre|litres|liter|liters/l/i;
							$new_field_value =~ s/kilogramme|kilogrammes|kgs/kg/i;
					}

					$new_field_value =~ s/\s+$//g;
					$new_field_value =~ s/^\s+//g;

					next if $new_field_value eq "";

					# existing value?
					if ((defined $product_ref->{$field}) and ($product_ref->{$field} !~ /^\s*$/)) {

						if ($args_ref->{skip_existing_values}) {
							$log->debug("skip existing value for field", { field => $field, value => $product_ref->{$field} }) if $log->is_debug();
							next;
						}

						my $current_value = $product_ref->{$field};
						$current_value =~ s/\s+$//g;
						$current_value =~ s/^\s+//g;

						# normalize current value
						if (($field eq 'quantity') or ($field eq 'serving_size')) {

							$current_value =~ s/(\d)( )?(g|gramme|grammes|gr)(\.)?/$1 g/i;
							$current_value =~ s/(\d)( )?(ml|millilitres)(\.)?/$1 ml/i;
							$current_value =~ s/litre|litres|liter|liters/l/i;
							$current_value =~ s/kilogramme|kilogrammes|kgs/kg/i;
						}

						if (lc($current_value) ne lc($new_field_value)) {
						# if ($current_value ne $new_field_value) {
							$log->debug("differing value for field", { field => $field, existing_value => $product_ref->{$field}, new_value => $new_field_value }) if $log->is_debug();
							$differing++;
							$differing_fields{$field}++;

							$product_ref->{$field} = $new_field_value;

							# do not count the import id as a change
							if ($field ne "imports") {
								push @modified_fields, $field;
								$modified++;
								$stats{products_info_changed}{$code} = 1;
							}
						}
						elsif (($field eq 'quantity') and ($product_ref->{$field} ne $new_field_value)) {
							# normalize quantity
							$log->debug("normalizing quantity", { field => $field, existing_value => $product_ref->{$field}, new_value => $new_field_value }) if $log->is_debug();
							$product_ref->{$field} = $new_field_value;
							push @modified_fields, $field;
							$modified++;

							$stats{products_info_changed}{$code} = 1;
						}
					}
					else {
						$log->debug("setting previously unexisting value for field", { field => $field, new_value => $new_field_value }) if $log->is_debug();
						$product_ref->{$field} = $new_field_value;

						# do not count the import id as a change
						if ($field ne "imports") {
							push @modified_fields, $field;
							$modified++;
							$stats{products_info_added}{$code} = 1;
						}
					}
				}
			}
		}

		# nutrients

		my $seen_salt = 0;

		my $nutrition_data_per = $imported_product_ref->{nutrition_data_per};
		my $nutrition_data_prepared_per = $imported_product_ref->{nutrition_data_prepared_per};

		foreach my $nutriment (@sorted_nutriments) {

			next if $nutriment =~ /^\#/;

			my $nid = $nutriment;
			$nid =~ s/^(-|!)+//g;
			$nid =~ s/-$//g;

			# don't set sodium if we have salt
			next if (($nid eq 'sodium') and ($seen_salt));

			# next if $nid =~ /^nutrition-score/;   #TODO

			# for prepared product
			my $nidp = $nid . "_prepared";

			# Save current values so that we can see if they have changed
			my %original_values = (
				$nid . "_modifier" => $product_ref->{nutriments}{$nid . "_modifier"},
				$nidp . "_modifier" => $product_ref->{nutriments}{$nidp . "_modifier"},
				$nid . "_value" => $product_ref->{nutriments}{$nid . "_value"},
				$nidp . "_value" => $product_ref->{nutriments}{$nidp . "_value"},
				$nid . "_unit" => $product_ref->{nutriments}{$nid . "_unit"},
				$nidp . "_unit" => $product_ref->{nutriments}{$nidp . "_unit"},
			);

			# We may have nid_value, nid_100g_value or nid_serving_value. In the last 2 cases,
			# we need to set $nutrition_data_per to 100g or serving
			my %values = ();

			my $unit;

			foreach my $type ("", "_prepared") {

				foreach my $per ("", "_100g", "_serving") {

					next if (defined $values{$type});

					# Skip serving values if we have 100g values
					if ((defined $imported_product_ref->{"nutrition_data" . $type . "_per"})
						and ($imported_product_ref->{"nutrition_data" . $type . "_per"} eq "100g")
						and ($per eq "_serving")) {
						next;
					}

					if ((defined $imported_product_ref->{$nid . $type . $per . "_value"})
						and ($imported_product_ref->{$nid . $type . $per . "_value"} ne "")) {
						$values{$type} = $imported_product_ref->{$nid . $type . $per . "_value"};
					}

					if ((defined $imported_product_ref->{$nid . $type . $per . "_unit"})
						and ($imported_product_ref->{$nid . $type . $per . "_unit"} ne "")) {
						$unit = $imported_product_ref->{$nid . $type . $per . "_unit"};
					}

					# Energy can be: 852KJ/ 203Kcal
					# calcium_100g_value_unit = 50 mg
					# 10g
					if (not defined $values{$type}) {
						if (defined $imported_product_ref->{$nid . $type . $per . "_value_unit"}) {

							# Assign energy-kj and energy-kcal values from energy field

							if (($nid eq "energy") and ($imported_product_ref->{$nid . $type . $per . "_value_unit"} =~ /\b([0-9]+)(\s*)kJ/i)) {
								if (not defined $imported_product_ref->{$nid . "-j" . $type . $per . "_value_unit"}) {
									$imported_product_ref->{$nid . "-kj" . $type . $per . "_value_unit"} = $1 . " kJ";
								}
							}
							if (($nid eq "energy") and ($imported_product_ref->{$nid . $type . $per . "_value_unit"} =~ /\b([0-9]+)(\s*)kcal/i)) {
								if (not defined $imported_product_ref->{$nid . "-kcal" . $type . $per . "_value_unit"}) {
									$imported_product_ref->{$nid . "-kcal" . $type . $per . "_value_unit"} = $1 . " kcal";
								}
							}

							if ($imported_product_ref->{$nid . $type . $per . "_value_unit"} =~ /^(~?<?>?=?\s?([0-9]*(\.|,))?[0-9]+)(\s*)([a-zµ%]+)$/i) {
								$values{$type} = $1;
								$unit = $5;
							}
							# We might have only a number even if the field is set to value_unit
							# in that case, use the default unit
							elsif ($imported_product_ref->{$nid . $type . $per . "_value_unit"} =~ /^(([0-9]*(\.|,))?[0-9]+)(\s*)$/i) {
								$values{$type} = $1;
							}
						}
					}

					# calcium_100g_value_in_mcg

					if (not defined $values{$type}) {
						foreach my $u ('kj', 'kcal', 'kg', 'g', 'mg', 'mcg', 'l', 'dl', 'cl', 'ml', 'iu') {
							my $value_in_u = $imported_product_ref->{$nid . $type . $per . "_value" . "_in_" . $u};
							if ((defined $value_in_u) and ($value_in_u ne "")) {
								$values{$type} = $value_in_u;
								$unit = $u;
							}
						}
					}

					if ((defined $values{$type}) and ($per ne "")) {
						$imported_product_ref->{"nutrition_data" . $type . "_per"} = $per;
						$imported_product_ref->{"nutrition_data" . $type . "_per"} =~ s/^_//;
					}
				}

				if ($nid eq 'alcohol') {
					$unit = '% vol';
				}

				# Standardize units
				if (defined $unit) {
					if ($unit eq "kj") {
						$unit = "kJ";
					}
					elsif ($unit eq "mcg") {
						$unit = "µg";
					}
					elsif ($unit eq "iu") {
						$unit = "IU";
					}
				}

				my $modifier = undef;

				(defined $values{$type}) and normalize_nutriment_value_and_modifier(\$values{$type}, \$modifier);

				if ((defined $values{$type}) and ($values{$type} ne '')) {

					if ($nid eq 'salt') {
						$seen_salt = 1;
					}

					$log->debug("nutrient with defined and non empty value", { nid => $nid, type => $type, value => $values{$type}, unit => $unit }) if $log->is_debug();
					$stats{products_with_nutrition}{$code} = 1;

					assign_nid_modifier_value_and_unit($product_ref, $nid . $type, $modifier, $values{$type}, $unit);

					if ((defined $Owner_id) and ($Owner_id =~ /^org-/)
						and ($Owner_id !~ /^org-app-/)
						and ($Owner_id !~ /^org-database-/)
						and ($Owner_id !~ /^org-label-/)) {
						$product_ref->{owner_fields}{$nid} = $time;
					}
				}
			}

			# See which fields have changed

			foreach my $field (sort keys %original_values) {
				if ((defined $product_ref->{nutriments}{$field}) and ($product_ref->{nutriments}{$field} ne "")
					and (defined $original_values{$field}) and ($original_values{$field} ne "")
					and ($product_ref->{nutriments}{$field} ne $original_values{$field})) {
					$log->debug("differing nutrient value", { field => $field, old => $original_values{$field}, new => $product_ref->{nutriments}{$field} }) if $log->is_debug();
					$stats{products_nutrition_updated}{$code} = 1;
					$stats{products_nutrition_changed}{$code} = 1;
					$modified++;
					$nutrients_edited{$code}++;
					push @modified_fields, "nutrients.$field";
				}
				elsif (
						( defined $product_ref->{nutriments}{$field} )
					and ( $product_ref->{nutriments}{$field} ne "" )
					and (  ( not defined $original_values{$field} )
						or ( $original_values{$field} eq '' ) )
					)
				{
					$log->debug("new nutrient value", { field => $field,  new => $product_ref->{nutriments}{$field} }) if $log->is_debug();
					$stats{products_nutrition_updated}{$code} = 1;
					$stats{products_nutrition_added}{$code} = 1;
					$modified++;
					$nutrients_edited{$code}++;
					push @modified_fields, "nutrients.$field";
				}
				elsif ((not defined $product_ref->{nutriments}{$field}) and (defined $original_values{$field}) and ($original_values{$field} ne '')) {
					$log->debug("deleted nutrient value", { field => $field, old => $original_values{$field} }) if $log->is_debug();
					$stats{products_nutrition_updated}{$code} = 1;
					$modified++;
					$nutrients_edited{$code}++;
					push @modified_fields, "nutrients.$field";
				}
			}
		}

		# Set nutrition_data_per to 100g if it was not provided and we have nutrition data in the csv file
		if (defined $stats{products_with_nutrition}{$code}) {
			if (not defined $imported_product_ref->{nutrition_data_per}) {
				if (defined $nutrition_data_per) {
					$imported_product_ref->{nutrition_data_per} = $nutrition_data_per;
				}
				else {
					$imported_product_ref->{nutrition_data_per} = "100g";
				}
			}

			if ((not defined $product_ref->{nutrition_data_per}) or ($product_ref->{nutrition_data_per} ne $imported_product_ref->{nutrition_data_per})) {
				$product_ref->{nutrition_data_per} = $imported_product_ref->{nutrition_data_per};
				$stats{products_nutrition_data_per_updated}{$code} = 1;
				$modified++;
			}

			if (not defined $imported_product_ref->{nutrition_data_prepared_per}) {
				if (defined $nutrition_data_prepared_per) {
					$imported_product_ref->{nutrition_data_prepared_per} = $nutrition_data_prepared_per;
				}
				else {
					$imported_product_ref->{nutrition_data_prepared_per} = "100g";
				}
			}

			if ((not defined $product_ref->{nutrition_data_prepared_per}) or ($product_ref->{nutrition_data_prepared_per} ne $imported_product_ref->{nutrition_data_prepared_per})) {
				$product_ref->{nutrition_data_prepared_per} = $imported_product_ref->{nutrition_data_prepared_per};
				$stats{products_nutrition_data_per_updated}{$code} = 1;
				$modified++;
			}
		}

		if ((defined $stats{products_info_added}{$code}) or (defined $stats{products_info_changed}{$code})) {
			$stats{products_info_updated}{$code} = 1;
		}
		else {
			$stats{products_info_not_updated}{$code} = 1;
		}

		if ((defined $stats{products_nutrition_added}{$code}) or (defined $stats{products_nutrition_changed}{$code})) {
			$stats{products_nutrition_updated}{$code} = 1;
		}
		else {
			$stats{products_nutrition_not_updated}{$code} = 1;
		}

		if ((defined $stats{products_info_updated}{$code}) or (defined $stats{products_nutrition_updated}{$code}) or (defined $stats{products_nutrition_data_per_updated}{$code})) {
			$stats{products_data_updated}{$code} = 1;
		}
		else {
			$stats{products_data_not_updated}{$code} = 1;
		}

		if (not defined $stats{products_with_info}{$code}) {
			$stats{products_without_info}{$code} = 1;
		}
		if (not defined $stats{products_with_ingredients}{$code}) {
			$stats{products_without_ingredients}{$code} = 1;
		}
		if (not defined $stats{products_with_nutrition}{$code}) {
			$stats{products_without_nutrition}{$code} = 1;
		}

		if ((defined $stats{products_with_info}{$code}) or (defined $stats{products_with_nutrition}{$code})) {
			$stats{products_with_data}{$code} = 1;
		}
		else {
			$stats{products_without_data}{$code} = 1;
		}

		if ($modified and not $stats{products_data_updated}{$code}) {
			print STDERR "Error: modified but not products_data_updated\n";
		}

		if ((not $modified) and $stats{products_data_updated}{$code}) {
			print STDERR "Error: not modified but products_data_updated\n";
		}

		if ($code ne $product_ref->{code}) {
			$log->error("Error - code not the same as product_ref->{code}", { i => $i, code => $code, product_ref_code=>$product_ref->{code}, imported_product_ref => $imported_product_ref }) if $log->is_error();
			next;
		}

		# Skip further processing if we have not modified any of the fields

		$log->debug("number of modifications", { code => $code, modified => $modified }) if $log->is_debug();
		if ($modified == 0) {
			$log->debug("skipping - no modifications", { code => $code }) if $log->is_debug();
			$stats{products_data_not_updated}{$code} = 1;

		}
		elsif (($args_ref->{skip_products_without_info}) and ($stats{products_without_info}{$code})) {
			$log->debug("skipping - product without info and --skip_products_without_info", { code => $code }) if $log->is_debug();
		}
		else {
			$log->debug("updating product", { code => $code, modified => $modified }) if $log->is_debug();
			$stats{products_data_updated}{$code} = 1;

			# Process the fields

			# Food category rules for sweeetened/sugared beverages
			# French PNNS groups from categories

			if ($server_domain =~ /openfoodfacts/) {
				ProductOpener::Food::special_process_product($product_ref);
			}

			if ((defined $product_ref->{nutriments}{"carbon-footprint"}) and ($product_ref->{nutriments}{"carbon-footprint"} ne '')
				and not has_tag($product_ref, "labels", "en:carbon-footprint")) {
				push @{$product_ref->{"labels_hierarchy" }}, "en:carbon-footprint";
				push @{$product_ref->{"labels_tags" }}, "en:carbon-footprint";
			}

			if ((defined $product_ref->{nutriments}{"glycemic-index"}) and ($product_ref->{nutriments}{"glycemic-index"} ne '')
				and not has_tag($product_ref, "labels", "en:glycemic-index")) {
				push @{$product_ref->{"labels_hierarchy" }}, "en:glycemic-index";
				push @{$product_ref->{"labels_tags" }}, "en:glycemic-index";
			}

			# For fields that can have different values in different languages, copy the main language value to the non suffixed field

			foreach my $field (keys %language_fields) {
				if ($field !~ /_image/) {
					if (defined $product_ref->{$field . "_" . $product_ref->{lc}}) {
						$product_ref->{$field} = $product_ref->{$field . "_" . $product_ref->{lc}};
					}
				}
			}

			compute_languages($product_ref); # need languages for allergens detection and cleaning ingredients

			# Ingredients classes
			extract_ingredients_from_text($product_ref);
			extract_ingredients_classes_from_text($product_ref);
			detect_allergens_from_text($product_ref);

			if (not $args_ref->{no_source}) {

				if (not defined $product_ref->{sources}) {
					$product_ref->{sources} = [];
				}

				my $product_source_url = $args_ref->{source_url};
				if ((defined $imported_product_ref->{source_url}) and ($imported_product_ref->{source_url} ne "")) {
					$product_source_url = $imported_product_ref->{source_url};
				}

				my $source_ref = {
					id => $args_ref->{source_id},
					name => $args_ref->{source_name},
					url => $product_source_url,
					manufacturer => $args_ref->{manufacturer},
					import_t => time(),
					fields => \@modified_fields,
					images => \@images_ids,
				};

				defined $args_ref->{source_licence} and $source_ref->{source_licence} = $args_ref->{source_licence};
				defined $args_ref->{source_licence_url} and $source_ref->{source_licence_url} = $args_ref->{source_licence_url};

				push @{$product_ref->{sources}}, $source_ref;
			}

			if (not $args_ref->{test}) {

				fix_salt_equivalent($product_ref);

				compute_serving_size_data($product_ref);

				compute_nutrition_score($product_ref);

				compute_nova_group($product_ref);

				compute_nutrient_levels($product_ref);

				compute_unknown_nutrients($product_ref);

				ProductOpener::DataQuality::check_quality($product_ref);

				$log->debug("storing product", { code => $code, product_id => $product_id }) if $log->is_debug();

				store_product($product_ref, "Editing product (import) - " . $product_comment );

				push @edited, $code;
				$edited{$code}++;

				$stats{products_updated}{$code} = 1;

				$j++;
			}
		}

		# Images need to be updated after the product is saved (and possibly created)

		# Images can be specified as local paths to image files
		# e.g. from the producers platform

		foreach my $field (sort keys %{$imported_product_ref}) {

			next if $field !~ /^image_((front|ingredients|nutrition|other)(_\w\w)?(_\d+)?)_file/;

			my $imagefield = $1;

			(defined $images_ref->{$code}) or $images_ref->{$code} = {};
			$images_ref->{$code}{$imagefield} = $imported_product_ref->{$field};
		}

		# Images can be specified as urls that we need to download

		foreach my $field (sort keys %{$imported_product_ref}) {

			# image field can have forms like:
			# image_front_url_fr
			# image_front_fr_url
			# image_other_url
			# image_other_url.2	: a second "other" photo

			next if $field !~ /^image_((front|ingredients|nutrition|other)(_[a-z]{2})?)_url/;

			my $imagefield = $1 . $'; # e.g. image_front_url_fr -> front_fr

			$log->debug("image file", { field => $field, imagefield => $imagefield, field_value => $imported_product_ref->{$field} }) if $log->is_debug();

			if ((defined $imported_product_ref->{$field}) and ($imported_product_ref->{$field} =~ /^http/)) {

				# Create a local filename from the url
				my $filename = $imported_product_ref->{$field};
				$filename =~ s/.*\///;
				$filename =~ s/[^A-Za-z0-9-_\.]/_/g;

				# If the filename does not include the product code, prefix it
				if ($filename !~ /$code/) {

					$filename = $code . "_" . $filename;
				}

				my $images_download_dir = $args_ref->{images_download_dir};

				if ((defined $images_download_dir) and ($images_download_dir ne '')) {
					if (not -d $images_download_dir) {
						$log->debug("Creating images_download_dir", { images_download_dir => $images_download_dir}) if $log->is_debug();
						mkdir($images_download_dir, 0755) or $log->warn("Could not create images_download_dir", { images_download_dir => $images_download_dir, error=> $!}) if $log->is_warn();
					}

					my $file = $images_download_dir . "/" . $filename;

					# Check if the image exists
					if (-e $file) {

						$log->debug("we already have downloaded image file", { file => $file }) if $log->is_debug();

						# Is the image readable?
						my $magick = Image::Magick->new();
						my $x = $magick->Read($file);
						if ("$x") {
							$log->warn("cannot read image file", { error => $x, file => $file }) if $log->is_warn();
							unlink($file);
						}
					}

					# Download the image
					if (! -e $file) {

						# https://secure.equadis.com/Equadis/MultimediaFileViewer?thumb=true&idFile=601231&file=10210/8076800105735.JPG
						# -> remove thumb=true to get the full image

						my $image_url = $imported_product_ref->{$field};
						$image_url =~ s/thumb=true&//;

						$log->debug("download image file", { file => $file, image_url => $image_url }) if $log->is_debug();

						require LWP::UserAgent;

						my $ua = LWP::UserAgent->new(timeout => 10);

						my $response = $ua->get($image_url);

						if ($response->is_success) {
							$log->debug("downloaded image file", { file => $file }) if $log->is_debug();
							open (my $out, ">", $file);
							print $out $response->decoded_content;
							close($out);

							# Assign the download image to the field
							(defined $images_ref->{$code}) or $images_ref->{$code} = {};
							$images_ref->{$code}{$imagefield} = $file;
						}
						else {
							$log->debug("could not download image file", { file => $file, response => $response }) if $log->is_debug();
						}
					}
				}
				else {
					$log->warn("no image download dir specified", { }) if $log->is_warn();
				}
			}
		}


		# Upload images

		if (defined $images_ref->{$code}) {

			$stats{products_with_images}{$code} = 1;

			if ((not $args_ref->{test})
				and (not ((defined $args_ref->{do_not_upload_images}) and ($args_ref->{do_not_upload_images})))) {

				$log->debug("uploading images for product", { code => $code }) if $log->is_debug();

				my $images_ref = $images_ref->{$code};

				# Keep track of the images we select so that we don't select multiple images for the same field
				my %selected_images = ();

				foreach my $imagefield (sort keys %{$images_ref}) {

					$log->debug("uploading image for product", { imagefield => $imagefield, code => $code }) if $log->is_debug();

					my $current_max_imgid = -1;

					if (defined $product_ref->{images}) {
						foreach my $imgid (keys %{$product_ref->{images}}) {
							if (($imgid =~ /^\d/) and ($imgid > $current_max_imgid)) {
								$current_max_imgid = $imgid;
							}
						}
					}

					# if the language is not specified, assign it to the language of the product

					my $imagefield_with_lc = $imagefield;

					# image_other_url.2 -> remove the number
					$imagefield_with_lc =~ s/(\.|_)(\d+)$//;

					if ($imagefield_with_lc !~ /_\w\w/) {
						$imagefield_with_lc .= "_" . $product_ref->{lc};
					}

					# upload the image
					my $file = $images_ref->{$imagefield};

					if (-e "$file") {
						$log->debug("found image file", { file => $file, imagefield => $imagefield, code => $code }) if $log->is_debug();

						# upload a photo
						my $imgid;
						my $debug;
						my $return_code = process_image_upload($product_id, "$file", $args_ref->{user_id}, undef, $product_comment, \$imgid, \$debug);
						$log->debug("process_image_upload", { file => $file, imagefield => $imagefield, code => $code, return_code => $return_code, imgid => $imgid, imagefield_with_lc => $imagefield_with_lc, debug => $debug }) if $log->is_debug();

						if (($imgid > 0) and ($imgid > $current_max_imgid)) {
							$stats{products_images_added}{$code} = 1;
						}

						my $x1 = $imported_product_ref->{"image_" . $imagefield . "_x1"} || -1;
						my $y1 = $imported_product_ref->{"image_" . $imagefield . "_y1"} || -1;
						my $x2 = $imported_product_ref->{"image_" . $imagefield . "_x2"} || -1;
						my $y2 = $imported_product_ref->{"image_" . $imagefield . "_y2"} || -1;
						my $coordinates_image_size = $imported_product_ref->{"image_" . $imagefield . "_coordinates_image_size"} || $crop_size;
						my $angle = $imported_product_ref->{"image_" . $imagefield . "_angle"} || 0;
						my $normalize = $imported_product_ref->{"image_" . $imagefield . "_normalize"} || "false";
						my $white_magic = $imported_product_ref->{"image_" . $imagefield . "_white_magic"} || "false";

						$log->debug("select and crop image?", { code => $code, imgid => $imgid, current_max_imgid => $current_max_imgid, imagefield_with_lc => $imagefield_with_lc, x1 => $x1, y1 => $y1, x2 => $x2, y2 => $y2, angle => $angle, normalize => $normalize, white_magic => $white_magic }) if $log->is_debug();

						# select the photo
						if (($imagefield_with_lc =~ /front|ingredients|nutrition/) and
							( (not ((defined $args_ref->{only_select_not_existing_images}) and ($args_ref->{only_select_not_existing_images})))
								or ((not defined $product_ref->{images}) or (not defined $product_ref->{images}{$imagefield_with_lc})) ) ) {

							if (($imgid > 0) and ($imgid > $current_max_imgid)) {

								$log->debug("assigning image imgid to imagefield_with_lc", { code => $code, current_max_imgid => $current_max_imgid, imgid => $imgid, imagefield_with_lc => $imagefield_with_lc, x1 => $x1, y1 => $y1, x2 => $x2, y2 => $y2, angle => $angle, normalize => $normalize, white_magic => $white_magic }) if $log->is_debug();
								$selected_images{$imagefield_with_lc} = 1;
								eval { process_image_crop($product_id, $imagefield_with_lc, $imgid, $angle, $normalize, $white_magic, $x1, $y1, $x2, $y2, $coordinates_image_size); };
								# $modified++;

							}
							else {
								$log->debug("returned imgid $imgid not greater than the previous max imgid: $current_max_imgid", { imgid => $imgid, current_max_imgid => $current_max_imgid }) if $log->is_debug();

								# overwrite already selected images
								# if the selected image is not the same
								# or if we have non null crop coordinates that differ
								if (($imgid > 0)
									and (exists $product_ref->{images})
									and (exists $product_ref->{images}{$imagefield_with_lc})
									and (($product_ref->{images}{$imagefield_with_lc}{imgid} != $imgid)
										or (($x1 > 1) and ($product_ref->{images}{$imagefield_with_lc}{x1} != $x1))
										or (($x2 > 1) and ($product_ref->{images}{$imagefield_with_lc}{x2} != $x2))
										or (($y1 > 1) and ($product_ref->{images}{$imagefield_with_lc}{y1} != $y1))
										or (($y2 > 1) and ($product_ref->{images}{$imagefield_with_lc}{y2} != $y2))
										or ($product_ref->{images}{$imagefield_with_lc}{angle} != $angle)
										)
									) {
									$log->debug("re-assigning image imgid to imagefield_with_lc", { code => $code, imgid => $imgid, imagefield_with_lc => $imagefield_with_lc, x1 => $x1, y1 => $y1, x2 => $x2, y2 => $y2, angle => $angle, normalize => $normalize, white_magic => $white_magic }) if $log->is_debug();
									$selected_images{$imagefield_with_lc} = 1;
									eval { process_image_crop($product_id, $imagefield_with_lc, $imgid, $angle, $normalize, $white_magic, $x1, $y1, $x2, $y2, $coordinates_image_size); };
									# $modified++;
								}

							}
						}
						# If the image type is "other" and we don't have a front image, assign it
						# This is in particular for producers that send us many images without specifying their type: assume the first one is the front
						elsif (($imgid > 0) and ($imagefield_with_lc =~ /^other/) and (not defined $product_ref->{images}{"front_" . $product_ref->{lc}}) and (not defined $selected_images{"front_" . $product_ref->{lc}})) {
							$log->debug("selecting front image as we don't have one", { imgid => $imgid, imagefield => $imagefield, front_imagefield => "front_" . $product_ref->{lc}, x1 => $x1, y1 => $y1, x2 => $x2, y2 => $y2, angle => $angle, normalize => $normalize, white_magic => $white_magic}) if $log->is_debug();
							# Keep track that we have selected an image, so that we don't select another one after,
							# as we don't reload the product_ref after calling process_image_crop()
							$selected_images{"front_" . $product_ref->{lc}} = 1;
							eval { process_image_crop($product_id, "front_" . $product_ref->{lc}, $imgid, $angle, $normalize, $white_magic, $x1, $y1, $x2, $y2, $coordinates_image_size); };
						}
					}
					else {
						$log->debug("did not find image file", { file => $file, imagefield => $imagefield, code => $code }) if $log->is_debug();
					}
				}
			}
		}
		else {
			$log->debug("no images for product", { code => $code }) if $log->is_debug();
			$stats{products_without_images}{$code} = 1;
		}

		undef $product_ref;
	}

	$log->debug("import done", { products => $i, new_products => $new, existing_products => $existing, differing_products => $differing, differing_fields => \%differing_fields }) if $log->is_debug();

	print STDERR "\n\nimport done\n\n";

	foreach my $field (sort keys %differing_fields) {
		print STDERR "field $field - $differing_fields{$field} differing values\n";
	}

	print STDERR "$i products\n";
	print STDERR "$new new products\n";
	print STDERR "$skip_not_existing skipped not existing products\n";
	print STDERR "$skip_no_images skipped no images products\n";
	print STDERR "$existing existing products\n";
	print STDERR "$differing differing values\n\n";

	print STDERR ((scalar keys %nutrients_edited) . " products with edited nutrients\n");
	print STDERR ((scalar keys %edited) . " products with edited fields or nutrients\n");

	print STDERR ((scalar @edited) . " products updated\n");

	return \%stats;
}



=head2 import_products_categories_from_public_database ( ARGUMENTS )

C<import_products_categories_from_public_database()> imports categories
from the public Open Food Facts database to the producers platform, for
products with a specific owner.

The products have to already exist in the producers platform.

=head3 Arguments

Arguments are passed through a single hash reference with the following keys:

=head4 user_id - required

User id to which the changes (new products, added or changed values, new images)
will be attributed.

=head4 org_id - optional

Organisation id to which the changes (new products, added or changed values, new images)
will be attributed.

=head4 owner_id - required

Owner of the products on the producers platform.

=cut

sub import_products_categories_from_public_database($) {

	my $args_ref = shift;

	$User_id = $args_ref->{user_id};
	$Org_id = $args_ref->{org_id};
	$Owner_id = get_owner_id($User_id, $Org_id, $args_ref->{owner_id});

	my $query_ref = { owner => $Owner_id };

	my $products_collection = get_products_collection();

	my $cursor = $products_collection->query($query_ref)->fields({ _id => 1, code => 1, owner => 1 });
	$cursor->immortal(1);

	my $n = 0;

	while (my $product_ref = $cursor->next) {

		my $productid = $product_ref->{_id};
		my $code = $product_ref->{code};
		my $path = product_path($product_ref);

		my $owner_info = "";
		if (defined $product_ref->{owner}) {
			$owner_info = "- owner: " . $product_ref->{owner} . " ";
		}

		if (not defined $code) {
			print STDERR "code field undefined for product id: " . $product_ref->{id} . " _id: " . $product_ref->{_id} . "\n";
		}
		else {
			print STDERR "updating product code: $code $owner_info ($n)\n";
		}

		# Load the product from the public database

		my $imported_product_ref;

		if (defined $server_options{export_data_root}) {

			my $public_path = product_path_from_id($code);
			my $file = $server_options{export_data_root} . "/products/$public_path/product.sto";

			$imported_product_ref = retrieve($file);

			if (not defined $imported_product_ref) {
				$log->debug("import_product_categories - unable to load public product file", { code => $code, file => $file } ) if $log->is_debug();
			}
		}

		if (defined $imported_product_ref) {

			# Load the product from the producers platform

			$product_ref = retrieve_product($productid);

			if (defined $product_ref) {

				my $field = "categories";

				my $current_field = $product_ref->{$field};

				my %existing = ();
					if (defined $product_ref->{$field . "_tags"}) {
					foreach my $tagid (@{$product_ref->{$field . "_tags"}}) {
						$existing{$tagid} = 1;
					}
				}

				foreach my $tag (split(/,/, $imported_product_ref->{$field})) {

					my $tagid;

					next if $tag =~ /^(\s|,|-|\%|;|_|°)*$/;

					$tag =~ s/^\s+//;
					$tag =~ s/\s+$//;

					if (defined $taxonomy_fields{$field}) {
						$tagid = get_taxonomyid($imported_product_ref->{lc}, canonicalize_taxonomy_tag($imported_product_ref->{lc}, $field, $tag));
					}

					if (not exists $existing{$tagid}) {
						$product_ref->{$field} .= ", $tag";
						$existing{$tagid} = 1;
					}
				}

				if ((defined $product_ref->{$field}) and ($product_ref->{$field} =~ /^, /)) {
					$product_ref->{$field} = $';
				}

				if ((not defined $current_field) or ($current_field ne $product_ref->{$field})) {
					$log->debug("import_product_categories - new categories", { categories => $product_ref->{$field} } ) if $log->is_debug();
					compute_field_tags($product_ref, $product_ref->{lc}, $field);
					if ($server_domain =~ /openfoodfacts/) {
						$log->debug("Food::special_process_product") if $log->is_debug();
						ProductOpener::Food::special_process_product($product_ref);
					}
					compute_nutrition_score($product_ref);
					compute_nova_group($product_ref);
					compute_nutrient_levels($product_ref);
					compute_unknown_nutrients($product_ref);
					ProductOpener::DataQuality::check_quality($product_ref);
					store_product($product_ref, "imported categories from public database");
				}

			}
			else {
				$log->debug("import_product_categories - unable to load private product file", { code => $code } ) if $log->is_debug();
			}
		}

		$n++;
	}

	return;
}

1;

