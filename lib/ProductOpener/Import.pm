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

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

use Storable qw(dclone);
use Text::Fuzzy;
use Data::DeepAccess qw(deep_exists);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		$IMPORT_MAX_PACKAGING_COMPONENTS

		&import_csv_file
		&import_products_categories_from_public_database

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
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
use ProductOpener::ImportConvert qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Orgs qw/:all/;
use ProductOpener::Data qw/:all/;
use ProductOpener::Packaging qw/:all/;
use ProductOpener::Ecoscore qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;
use ProductOpener::PackagerCodes qw/:all/;
use ProductOpener::API qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use Data::Dumper;
use Text::CSV;
use DateTime::Format::ISO8601;
use URI;
use Digest::MD5 qw(md5_hex);
use LWP::UserAgent;
use Data::Difference qw(data_diff);

$IMPORT_MAX_PACKAGING_COMPONENTS = 10;

# private function to import images from dir
# args:
# image_dir: path to image directory
# stats: stats map
# return
sub import_images_from_dir ($image_dir, $stats) {
	my $images_ref = {};

	if (not -d $image_dir) {
		die("images_dir $image_dir is not a directory\n");
	}

	# images rules to assign front/ingredients/nutrition image ids

	my @images_rules = ();

	if (-e "$image_dir/images.rules") {

		$log->debug("found images.rules in images_dir", {images_dir => $image_dir}) if $log->is_debug();

		open(my $in, '<', "$image_dir/images.rules") or die "Could not open $image_dir/images.rules : $!\n";
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
				$log->debug("adding rule", {find => $1, replace => $2}) if $log->is_debug();
			}
			else {
				die("Unrecognized line number $line: $line_number\n");
			}
		}
	}
	else {
		$log->debug("did not find images.rules in images_dir", {images_dir => $image_dir}) if $log->is_debug();
	}

	$log->debug("opening images_dir", {images_dir => $image_dir}) if $log->is_debug();

	if (opendir(DH, $image_dir)) {
		foreach my $file (sort {$a cmp $b} readdir(DH)) {

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
					$log->debug("applied rule", {find => $find, replace => $replace, file => $file, file2 => $file2})
						if $log->is_debug();
				}
			}

			if ($file2 =~ /(\d+)(_|-|\.)?([^\.-]*)?((-|\.)(.*))?\.(jpg|jpeg|png)/i) {

				if ((-s $image_dir . "/" . "$file") < 10000) {
					$log->debug("skipping too small image file", {file => $file, size => (-s $file)})
						if $log->is_debug();
					next;
				}

				my $code = $1;
				$code = normalize_code($code);
				my $imagefield = $3;    # front / ingredients / nutrition , optionally with _[language code] suffix

				if ((not defined $imagefield) or ($imagefield eq '')) {
					$imagefield = "front";
				}

				$stats->{products_with_images_even_if_no_data}{$code} = 1;

				$log->debug("found image", {code => $code, imagefield => $imagefield, file => $file, file2 => $file2})
					if $log->is_debug();

				# skip jpg and keep png for front product image

				defined $images_ref->{$code} or $images_ref->{$code} = {};

				# push @{$images_ref->{$code}}, $file;
				# keep jpg if there is also a png
				if (not defined $images_ref->{$code}{$imagefield}) {
					$images_ref->{$code}{$imagefield} = $image_dir . "/" . $file;
				}
			}
		}
	}
	else {
		die("Could not open images_dir $image_dir : $!\n");
	}

	return $images_ref;
}

# download image at given url parameter
sub download_image ($image_url) {

	my $ua = LWP::UserAgent->new(timeout => 10);

	# Some platforms such as CloudFlare block the default LWP user agent.
	$ua->agent(lang('site_name') . " (https://$server_domain)");

	return $ua->get($image_url);
}

# deduplicate column names
# We may have duplicate columns (e.g. image_other_url),
# turn them to image_other_url.2 etc.
# arguments: column ref
# return array ref column_names
sub deduped_colnames ($columns_ref) {
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
	return \@column_names;
}

=head1 FUNCTIONS

=head2 preprocess_field($imported_product_ref, $product_ref, $field, $yes_regexp, $no_regexp)

Do some pre-processing on input field values:

- Fields suffixed with _if_not_existing are loaded only if the product does not have an existing value
- Special handling of tags fields:
	- Empty values are skipped
	- For labels and categories, we can have columns like labels:Bio with values like 1, Y, Yes
	- [tags type]_if_match_in_taxonomy : contains candidate values that we import only if we have a matching taxonomy entry
	- Values for multiple columns for the same tag field. e.g. brands, brands.2, brands.3 etc. are concatenated with a comma

=cut

sub preprocess_field ($imported_product_ref, $product_ref, $field, $yes_regexp, $no_regexp) {

	# fields suffixed with _if_not_existing are loaded only if the product does not have an existing value

	if (
		not((defined $product_ref->{$field}) and ($product_ref->{$field} !~ /^\s*$/))
		and (   (defined $imported_product_ref->{$field . "_if_not_existing"})
			and ($imported_product_ref->{$field . "_if_not_existing"} !~ /^\s*$/))
		)
	{
		print STDERR "no existing value for $field, using value from ${field}_if_not_existing: "
			. $imported_product_ref->{$field . "_if_not_existing"} . "\n";
		$imported_product_ref->{$field} = $imported_product_ref->{$field . "_if_not_existing"};
	}
	# if it is a tag field (taxonomized or not)
	# (see %tags_fields in Tags.pm)
	if (defined $tags_fields{$field}) {
		foreach my $subfield (sort keys %{$imported_product_ref}) {
			# empty values are skipped
			next
				if ((not defined $imported_product_ref->{$subfield})
				or ($imported_product_ref->{$subfield} eq ""));

			# For labels and categories, we can have columns like labels:Bio with values like 1, Y, Yes
			# concatenate them to the labels field

			if ($subfield =~ /^$field:/) {
				# tag_name is the part after field name, like Bio
				my $tag_name = $';
				my $tag_to_add;

				$log->debug("specific field",
					{field => $field, tag_name => $tag_name, value => $imported_product_ref->{$subfield}})
					if $log->is_debug();

				# compute the tag value to add
				# if it's yes add tag_name
				if ($imported_product_ref->{$subfield} =~ /^\s*($yes_regexp)\s*$/i) {
					$tag_to_add = $tag_name;
				}

				# else if we have a value like 0, N, No and an opposite property exists in the taxonomy
				# then add the negative entry
				elsif ($imported_product_ref->{$subfield} =~ /^\s*($no_regexp)\s*$/i) {
					# fetch tag
					my $tagid = canonicalize_taxonomy_tag($imported_product_ref->{lc}, $field, $tag_name);

					$log->debug(
						"opposite value for specific field",
						{
							field => $field,
							value => $imported_product_ref->{$subfield},
							tag_name => $tag_name,
							tagid => $tagid,
							opposite_tagid => get_property($field, $tagid, "opposite:en")
						}
					) if $log->is_debug();

					if (exists_taxonomy_tag($field, $tagid)) {
						my $opposite_tagid = get_property($field, $tagid, "opposite:en");
						# we have an opposite, add it
						if (defined $opposite_tagid) {
							$tag_to_add = $opposite_tagid;
						}
					}
				}
				# If we have a tag to add
				# (because we had a "yes" or a "no" value for a specific tag field),
				# concatenate it to possible pre-existing tags
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

			if ($subfield =~ /^${field}_if_match_in_taxonomy/) {

				# we may have comma separated values
				foreach my $value (split(/\s*,\s*/, $imported_product_ref->{$subfield})) {
					if (
						exists_taxonomy_tag(
							$field, canonicalize_taxonomy_tag($imported_product_ref->{lc}, $field, $value)
						)
						)
					{
						# it exists, add it to values
						if (defined $imported_product_ref->{$field}) {
							$imported_product_ref->{$field} .= "," . $value;
						}
						else {
							$imported_product_ref->{$field} = $value;
						}
					}
				}
			}

			# We may have multiple columns for the same tag field. e.g. brands, brands.2, brands.3 etc.
			# Concatenate them with a comma

			if ($subfield =~ /^${field}\.(\d+)$/) {
				$imported_product_ref->{$field} .= ',' . $imported_product_ref->{$subfield};
			}
		}
	}

	return;
}

=head2 set_field_value($args_ref, $imported_product_ref, $product_ref, $field, $yes_regexp, $no_regexp, $stats_ref, $modified_ref, $differing_ref)

Update a product field value in $product_ref based on the value in the imported product $imported_product_ref

Return an incremented $modified value if a change was made.

=cut

sub set_field_value (
	$args_ref, $imported_product_ref, $product_ref, $field,
	$yes_regexp, $no_regexp, $stats_ref, $modified_ref,
	$modified_fields_ref, $differing_ref, $differing_fields_ref, $time
	)
{

	my $code = $imported_product_ref->{code};

	$log->debug("defined and non empty value for field", {field => $field, value => $imported_product_ref->{$field}})
		if $log->is_debug();

	if (($field =~ /product_name/) or ($field eq "brands")) {
		$stats_ref->{products_with_info}{$code} = 1;
	}

	if ($field =~ /^ingredients/) {
		$stats_ref->{products_with_ingredients}{$code} = 1;
	}

	if (
			(defined $Owner_id)
		and ($Owner_id =~ /^org-/)
		and ($field ne "imports")    # "imports" contains the timestamp of each import
		)
	{

		# Don't set owner_fields for apps, labels and databases, only for producers
		if (    ($Owner_id !~ /^org-app-/)
			and ($Owner_id !~ /^org-database-/)
			and ($Owner_id !~ /^org-label-/))
		{
			$product_ref->{owner_fields}{$field} = $time;

			# Save the imported value, before it is cleaned etc. so that we can avoid reimporting data that has been manually changed afterwards
			if (
				   (not defined $product_ref->{$field . "_imported"})
				or ($product_ref->{$field . "_imported"} ne $imported_product_ref->{$field})
				# we had a bug that caused serving_size to be set to "serving": change it
				or (($field eq "serving_size") and ($product_ref->{$field} eq "serving"))
				)
			{
				$log->debug(
					"setting _imported field value",
					{
						field => $field,
						imported_value => $imported_product_ref->{$field},
						current_value => $product_ref->{$field}
					}
				) if $log->is_debug();
				$product_ref->{$field . "_imported"} = $imported_product_ref->{$field};
				$$modified_ref++;
				defined $stats_ref->{"products_imported_field_" . $field . "_updated"}
					or $stats_ref->{"products_imported_field_" . $field . "_updated"} = {};
				$stats_ref->{"products_imported_field_" . $field . "_updated"}{$code} = 1;
			}

			# Skip data that we have already imported before (even if it has been changed)
			# But do import the field "obsolete"
			elsif ( ($field ne "obsolete")
				and (defined $product_ref->{$field . "_imported"})
				and ($product_ref->{$field . "_imported"} eq $imported_product_ref->{$field}))
			{
				# we had a bug that caused serving_size to be set to "serving", this value should be overridden
				return if (($field eq "serving_size") and ($product_ref->{"serving_size"} eq "serving"));
				$log->debug(
					"skipping field that was already imported",
					{
						field => $field,
						imported_value => $imported_product_ref->{$field},
						current_value => $product_ref->{$field}
					}
				) if $log->is_debug();
				return;
			}
		}
		# For apps, databases, labels: do not overwrite fields provided by the owner
		else {
			# Tags field will be added, we can import them
			if ((not defined $tags_fields{$field}) and (defined $product_ref->{owner_fields}{$field})) {
				$log->debug(
					"skipping field that was already imported by the owner",
					{
						field => $field,
						imported_value => $imported_product_ref->{$field},
						current_value => $product_ref->{$field}
					}
				) if $log->is_debug();
				return;
			}
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

		# If we are on the producers platform, replace existing values by producer supplied values for allergens and traces
		if (deep_exists(\%options, "replace_existing_values_when_importing_those_tags_fields", $field)) {
			if ($imported_product_ref->{$field} ne "") {
				$product_ref->{$field} = "";
				delete $product_ref->{$field . "_tags"};
			}
		}

		# existing is the list of already existing tags
		# that will be completed with more values
		my %existing = ();
		if (defined $product_ref->{$field . "_tags"}) {
			foreach my $tagid (@{$product_ref->{$field . "_tags"}}) {
				$existing{$tagid} = 1;
			}
		}
		# process each provided value
		foreach my $tag (split(/,/, $imported_product_ref->{$field})) {

			my $tagid;

			next
				if $tag =~ /^\s*($empty_regexp|$unknown_regexp|$not_applicable_regexp)\s*$/i;

			$tag =~ s/^\s+//;
			$tag =~ s/\s+$//;
			# normalize field in different ways depending on its type
			if ($field eq 'emb_codes') {
				$tag = normalize_packager_codes($tag);
			}

			if (defined $taxonomy_fields{$field}) {
				$tagid = get_taxonomyid($imported_product_ref->{lc},
					canonicalize_taxonomy_tag($imported_product_ref->{lc}, $field, $tag));
			}
			else {
				$tagid = get_string_id_for_lang("no_language", $tag);
			}
			# if the tag was not already in the existing tags, add it
			if (not exists $existing{$tagid}) {
				$log->debug("adding tagid to field", {field => $field, tagid => $tagid})
					if $log->is_debug();
				$product_ref->{$field} .= ", $tag";
				$existing{$tagid} = 1;
			}
			else {
				#print "- $tagid already in $field\n";
				# replace eventual tagid by it's plain value
				# update the case (e.g. for brands)
				if ($field eq "brands") {
					my $regexp = $tag;
					$regexp =~ s/( |-)/\( \|-\)/g;
					$product_ref->{$field} =~ s/\b$tagid\b/$tag/i;
					$product_ref->{$field} =~ s/\b$regexp\b/$tag/i;
				}
			}
		}
		# remove leading comma
		if ((defined $product_ref->{$field}) and ($product_ref->{$field} =~ /^, /)) {
			$product_ref->{$field} = $';
		}

		my $tag_lc = $product_ref->{lc};

		# If an import_lc was passed as a parameter, assume the imported values are in the import_lc language
		if (defined $args_ref->{import_lc}) {
			$tag_lc = $args_ref->{import_lc};
		}
		# emb_codes noramlization
		if ($field eq 'emb_codes') {
			# French emb codes
			$product_ref->{emb_codes_orig} = $product_ref->{emb_codes};
			$product_ref->{emb_codes} = normalize_packager_codes($product_ref->{emb_codes});
		}
		# post processing according to the type of action
		# $current_field is the value before update
		if (not defined $current_field) {
			$log->debug("added value to field", {field => $field, value => $product_ref->{$field}})
				if $log->is_debug();
			# recompute tags
			compute_field_tags($product_ref, $tag_lc, $field);
			# rembember it was added
			push @$modified_fields_ref, $field;
			# upddate stats
			$$modified_ref++;
			$stats_ref->{products_info_added}{$code} = 1;
			defined $stats_ref->{"products_info_added_" . $field} or $stats_ref->{"products_info_added_" . $field} = {};
			$stats_ref->{"products_info_added_field_" . $field}{$code} = 1;
		}
		elsif ($current_field ne $product_ref->{$field}) {
			$log->debug("changed value for field",
				{field => $field, value => $product_ref->{$field}, old_value => $current_field})
				if $log->is_debug();
			# recompute tags
			compute_field_tags($product_ref, $tag_lc, $field);
			# rembember it was added
			push @$modified_fields_ref, $field;
			# upddate stats
			$$modified_ref++;
			$stats_ref->{products_info_changed}{$code} = 1;
			defined $stats_ref->{"products_info_changed_" . $current_field}
				or $stats_ref->{"products_info_changed_" . $current_field} = {};
			$stats_ref->{"products_info_changed_field_" . $current_field}{$code} = 1;
		}
		elsif ($field eq "brands") {    # we removed it earlier
			compute_field_tags($product_ref, $tag_lc, $field);
		}
	}
	# Processing non tag field
	else {
		# new value replaces the old value
		my $new_field_value = $imported_product_ref->{$field};

		next if not defined $new_field_value;
		# remove leading and trailing spaces
		$new_field_value =~ s/\s+$//;
		$new_field_value =~ s/^\s+//;

		next if $new_field_value eq "";
		# specific normalizations for quantity and serving_size
		# TODO: move in a generic function
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
		# remove leading and trailing spaces
		$new_field_value =~ s/\s+$//g;
		$new_field_value =~ s/^\s+//g;

		# Some fields like "obsolete" can have yes/no values
		if ($field eq "obsolete") {
			if ($new_field_value =~ /^\s*($yes_regexp)\s*$/i) {
				$new_field_value = "on";    # internal value (value of the checkbox field)
			}
			# If we have a value like 0, N, No, delete the field
			if ($new_field_value =~ /^\s*($no_regexp)\s*$/i) {
				$new_field_value = "-";
			}
		}

		if ($new_field_value eq "") {
			next;
		}

		# if the value is -, it is an indication that we should remove existing values
		if ($new_field_value eq '-') {
			# existing value?
			if ((defined $product_ref->{$field}) and ($product_ref->{$field} !~ /^\s*$/)) {
				$log->debug(
					"removing existing value for field",
					{
						field => $field,
						existing_value => $product_ref->{$field},
						new_value => $new_field_value
					}
				) if $log->is_debug();
				$$differing_ref++;
				$differing_fields_ref->{$field}++;

				$product_ref->{$field} = "";

				push @$modified_fields_ref, $field;
				$$modified_ref++;
				$stats_ref->{products_info_changed}{$code} = 1;
			}
		}
		else {
			# existing value?
			if ((defined $product_ref->{$field}) and ($product_ref->{$field} !~ /^\s*$/)) {

				if ($args_ref->{skip_existing_values}) {
					$log->debug("skip existing value for field", {field => $field, value => $product_ref->{$field}})
						if $log->is_debug();
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
					$log->debug(
						"differing value for field",
						{
							field => $field,
							existing_value => $product_ref->{$field},
							new_value => $new_field_value
						}
					) if $log->is_debug();
					$$differing_ref++;
					$differing_fields_ref->{$field}++;

					$product_ref->{$field} = $new_field_value;

					# do not count the import id as a change
					if ($field ne "imports") {
						push @$modified_fields_ref, $field;
						$$modified_ref++;
						$stats_ref->{products_info_changed}{$code} = 1;
					}
				}
				elsif (($field eq 'quantity') and ($product_ref->{$field} ne $new_field_value)) {
					# normalize quantity
					$log->debug(
						"normalizing quantity",
						{
							field => $field,
							existing_value => $product_ref->{$field},
							new_value => $new_field_value
						}
					) if $log->is_debug();
					$product_ref->{$field} = $new_field_value;
					push @$modified_fields_ref, $field;
					$$modified_ref++;

					$stats_ref->{products_info_changed}{$code} = 1;
					defined $stats_ref->{"products_info_changed_" . $field}
						or $stats_ref->{"products_info_changed_" . $field} = {};
					$stats_ref->{"products_info_changed_field_" . $field}{$code} = 1;
				}
			}
			else {
				$log->debug(
					"setting previously unexisting value for field",
					{field => $field, new_value => $new_field_value}
				) if $log->is_debug();
				$product_ref->{$field} = $new_field_value;

				# do not count the import id as a change
				if ($field ne "imports") {
					push @$modified_fields_ref, $field;
					$$modified_ref++;
					$stats_ref->{products_info_added}{$code} = 1;
				}
			}
		}
	}

	return;
}

sub import_nutrients (
	$args_ref, $imported_product_ref, $product_ref, $stats_ref, $modified_ref,
	$modified_fields_ref, $differing_ref, $differing_fields_ref, $nutrients_edited_ref, $time
	)
{

	my $code = $imported_product_ref->{code};

	my $seen_salt = 0;

	foreach my $nutrient_tagid (sort(get_all_taxonomy_entries("nutrients"))) {

		my $nid = $nutrient_tagid;
		$nid =~ s/^zz://g;

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
				if (    (defined $imported_product_ref->{"nutrition_data" . $type . "_per"})
					and ($imported_product_ref->{"nutrition_data" . $type . "_per"} eq "100g")
					and ($per eq "_serving"))
				{
					next;
				}

				if (    (defined $imported_product_ref->{$nid . $type . $per . "_value"})
					and ($imported_product_ref->{$nid . $type . $per . "_value"} ne ""))
				{
					$values{$type} = $imported_product_ref->{$nid . $type . $per . "_value"};
				}

				if (    (defined $imported_product_ref->{$nid . $type . $per . "_unit"})
					and ($imported_product_ref->{$nid . $type . $per . "_unit"} ne ""))
				{
					$unit = $imported_product_ref->{$nid . $type . $per . "_unit"};
				}

				# Energy can be: 852KJ/ 203Kcal
				# calcium_100g_value_unit = 50 mg
				# 10g
				if (not defined $values{$type}) {
					if (defined $imported_product_ref->{$nid . $type . $per . "_value_unit"}) {

						# Assign energy-kj and energy-kcal values from energy field

						if (    ($nid eq "energy")
							and ($imported_product_ref->{$nid . $type . $per . "_value_unit"} =~ /\b([0-9]+)(\s*)kJ/i))
						{
							if (not defined $imported_product_ref->{$nid . "-kj" . $type . $per . "_value_unit"}) {
								$imported_product_ref->{$nid . "-kj" . $type . $per . "_value_unit"} = $1 . " kJ";
							}
						}
						if (
								($nid eq "energy")
							and ($imported_product_ref->{$nid . $type . $per . "_value_unit"} =~ /\b([0-9]+)(\s*)kcal/i)
							)
						{
							if (not defined $imported_product_ref->{$nid . "-kcal" . $type . $per . "_value_unit"}) {
								$imported_product_ref->{$nid . "-kcal" . $type . $per . "_value_unit"} = $1 . " kcal";
							}
						}

						if ($imported_product_ref->{$nid . $type . $per . "_value_unit"}
							=~ /^(~?<?>?=?\s?([0-9]*(\.|,))?[0-9]+)(\s*)([a-zµ%]+)$/i)
						{
							$values{$type} = $1;
							$unit = $5;
						}
						# We might have only a number even if the field is set to value_unit
						# in that case, use the default unit
						elsif ($imported_product_ref->{$nid . $type . $per . "_value_unit"}
							=~ /^(([0-9]*(\.|,))?[0-9]+)(\s*)$/i)
						{
							$values{$type} = $1;
						}
					}
				}

				# calcium_100g_value_in_mcg

				if (not defined $values{$type}) {
					foreach my $u ('kj', 'kcal', 'kg', 'g', 'mg', 'mcg', 'l', 'dl', 'cl', 'ml', 'iu', 'percent') {
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
				elsif ($unit eq "percent") {
					$unit = '%';
				}
			}

			my $modifier = undef;

			# Remove bogus values (e.g. nutrition facts for multiple nutrients): 1 digit followed by letters followed by more digits
			if ((defined $values{$type}) and ($values{$type} =~ /\d.*[a-z].*\d/)) {
				$log->debug("nutrient with strange value, skipping",
					{nid => $nid, type => $type, value => $values{$type}, unit => $unit})
					if $log->is_debug();
				delete $values{$type};
			}

			(defined $values{$type}) and normalize_nutriment_value_and_modifier(\$values{$type}, \$modifier);

			if ((defined $values{$type}) and ($values{$type} ne '')) {

				if ($nid eq 'salt') {
					$seen_salt = 1;
				}

				$log->debug("nutrient with defined and non empty value",
					{nid => $nid, type => $type, value => $values{$type}, unit => $unit})
					if $log->is_debug();
				$stats_ref->{"products_with_nutrition" . $type}{$code} = 1;

				# if the nid is "energy" and we have a unit, set "energy-kj" or "energy-kcal"
				if (($nid eq "energy") and ((lc($unit) eq "kj") or (lc($unit) eq "kcal"))) {
					$nid = "energy-" . lc($unit);
				}

				assign_nid_modifier_value_and_unit($product_ref, $nid . $type, $modifier, $values{$type}, $unit);

				if (    (defined $Owner_id)
					and ($Owner_id =~ /^org-/)
					and ($Owner_id !~ /^org-app-/)
					and ($Owner_id !~ /^org-database-/)
					and ($Owner_id !~ /^org-label-/))
				{
					$product_ref->{owner_fields}{$nid} = $time;
				}
			}
		}

		# See which fields have changed

		foreach my $field (sort keys %original_values) {
			if (    (defined $product_ref->{nutriments}{$field})
				and ($product_ref->{nutriments}{$field} ne "")
				and (defined $original_values{$field})
				and ($original_values{$field} ne "")
				and ($product_ref->{nutriments}{$field} ne $original_values{$field}))
			{
				$log->debug("differing nutrient value",
					{field => $field, old => $original_values{$field}, new => $product_ref->{nutriments}{$field}})
					if $log->is_debug();
				$stats_ref->{products_nutrition_updated}{$code} = 1;
				$stats_ref->{products_nutrition_changed}{$code} = 1;
				$$modified_ref++;
				$nutrients_edited_ref->{$code}++;
				push @$modified_fields_ref, "nutrients.$field";
			}
			elsif (
					(defined $product_ref->{nutriments}{$field})
				and ($product_ref->{nutriments}{$field} ne "")
				and (  (not defined $original_values{$field})
					or ($original_values{$field} eq ''))
				)
			{
				$log->debug("new nutrient value", {field => $field, new => $product_ref->{nutriments}{$field}})
					if $log->is_debug();
				$stats_ref->{products_nutrition_updated}{$code} = 1;
				$stats_ref->{products_nutrition_added}{$code} = 1;
				$$modified_ref++;
				$nutrients_edited_ref->{$code}++;
				push @$modified_fields_ref, "nutrients.$field";
			}
			elsif ( (not defined $product_ref->{nutriments}{$field})
				and (defined $original_values{$field})
				and ($original_values{$field} ne ''))
			{
				$log->debug("deleted nutrient value", {field => $field, old => $original_values{$field}})
					if $log->is_debug();
				$stats_ref->{products_nutrition_updated}{$code} = 1;
				$$modified_ref++;
				$nutrients_edited_ref->{$code}++;
				push @$modified_fields_ref, "nutrients.$field";
			}
		}
	}

	return;
}

sub set_nutrition_data_per_fields ($args_ref, $imported_product_ref, $product_ref, $stats_ref, $modified_ref) {

	my $code = $imported_product_ref->{code};

	my $nutrition_data_per = $imported_product_ref->{nutrition_data_per};
	my $nutrition_data_prepared_per = $imported_product_ref->{nutrition_data_prepared_per};

	# Set nutrition_data_per and nutrition_data_prepared_per fields

	foreach my $type ("", "_prepared") {

		if (defined $stats_ref->{"products_with_nutrition" . $type}{$code}) {

			my $nutrition_data_field = "nutrition_data" . $type;
			my $nutrition_data_per_field = "nutrition_data" . $type . "_per";
			my $imported_nutrition_data_per_value = $imported_product_ref->{$nutrition_data_per_field};

			$log->debug(
				"nutrition_data_per_field imported value",
				{
					code => $code,
					nutrition_data_per_field => $nutrition_data_per_field,
					imported_nutrition_data_per_value => $imported_nutrition_data_per_value
				}
			) if $log->is_debug();

			# Set nutrition_data_per to 100g if it was not provided and we have nutrition data in the csv file
			if ((not defined $imported_nutrition_data_per_value) or ($imported_nutrition_data_per_value eq "")) {

				$log->debug(
					"nutrition_data_per_field value not supplied, setting to 100g",
					{
						code => $code,
						nutrition_data_per_field => $nutrition_data_per_field,
						$imported_nutrition_data_per_value => $imported_nutrition_data_per_value
					}
				) if $log->is_debug();
				$imported_nutrition_data_per_value = "100g";
			}

			# Apps and the web product edit form on OFF always send "100g" or "serving" in the nutrition_data_per fields
			# but imports from GS1 / Equadis can have values like "100.0 g" or "240.0 grm"

			# 100.00g -> 100g
			$imported_nutrition_data_per_value =~ s/(\d)(\.|,)0?0?([^0-9])/$1$3/;
			$imported_nutrition_data_per_value =~ s/(grammes|grams|gr)\b/g/ig;

			# 100 g or 100 ml -> assign to the per 100g value
			if ($imported_nutrition_data_per_value =~ /^100\s?(g|ml)$/i) {
				$imported_nutrition_data_per_value = "100g";
			}
			elsif ($imported_nutrition_data_per_value =~ /^serving$/i) {
				$imported_nutrition_data_per_value = "serving";
			}
			# otherwise, assign the per serving value, and assign serving size
			else {
				$log->debug(
					"nutrition_data_per_field corresponds to serving size",
					{
						code => $code,
						nutrition_data_per_field => $nutrition_data_per_field,
						$imported_nutrition_data_per_value => $imported_nutrition_data_per_value
					}
				) if $log->is_debug();
				if (   (not defined $product_ref->{serving_size})
					or ($product_ref->{serving_size} ne $imported_nutrition_data_per_value))
				{
					$product_ref->{serving_size} = $imported_nutrition_data_per_value;
					$$modified_ref++;
					$stats_ref->{products_data_updated}{$code} = 1;
					defined $stats_ref->{"products_serving_size_updated"}
						or $stats_ref->{"products_serving_size_updated"} = {};
					$stats_ref->{"products_serving_size_updated"}{$code} = 1;
				}
				$imported_nutrition_data_per_value = "serving";
			}

			# Set the nutrition_data[_prepared]_per field
			if (   (not defined $product_ref->{$nutrition_data_per_field})
				or ($product_ref->{$nutrition_data_per_field} ne $imported_nutrition_data_per_value))
			{
				$product_ref->{$nutrition_data_per_field} = $imported_nutrition_data_per_value;
				$stats_ref->{"products_" . $nutrition_data_per_field . "_updated"}{$code} = 1;
				$$modified_ref++;
				$stats_ref->{products_data_updated}{$code} = 1;
			}

			# Set the nutrition_data[_prepared] checkbox
			if (   (not defined $product_ref->{$nutrition_data_field})
				or ($product_ref->{$nutrition_data_field} ne "on"))
			{
				$product_ref->{$nutrition_data_field} = "on";
				defined $stats_ref->{"products_" . $nutrition_data_per_field . "_updated"}
					or $stats_ref->{"products_" . $nutrition_data_per_field . "_updated"} = {};
				$stats_ref->{"products_" . $nutrition_data_per_field . "_updated"}{$code} = 1;
				$$modified_ref++;
				$stats_ref->{products_data_updated}{$code} = 1;
			}
		}
	}

	return;
}

sub import_packaging_components (
	$args_ref, $imported_product_ref, $product_ref, $stats_ref,
	$modified_ref, $modified_fields_ref, $differing_ref, $differing_fields_ref,
	$packagings_edited_ref, $time
	)
{

	my $code = $imported_product_ref->{code};

	# keep a deep copy of the existing packaging components, so that we can check if the resulting components are different
	my $original_packagings_ref = dclone($product_ref->{packagings} || []);

	# build a list of input packaging components
	my @input_packagings = ();
	my $data_is_complete = 0;

	# packaging data is specified in the CSV file in columns named like packaging_1_number_of_units
	# we currently search up to 10 components

	for (my $i = 1; $i <= $IMPORT_MAX_PACKAGING_COMPONENTS; $i++) {
		my $input_packaging_ref = {};
		foreach
			my $field (qw(number_of_units shape material recycling quantity_per_unit weight_specified weight_measured))
		{
			$input_packaging_ref->{$field} = $imported_product_ref->{"packaging_${i}_${field}"};
		}
		$log->debug("input_packaging_ref", {i => $i, input_packaging_ref => $input_packaging_ref}) if $log->is_debug();

		# Taxonomize the input packaging component data
		push @input_packagings,
			get_checked_and_taxonomized_packaging_component_data($imported_product_ref->{lc}, $input_packaging_ref, {});

		# Record if we have complete input data, with all key fields (for at least 1 component)
		# not considered a key field (and thus may be lost): recycling instruction, quantity per unit
		# If we have complete data for one component in an import, we assume the data is reasonably
		# complete for all components (e.g. we might miss a weight for a very light component)
		if (
				(defined $input_packaging_ref->{number_of_units})
			and (defined $input_packaging_ref->{shape})
			and (defined $input_packaging_ref->{material})
			and
			((defined $input_packaging_ref->{weight_specified}) or (defined $input_packaging_ref->{weight_measured}))
			)
		{
			$data_is_complete = 1;
		}
	}

	if ($data_is_complete) {
		# We seem to have complete data, replace existing data
		$product_ref->{packagings} = \@input_packagings;
		# and set the packagings complete checkbox
		$product_ref->{packagings_complete} = 1;
	}
	else {
		# We have partial data, that may be missing fields like number of units, weight etc.
		# In that case, we try to merge the input components with the existing components
		# so that we don't lose user entered data such as weights
		# This may result in some components being duplicated, if the existing component and
		# the input component have incompatible fields (e.g. if one is a "tray" and the other a "box",
		# even though they refer to the same thing)

		foreach my $input_packaging_ref (@input_packagings) {
			add_or_combine_packaging_component_data($product_ref, $input_packaging_ref, {});
		}
	}

	# Check if the packagings data has changed
	my @diffs = data_diff($original_packagings_ref, $product_ref->{packagings});
	if (scalar @diffs > 0) {
		$log->debug(
			"packagings diff",
			{
				original_packagings => $original_packagings_ref,
				input_packagings => \@input_packagings,
				new_packagings => $product_ref->{packagings},
				data_is_complete => $data_is_complete,
				diffs => \@diffs
			}
		) if $log->is_debug();
		$stats_ref->{products_packagings_updated}{$code} = 1;
		if (scalar @$original_packagings_ref == 0) {
			$stats_ref->{products_packagings_created}{$code} = 1;
		}
		else {
			$stats_ref->{products_packagings_changed}{$code} = 1;
		}
		$$modified_ref++;
		$packagings_edited_ref->{$code}++;
		# push @$modified_fields_ref, "nutrients.$field";
	}

	# Update the packagings_complete_field

	return;
}

=head2 import_csv_file ( ARGUMENTS )

C<import_csv_file()> imports product data in the Open Food Facts CSV format
and associated product photos.

=head3 Arguments

Arguments are passed through a single hash reference with the following keys:

=head4 user_id - required

User id to which the changes (new products, added or changed values, new images)
will be attributed.

If the user_id is 'all', the change will be attributed to the org of the product.
(e.g. when importing products from the producers database to the public database)

=head4 org_id - optional

Organization id to which the changes (new products, added or changed values, new images)
will be attributed.

=head4 owner_id - optional

For databases with private products, owner (user or org) that the products belong to.
Values are of the form user-[user id] or org-[organization id].

If not set, for databases with private products, it will be constructed from the user_id
and org_id parameters.

The owner can be overrode if the CSV file contains a org_name field.
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

License that the source data is available in.

=head4 source_licence_url - optional (unless no_source is indicated)

URL for the license.

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

# Regexps to match localized Yes or No values in some fields
# lowercased

my %yes = (
	en => "on|yes|y",    # on is a special value, it does not need to be translated to other languages
	de => "ja|j",
	es => "si|s",
	fr => "oui|o",
	it => "si|s",
);

my %no = (
	en => "off|no|n|not",    # off is a special value, it does not need to be translated to other languages
	de => "nein|n",
	es => "no|n",
	fr => "non|n",
	it => "no|n",
);

sub import_csv_file ($args_ref) {

	$User_id = $args_ref->{user_id};
	$Org_id = $args_ref->{org_id};
	$Owner_id = get_owner_id($User_id, $Org_id, $args_ref->{owner_id});

	$log->debug("starting import_csv_file",
		{User_id => $User_id, Org_id => $Org_id, Owner_id => $Owner_id, args_ref => $args_ref})
		if $log->is_debug();

	# Load GS1 GLNs so that we can map products to the owner orgs
	my $glns_ref = retrieve("$BASE_DIRS{ORGS}/orgs_glns.sto");
	not defined $glns_ref and $glns_ref = {};

	my %global_values = ();
	if (defined $args_ref->{global_values}) {
		%global_values = %{$args_ref->{global_values}};
	}

	my $stats_ref = {
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
		'products_with_nutrition_prepared' => {},
		'products_without_images' => {},
		'products_without_data' => {},
		'products_without_info' => {},
		'products_without_info' => {},
		'products_without_nutrition' => {},
		'products_updated' => {},
		# Keep track of the number of products that are not imported
		# because the source does not have authorization for the org
		'orgs_without_source_authorization' => {},
		'orgs_created' => {},
		'orgs_existing' => {},
		'orgs_in_file' => {},
		'orgs_with_gln_but_no_party_name' => {},
	};

	my $csv = Text::CSV->new({binary => 1, sep_char => "\t"})    # should set binary attribute.
		or die "Cannot use CSV: " . Text::CSV->error_diag();

	my $time = time();

	# Read images from directory if supplied
	my $images_ref = {};
	if ((defined $args_ref->{images_dir}) and ($args_ref->{images_dir} ne '')) {
		$images_ref = import_images_from_dir($args_ref->{images_dir}, $stats_ref);
	}

	$log->debug("importing products", {}) if $log->is_debug();

	my $io;
	if (not open($io, '<:encoding(UTF-8)', $args_ref->{csv_file})) {
		$stats_ref->{error} = "Could not open " . $args_ref->{csv_file} . ": $!";
		return $stats_ref;
	}

	# first line contains headers
	my $columns_ref = $csv->getline($io);
	$csv->column_names(@{deduped_colnames($columns_ref)});

	my $i = 0;
	my $j = 0;
	my $existing = 0;
	my $new = 0;
	my $differing = 0;
	my %differing_fields = ();
	my @edited = ();
	my %edited = ();
	my %nutrients_edited = ();
	my %packagings_edited = ();
	my $skip_not_existing = 0;
	my $skip_no_images = 0;

	# go through file
	while (my $imported_product_ref = $csv->getline_hr($io)) {

		# Response structure to keep track of warnings and errors
		# Note: currently some warnings and errors are added,
		# but we do not yet do anything with them
		my $response_ref = get_initialized_response();

		$i++;

		# By default, use the orgid passed in the arguments
		# it may be overriden later on a per product basis
		my $org_id = $args_ref->{org_id};
		my $org_ref;

		# read code
		my $code = $imported_product_ref->{code};
		$code = normalize_code($code);

		my $modified = 0;

		# Keep track of fields that have been modified,
		# so that we don't import products that have not been modified
		my @modified_fields;

		my @images_ids;

		# Determine the org_id for the product

		$log->debug(
			"org for product - start",
			{
				org_name => $imported_product_ref->{org_name},
				org_id => $org_id,
				gln => $imported_product_ref->{"sources_fields:org-gs1:gln"}
			}
		) if $log->is_debug();

		# The option import_owner is used when exporting from the producers database to the public database
		if (    ($args_ref->{import_owner})
			and (defined $imported_product_ref->{owner})
			and ($imported_product_ref->{owner} =~ /^org-(.+)$/))
		{
			$org_id = $1;
			$log->debug("org_id from owner", {org_id => $org_id, owner => $imported_product_ref->{owner}})
				if $log->is_debug();
		}
		elsif (($args_ref->{use_brand_owner_as_org_name}) and (defined $imported_product_ref->{brand_owner})) {
			# The option -use_brand_owner_as_org_name can be used to set the org name
			# e.g. for the USDA branded food database import
			$imported_product_ref->{org_name} = $imported_product_ref->{brand_owner};
			$log->debug("org_id from brand owner",
				{org_id => $org_id, brand_owner => $imported_product_ref->{brand_owner}})
				if $log->is_debug();
		}
		# if the GLN corresponds to a GLN stored inside organization profiles (loaded in $glns_ref), use it
		elsif ( (defined $imported_product_ref->{"sources_fields:org-gs1:gln"})
			and ($glns_ref->{$imported_product_ref->{"sources_fields:org-gs1:gln"}}))
		{
			$org_id = $glns_ref->{$imported_product_ref->{"sources_fields:org-gs1:gln"}};
			$log->debug("org_id from gln",
				{org_id => $org_id, gln => $imported_product_ref->{"sources_fields:org-gs1:gln"}})
				if $log->is_debug();
		}
		# Otherwise, if the CSV includes an org_name (e.g. from GS1 partyName field)
		elsif (defined $imported_product_ref->{org_name}) {
			if ($imported_product_ref->{org_name} ne "") {
				# set the owner of the product to the org_name if it is not empty
				$org_id = get_string_id_for_lang("no_language", $imported_product_ref->{org_name});
				$log->debug("org_id from org_name", {org_id => $org_id, org_name => $imported_product_ref->{org_name}})
					if $log->is_debug();
			}
			else {
				# No org_id is set but we have an empty partyName
				# Could be a GS1 import with a GLN that we don't know about yet, and missing a partyName
				$log->debug(
					"skipping product with no org_id specified",
					{
						gln => $imported_product_ref->{"sources_fields:org-gs1:gln"},
						imported_product_ref => $imported_product_ref
					}
				) if $log->is_debug();
				$stats_ref->{orgs_with_gln_but_no_party_name}{$imported_product_ref->{"sources_fields:org-gs1:gln"}}++;
				next;
			}
		}

		$log->debug(
			"org for product - result",
			{
				org_name => $imported_product_ref->{org_name},
				org_id => $org_id,
				gln => $imported_product_ref->{"sources_fields:org-gs1:gln"}
			}
		) if $log->is_debug();

		if ((defined $org_id) and ($org_id ne "")) {
			# Re-assign some organizations
			# e.g. nestle-france-div-choc-cul-bi-inf -> nestle-france
			$org_id =~ s/^nestle-france-.*/nestle-france/;
			$org_id =~ s/^cereal-partners-france$/nestle-france/;
			$org_id =~ s/^nestle-spac$/nestle-france/;

			defined $stats_ref->{orgs_in_file}{$org_id} or $stats_ref->{orgs_in_file}{$org_id} = 0;
			$stats_ref->{orgs_in_file}{$org_id}++;

			$org_ref = retrieve_org($org_id);

			if (defined $org_ref) {

				defined $stats_ref->{orgs_existing}{$org_id} or $stats_ref->{orgs_existing}{$org_id} = 0;
				$stats_ref->{orgs_existing}{$org_id}++;

				# Make sure the source as the authorization to load data to the org
				# e.g. if an org has loaded fresh data manually or through Equadis,
				# don't overwrite it with potentially stale CodeOnline or USDA data

				# For files uploaded through the producers platform, the source_id is org-[id of org]

				if ((defined $args_ref->{source_id}) and ($args_ref->{source_id} ne "org-${org_id}")) {
					if (not $org_ref->{"import_source_" . $args_ref->{source_id}}) {
						$log->debug(
							"skipping import for org without authorization for the source",
							{org_ref => $org_ref, source_id => $args_ref->{source_id}}
						) if $log->is_debug();
						$stats_ref->{orgs_without_source_authorization}{$org_id}
							or $stats_ref->{orgs_without_source_authorization}{$org_id} = 0;
						$stats_ref->{orgs_without_source_authorization}{$org_id}++;
						next;
					}
				}

				# The do_not_import_codeonline checkbox will be replaced by the new system above that will work for all sources

				# Check if it is a CodeOnline import for an org with do_not_import_codeonline
				if (    (defined $args_ref->{source_id})
					and ($args_ref->{source_id} eq "codeonline")
					and (defined $org_ref->{do_not_import_codeonline})
					and ($org_ref->{do_not_import_codeonline}))
				{
					$log->debug("skipping codeonline import for org with do_not_import_codeonline",
						{org_ref => $org_ref})
						if $log->is_debug();
					next;
				}

				# If it is a GS1 import (Equadis, CodeOnline, Agena3000), check if the org is associated with known issues

				# Abbreviated product name
				if (
					(defined $args_ref->{source_id})
					and (  ($args_ref->{source_id} eq "codeonline")
						or ($args_ref->{source_id} eq "equadis")
						or ($args_ref->{source_id} eq "agena3000"))
					and (defined $org_ref->{gs1_product_name_is_abbreviated})
					and ($org_ref->{gs1_product_name_is_abbreviated})
					)
				{

					if (    (defined $imported_product_ref->{product_name_fr})
						and ($imported_product_ref->{product_name_fr} ne ""))
					{
						$imported_product_ref->{abbreviated_product_name_fr} = $imported_product_ref->{product_name_fr};
						delete $imported_product_ref->{product_name_fr};
					}
				}

				# Nutrition facts marked as "prepared" are in fact for unprepared / as sold product
				if (
					(defined $args_ref->{source_id})
					and (  ($args_ref->{source_id} eq "codeonline")
						or ($args_ref->{source_id} eq "equadis")
						or ($args_ref->{source_id} eq "agena3000"))
					and (defined $org_ref->{gs1_nutrients_are_unprepared})
					and ($org_ref->{gs1_nutrients_are_unprepared})
					)
				{

					foreach my $field (sort keys %$imported_product_ref) {
						if ($field =~ /_prepared/) {
							my $unprepared_field = $` . $';
							if (
								(
										(defined $imported_product_ref->{$field})
									and ($imported_product_ref->{$field} ne '')
								)
								and not((defined $imported_product_ref->{$unprepared_field})
									and ($imported_product_ref->{$unprepared_field} ne ""))
								)
							{
								$imported_product_ref->{$unprepared_field} = $imported_product_ref->{$field};
								delete $imported_product_ref->{$field};
							}
						}
					}
				}
			}
			else {
				# The org does not exist yet, create it

				defined $stats_ref->{orgs_created}{$org_id} or $stats_ref->{orgs_created}{$org_id} = 0;
				$stats_ref->{orgs_created}{$org_id}++;

				$org_ref = create_org($User_id, $org_id);
				$org_ref->{name} = $imported_product_ref->{org_name};

				# Set the sources field to authorize imports from the source that created the org
				# e.g. if the org was created by an import of Codeonline or the USDA,
				# then that source will be able to load new imports automatically
				# (unless the authorization is revoked by an admin or the org owner)

				if (defined $args_ref->{source_id}) {
					$org_ref->{"import_source_" . $args_ref->{source_id}} = "on";

					# Check the checkbox for automated exports to the public database
					$org_ref->{"activate_automated_daily_export_to_public_platform"} = "on";
				}

				if (defined $imported_product_ref->{"sources_fields:org-gs1:gln"}) {
					$org_ref->{sources_field} = {
						"org-gs1" => {
							gln => $imported_product_ref->{"sources_fields:org-gs1:gln"}
						}
					};
					if (defined $imported_product_ref->{"sources_fields:org-gs1:partyName"}) {
						$org_ref->{sources_field}{"org-gs1"}{"partyName"}
							= $imported_product_ref->{"sources_fields:org-gs1:partyName"};
					}
					set_org_gs1_gln($org_ref, $imported_product_ref->{"sources_fields:org-gs1:gln"});
					$glns_ref = retrieve("$BASE_DIRS{ORGS}/orgs_glns.sto");
				}

				store_org($org_ref);
			}
		}

		$Org_id = $org_id;
		$Owner_id = get_owner_id($User_id, $Org_id, $args_ref->{owner_id});
		my $product_id = product_id_for_owner($Owner_id, $code);

		# The userid can be overriden on a per product basis
		# when we import data from the producers platform to the public platform
		# we use the orgid as the userid
		my $user_id = $args_ref->{user_id};
		if ($user_id eq 'all') {
			$user_id = "org-" . $org_id;
		}

		if ((defined $args_ref->{skip_if_not_code}) and ($code ne $args_ref->{skip_if_not_code})) {
			next;
		}

		$log->debug("importing product", {i => $i, code => $code, product_id => $product_id}) if $log->is_debug();

		if ($code eq '') {
			$log->error("Error - empty code",
				{i => $i, code => $code, product_id => $product_id, imported_product_ref => $imported_product_ref})
				if $log->is_error();
			next;
		}

		if ($code !~ /^\d\d\d\d\d\d\d\d(\d*)$/) {
			$log->error("Error - code not a number with 8 or more digits",
				{i => $i, code => $code, product_id => $product_id, imported_product_ref => $imported_product_ref})
				if $log->is_error();
			next;
		}

		$stats_ref->{products_in_file}{$code} = 1;

		# apply global field values
		foreach my $field (keys %global_values) {
			if ((not defined $imported_product_ref->{$field}) or ($imported_product_ref->{$field} eq "")) {
				$imported_product_ref->{$field} = $global_values{$field};
			}
		}

		# add data_source "Producers"
		if ((defined $Org_id) and ($Org_id !~ /^app-/) and ($Org_id !~ /^database-/) and ($Org_id !~ /^label-/)) {
			if (defined $imported_product_ref->{data_sources}) {
				$imported_product_ref->{data_sources} .= ", Producers, Producer - " . $Org_id;
			}
			else {
				$imported_product_ref->{data_sources} = "Producers, Producer - " . $Org_id;
			}
		}

		if (not defined $imported_product_ref->{lc}) {
			$log->warning("Warning - missing language code lc in csv file or global field values",
				{i => $i, code => $code, product_id => $product_id, imported_product_ref => $imported_product_ref})
				if $log->is_warning();
		}
		else {
			if ($imported_product_ref->{lc} !~ /^\w\w$/) {
				$log->error(
					"Error - lc is not a 2 letter language code",
					{
						lc => $lc,
						i => $i,
						code => $code,
						product_id => $product_id,
						imported_product_ref => $imported_product_ref
					}
				) if $log->is_error();
				next;
			}

			# Set the $lang field to $lc
			$imported_product_ref->{lang} = $imported_product_ref->{lc};
		}

		# Clean the input data, populate some fields from other fields (e.g. split quantity found in product name)

		clean_fields($imported_product_ref);

		# image paths can be passed in fields image_front / nutrition / ingredients / other
		# several values can be passed in others

		foreach my $imagefield ("front", "ingredients", "nutrition", "other") {
			my $k = 0;
			if (defined $imported_product_ref->{"image_" . $imagefield}) {
				foreach my $file (split(/\s*,\s*/, $imported_product_ref->{"image_" . $imagefield})) {
					$file =~ s/^\s+//;
					$file =~ s/\s+$//;

					$log->debug("images", {file => $file}) if $log->is_debug();

					defined $images_ref->{$code} or $images_ref->{$code} = {};
					if ($imagefield ne "other") {
						$images_ref->{$code}{$imagefield} = $file;
					}
					else {
						$k++;
						$images_ref->{$code}{$imagefield . "_$k"} = $file;

						$log->debug("images - other", {file => $file, imagefield => $imagefield, k => $k})
							if $log->is_debug();

						# No front image yet? --> take this one
						if (not(defined $images_ref->{$code}{front})) {
							$images_ref->{$code}{front} = $file;
						}

						if (
							(
									(defined $images_ref->{$code}{front})
								and ($images_ref->{$code}{front} eq $images_ref->{$code}{$imagefield . "_$k"})
							)
							or (    (defined $images_ref->{$code}{ingredients})
								and ($images_ref->{$code}{ingredients} eq $images_ref->{$code}{$imagefield . "_$k"}))
							or (    (defined $images_ref->{$code}{nutrition})
								and ($images_ref->{$code}{nutrition} eq $images_ref->{$code}{$imagefield . "_$k"}))
							)
						{
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

			if (   (not defined $images_ref->{$code})
				or (not defined $images_ref->{$code}{front})
				or ((not defined $images_ref->{$code}{ingredients})))
			{
				print STDERR "MISSING IMAGES SOME - PRODUCT CODE $code\n";
				$skip_no_images++;
				next;
			}
		}

		# If we are importing on the public platform, check if the product exists on other servers
		# (e.g. Open Beauty Facts, Open Products Facts), unless it already exists on the target server

		my $product_ref;

		if (    (defined $options{other_servers})
			and not((defined $server_options{private_products}) and ($server_options{private_products}))
			and not(product_exists($product_id)))
		{
			foreach my $server (sort keys %{$options{other_servers}}) {
				next if ($server eq $options{current_server});

				$product_ref = product_exists_on_other_server($server, $product_id);
				if ($product_ref) {
					# Indicate to store_product() that the product is on another server
					$product_ref->{server} = $server;
					# Indicate to Images.pm functions that the product is on another server
					$product_id = $server . ":" . $product_id;
					$log->debug("product exists on another server",
						{code => $code, server => $server, product_id => $product_id})
						if $log->is_debug();
					last;    # no need to search on other servers
				}
			}
		}

		if (not $product_ref) {
			$product_ref = product_exists($product_id);    # returns 0 if not
		}

		my $product_comment = $args_ref->{comment};
		if ((defined $imported_product_ref->{comment}) and ($imported_product_ref->{comment} ne "")) {
			$product_comment .= " - " . $imported_product_ref->{comment};
		}

		if (not $product_ref) {
			$log->debug("product does not exist yet", {code => $code, product_id => $product_id}) if $log->is_debug();

			if ($args_ref->{skip_not_existing_products}) {
				$log->debug("skip not existing product", {code => $code, product_id => $product_id})
					if $log->is_debug();
				$skip_not_existing++;
				next;
			}

			$new++;
			if (1 and (not $product_ref)) {
				$log->debug("creating not existing product", {code => $code, product_id => $product_id})
					if $log->is_debug();

				$stats_ref->{products_created}{$code} = 1;

				$product_ref = init_product($user_id, $org_id, $code, undef);
				$product_ref->{interface_version_created} = "import_csv_file - version 2019/09/17";

				$product_ref->{lc} = $imported_product_ref->{lc};
				$product_ref->{lang} = $imported_product_ref->{lc};

				delete $product_ref->{countries};
				delete $product_ref->{countries_tags};
				delete $product_ref->{countries_hierarchy};
			}
		}
		else {
			$log->debug("product already exists", {code => $code, product_id => $product_id}) if $log->is_debug();
			$existing++;
			$stats_ref->{products_already_existing}{$code} = 1;
		}

		# If the data comes from GS1 / GSDN (e.g. through Equadis or Code Online Food)
		# skip the data if it less recent than the last publication date we have in sources_fields:org-gs1:publicationDateTime
		# use lastChangeDateTime if publicationDateTime is not available (e.g. CodeOnline)
		# e.g. if we have real time Equadis data, do not overwrite it with monthly Code Online Food extracts

		if ((defined $product_ref->{sources_fields}) and (defined $product_ref->{sources_fields}{"org-gs1"})) {

			my $imported_date = $imported_product_ref->{"sources_fields:org-gs1:publicationDateTime"}
				// $imported_product_ref->{"sources_fields:org-gs1:lastChangeDateTime"};

			my $existing_date = $product_ref->{sources_fields}{"org-gs1"}{publicationDateTime}
				// $product_ref->{sources_fields}{"org-gs1"}{lastChangeDateTime};

			if (    (defined $imported_date)
				and ($imported_date ne "")
				and (defined $existing_date)
				and ($existing_date ne ""))
			{

				# Broken date strings can cause parse_datetime to fail
				my $imported_date_t;
				my $existing_date_t;
				eval {
					$imported_date_t = DateTime::Format::ISO8601->parse_datetime($imported_date)->epoch;
					$existing_date_t = DateTime::Format::ISO8601->parse_datetime($existing_date)->epoch;
				};

				if ($@) {
					$log->warn("Could not parse imported or existing dates",
						{imported_date => $imported_date, existing_date => $existing_date, error => $@})
						if $log->is_warn();
				}
				elsif ($imported_date_t < $existing_date_t) {
					$log->debug(
						"existing GS1 data with a greater sources_fields:org-gs1:publicationDateTime - skipping product",
						{
							existing => $existing_date,
							imported => $imported_date
						}
					) if $log->is_debug();
					next;
				}
				else {
					$log->debug(
						"existing GS1 data without a greater sources_fields:org-gs1:publicationDateTime - importing product",
						{
							existing => $existing_date,
							imported => $imported_date
						}
					) if $log->is_debug();
				}
			}
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

		foreach my $field (
			'owner', 'lc',
			'lang', 'product_name',
			'abbreviated_product_name', 'generic_name',
			'packaging_text', @ProductOpener::Config::product_fields,
			@ProductOpener::Config::product_other_fields, 'obsolete',
			'obsolete_since_date', 'no_nutrition_data',
			'nutrition_data_per', 'nutrition_data_prepared_per',
			'serving_size', 'allergens',
			'traces', 'ingredients_text',
			'data_sources', 'imports'
			)
		{

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
		if (    (defined $Owner_id)
			and ($Owner_id =~ /^org-/)
			and ($Owner_id !~ /^org-app-/)
			and ($Owner_id !~ /^org-database-/)
			and ($Owner_id !~ /^org-label-/))
		{

			# If the product already has an owner different from the imported owner,
			# skip the product, unless the overwrite_owner property is set
			if (    (defined $product_ref->{owner})
				and ($product_ref->{owner} ne $Owner_id)
				and (not defined $args_ref->{overwrite_owner}))
			{
				$log->info(
					"existing product has a different owner, skip the product",
					{
						product_owner => $product_ref->{owner},
						owner_id => $Owner_id,
						args_ref_overwrite_owner => $args_ref->{overwrite_owner}
					}
				) if $log->is_info();
				next;
			}

			defined $product_ref->{owner_fields} or $product_ref->{owner_fields} = {};
			if ((not defined $product_ref->{owner}) or ($product_ref->{owner} ne $Owner_id)) {
				$product_ref->{owner} = $Owner_id;
				$product_ref->{owners_tags} = [$product_ref->{owner}];
				$modified++;
				my $field = "owner";
				defined $stats_ref->{"products_sources_field_" . $field . "_updated"}
					or $stats_ref->{"products_sources_field_" . $field . "_updated"} = {};
				$stats_ref->{"products_sources_field_" . $field . "_updated"}{$code} = 1;
			}
		}

		# We can have source specific fields of the form : sources_fields:org-database-usda:fdc_category
		# Transfer them directly
		foreach my $field (sort keys %{$imported_product_ref}) {
			if ($field =~ /^sources_fields:([a-z0-9-]+):/) {
				my $source_id = $1;
				my $source_field = $';
				defined $product_ref->{sources_fields} or $product_ref->{sources_fields} = {};
				defined $product_ref->{sources_fields}{$source_id} or $product_ref->{sources_fields}{$source_id} = {};
				if (   (not defined $product_ref->{sources_fields}{$source_id}{$source_field})
					or ($imported_product_ref->{$field} ne $product_ref->{sources_fields}{$source_id}{$source_field}))
				{
					$modified++;
					defined $stats_ref->{"products_sources_field_" . $field . "_updated"}
						or $stats_ref->{"products_sources_field_" . $field . "_updated"} = {};
					$stats_ref->{"products_sources_field_" . $field . "_updated"}{$code} = 1;
					$product_ref->{sources_fields}{$source_id}{$source_field} = $imported_product_ref->{$field};
				}
			}
		}

		# Construct Yes and No regexps with English + local language
		my $yes_regexp = '1|' . $yes{en};
		if ((defined $imported_product_ref->{lc}) and ($imported_product_ref->{lc} ne 'en')) {
			$yes_regexp .= '|' . $yes{$imported_product_ref->{lc}};
		}

		my $no_regexp = '0|' . $no{en};
		if ((defined $imported_product_ref->{lc}) and ($imported_product_ref->{lc} ne 'en')) {
			$no_regexp .= '|' . $no{$imported_product_ref->{lc}};
		}

		# Go through all the possible fields that can be imported
		foreach my $field (@param_fields) {

			preprocess_field($imported_product_ref, $product_ref, $field, $yes_regexp, $no_regexp);

			# if field exists and is not empty
			if ((defined $imported_product_ref->{$field}) and ($imported_product_ref->{$field} !~ /^\s*$/)) {
				set_field_value(
					$args_ref, $imported_product_ref, $product_ref, $field,
					$yes_regexp, $no_regexp, $stats_ref, \$modified,
					\@modified_fields, \$differing, \%differing_fields, $time
				);
			}
		}

		# Nutrients

		import_nutrients(
			$args_ref, $imported_product_ref, $product_ref, $stats_ref,
			\$modified, \@modified_fields, \$differing, \%differing_fields,
			\%nutrients_edited, $time,
		);

		set_nutrition_data_per_fields($args_ref, $imported_product_ref, $product_ref, $stats_ref, \$modified,);

		# Packaging data

		import_packaging_components(
			$args_ref, $imported_product_ref, $product_ref, $stats_ref,
			\$modified, \@modified_fields, \$differing, \%differing_fields,
			\%packagings_edited, $time,
		);

		# Compute extra stats

		if ((defined $stats_ref->{products_info_added}{$code}) or (defined $stats_ref->{products_info_changed}{$code}))
		{
			$stats_ref->{products_info_updated}{$code} = 1;
		}
		else {
			$stats_ref->{products_info_not_updated}{$code} = 1;
		}

		if (   (defined $stats_ref->{products_nutrition_added}{$code})
			or (defined $stats_ref->{products_nutrition_changed}{$code}))
		{
			$stats_ref->{products_nutrition_updated}{$code} = 1;
		}
		else {
			$stats_ref->{products_nutrition_not_updated}{$code} = 1;
		}

		if (   (defined $stats_ref->{products_info_updated}{$code})
			or (defined $stats_ref->{products_nutrition_updated}{$code})
			or (defined $stats_ref->{products_nutrition_data_per_updated}{$code}))
		{
			$stats_ref->{products_data_updated}{$code} = 1;
		}
		else {
			$stats_ref->{products_data_not_updated}{$code} = 1;
		}

		if (not defined $stats_ref->{products_with_info}{$code}) {
			$stats_ref->{products_without_info}{$code} = 1;
		}
		if (not defined $stats_ref->{products_with_ingredients}{$code}) {
			$stats_ref->{products_without_ingredients}{$code} = 1;
		}
		if (not defined $stats_ref->{products_with_nutrition}{$code}) {
			$stats_ref->{products_without_nutrition}{$code} = 1;
		}

		if (   (defined $stats_ref->{products_with_info}{$code})
			or (defined $stats_ref->{products_with_nutrition}{$code})
			or (defined $stats_ref->{products_with_nutrition_prepared}{$code}))
		{
			$stats_ref->{products_with_data}{$code} = 1;
		}
		else {
			$stats_ref->{products_without_data}{$code} = 1;
		}

		if ($modified and not $stats_ref->{products_data_updated}{$code}) {
			print STDERR "Error: modified but not products_data_updated\n";
		}

		if ((not $modified) and $stats_ref->{products_data_updated}{$code}) {
			print STDERR "Error: not modified but products_data_updated\n";
		}

		if ($code ne $product_ref->{code}) {
			$log->error(
				"Error - code not the same as product_ref->{code}",
				{
					i => $i,
					code => $code,
					product_ref_code => $product_ref->{code},
					imported_product_ref => $imported_product_ref
				}
			) if $log->is_error();
			next;
		}

		# Skip further processing if we have not modified any of the fields

		$log->debug("number of modifications", {code => $code, modified => $modified}) if $log->is_debug();
		if ($modified == 0) {
			$log->debug("skipping - no modifications", {code => $code}) if $log->is_debug();
			$stats_ref->{products_data_not_updated}{$code} = 1;
		}
		elsif (($args_ref->{skip_products_without_info}) and ($stats_ref->{products_without_info}{$code})) {
			$log->debug("skipping - product without info and --skip_products_without_info", {code => $code})
				if $log->is_debug();
		}
		else {
			$log->debug("updating product", {code => $code, modified => $modified}) if $log->is_debug();
			$stats_ref->{products_data_updated}{$code} = 1;

			analyze_and_enrich_product_data($product_ref, $response_ref);

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
				defined $args_ref->{source_licence_url}
					and $source_ref->{source_licence_url} = $args_ref->{source_licence_url};

				push @{$product_ref->{sources}}, $source_ref;
			}

			if (not $args_ref->{test}) {

				# set the autoexport field if the org is auto exported to the public platform
				if (    (defined $server_options{private_products})
					and ($server_options{private_products})
					and (defined $org_ref)
					and ($org_ref->{"activate_automated_daily_export_to_public_platform"}))
				{
					$product_ref->{to_be_automatically_exported} = 1;
				}
				else {
					delete $product_ref->{to_be_automatically_exported};
				}

				$log->debug("storing product",
					{code => $code, product_id => $product_id, org_id => $org_id, Owner_id => $Owner_id})
					if $log->is_debug();

				store_product($user_id, $product_ref, "Editing product (import) - " . ($product_comment || ""));

				push @edited, $code;
				$edited{$code}++;

				$stats_ref->{products_updated}{$code} = 1;

				$j++;
			}
		}

		# Images need to be updated after the product is saved (and possibly created)

		# Images can be specified as local paths to image files
		# e.g. from the producers platform

		foreach my $field (sort keys %{$imported_product_ref}) {

			next if $field !~ /^image_((front|ingredients|nutrition|packaging|other)(_\w\w)?(_\d+)?)_file/;

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

			next
				if $field
				!~ /^image_((?:front|ingredients|nutrition|packaging|other)(?:_[a-z]{2})?)_url(_[a-z]{2})?(\.[0-9]+)?$/;

			my $imagefield = $1 . ($2 || '');    # e.g. image_front_url_fr or image_front_url_fr -> front_fr
			my $number = $3;

			# If the imagefield is other, and we have a value for image_other_type, try to identify the imagefield
			if ($imagefield eq "other") {
				my $image_other_type_field = "image_other_type";
				if (defined $number) {
					$image_other_type_field .= $number;
				}

				if ($imported_product_ref->{$image_other_type_field}) {
					my $type_imagefield
						= get_imagefield_from_string($product_ref->{lc},
						$imported_product_ref->{$image_other_type_field});
					$log->debug(
						"imagefield is other, tried to guess with image_other_type",
						{
							imagefield => $imagefield,
							type_imagefield => $type_imagefield,
							image_other_type => $imported_product_ref->{$image_other_type_field}
						}
					) if $log->is_debug();
					$imagefield = $type_imagefield;
				}
			}

			$log->debug("image file",
				{field => $field, imagefield => $imagefield, field_value => $imported_product_ref->{$field}})
				if $log->is_debug();

			next if !defined $imported_product_ref->{$field};

			# We may have several URLs separated by commas
			foreach my $image_url (split(/\s*,\s*/, $imported_product_ref->{$field})) {

				if ($image_url =~ /^http/) {

					# Create a local filename from the url

					# https://secure.equadis.com/Equadis/MultimediaFileViewer?key=49172280_A8E8029F60B478AE56CFA5A87B7E0F4C&idFile=1502347&file=10144/08710522680612_C8N1_s35.png
					# https://nestlecontenthub-dam.esko-saas.com/mediabeacon/servlet/dload?apikey=3FB047E2-3E1B-4177-AF64-3999E0543B78&id=202078864&filename=08593893749702_A1L1_s03.jpg

					my $filename = $image_url;
					$filename =~ s/.*\///;
					$filename =~ s/.*(file|filename=)//i;
					$filename =~ s/[^A-Za-z0-9-_\.]/_/g;

					# If the filename does not include the product code, prefix it
					if ($filename !~ /$code/) {

						$filename = $code . "_" . $filename;
					}

					# Add a hash of the URL
					my $md5 = md5_hex($image_url);
					$filename = $md5 . "_" . $filename;

					my $images_download_dir = $args_ref->{images_download_dir};

					if ((defined $images_download_dir) and ($images_download_dir ne '')) {
						if (not -d $images_download_dir) {
							$log->debug("Creating images_download_dir", {images_download_dir => $images_download_dir})
								if $log->is_debug();
							ensure_dir_created($images_download_dir)
								or $log->warn("Could not create images_download_dir",
								{images_download_dir => $images_download_dir, error => $!})
								if $log->is_warn();
						}

						my $file = $images_download_dir . "/" . $filename;

						# Skip PDF file has we have issues to convert them, and they are sometimes not images about the product
						# but multi-pages product sheets, certificates etc.
						if ($file =~ /\.pdf$/) {
							$log->debug("skipping PDF file", {file => $file, imagefield => $imagefield, code => $code})
								if $log->is_debug();
						}
						# Check if the image exists
						elsif (-e $file) {

							$log->debug("we already have downloaded image file", {file => $file}) if $log->is_debug();

							# Is the image readable?
							my $magick = Image::Magick->new();
							my $imagemagick_error = $magick->Read($file);
							# we can get a warning that we can ignore: "Exception 365: CorruptImageProfile `xmp' "
							# see https://github.com/openfoodfacts/openfoodfacts-server/pull/4221
							if (($imagemagick_error) and ($imagemagick_error =~ /(\d+)/) and ($1 >= 400)) {
								$log->warn("cannot read existing image file",
									{error => $imagemagick_error, file => $file})
									if $log->is_warn();
								unlink($file);
							}
							# If the product has an images field, assume that the image has already been uploaded
							# otherwise, upload it
							# This can happen when testing: we download the images once, then delete the products and reimport them again
							elsif (not defined $product_ref->{images}) {
								# Assign the download image to the field

								# We may have multiple images for the other field, in that case give them an imagefield of other.2, other.3 etc.
								my $new_imagefield = $imagefield;
								if (defined $images_ref->{$code}{$new_imagefield}) {
									my $image_number = 2;
									while (defined $images_ref->{$code}{$imagefield . '.' . $image_number}) {
										$image_number++;
									}
									$new_imagefield = $imagefield . '.' . $image_number;
								}

								$log->debug("assigning image file", {new_imagefield => $new_imagefield, file => $file})
									if $log->is_debug();
								(defined $images_ref->{$code}) or $images_ref->{$code} = {};
								$images_ref->{$code}{$new_imagefield} = $file;
							}
						}
						else {
							# Download the image

							# We can try to transform some URLs to get the full size image instead of preview thumbs

							my @image_urls = ($image_url);

							# https://secure.equadis.com/Equadis/MultimediaFileViewer?thumb=true&idFile=601231&file=10210/8076800105735.JPG
							# -> remove thumb=true to get the full image

							$image_url =~ s/thumb=true&//;

							# https://www.elle-et-vire.com/uploads/cache/400x400/uploads/recip/product_media/108/3451790013737-ev-bio-creme-epaisse-entiere-poche-33cl.png
							$image_url =~ s/\/uploads\/cache\/(\d+)x(\d+)\/uploads\//\/uploads\//;

							if ($image_url ne $image_urls[0]) {
								unshift @image_urls, $image_url;
							}

							my $downloaded_image = 0;

							while ((not $downloaded_image) and ($#image_urls >= 0)) {

								$image_url = shift(@image_urls);

								# http://www.Kimagesvc.com/03159470204634_A1N1.jpg
								# -> lowercase subdomain / domain

								my $uri = URI->new($image_url);
								$image_url = $uri->canonical;

								$log->debug("download image file", {file => $file, image_url => $image_url})
									if $log->is_debug();

								my $response = download_image($image_url);

								if ($response->is_success) {
									$log->debug("downloaded image file", {file => $file}) if $log->is_debug();
									open(my $out, ">", $file);
									print $out $response->decoded_content;
									close($out);

									# Is the image readable?
									my $magick = Image::Magick->new();
									my $imagemagick_error = $magick->Read($file);
									# we can get a warning that we can ignore: "Exception 365: CorruptImageProfile `xmp' "
									# see https://github.com/openfoodfacts/openfoodfacts-server/pull/4221
									if (($imagemagick_error) and ($imagemagick_error =~ /(\d+)/) and ($1 >= 400)) {
										$log->warn(
											"cannot read downloaded image file",
											{error => $imagemagick_error, file => $file}
										) if $log->is_warn();
										unlink($file);
									}
									else {
										# Assign the download image to the field

										# We may have multiple images for the other field, in that case give them an imagefield of other.2, other.3 etc.
										my $new_imagefield = $imagefield;
										if (defined $images_ref->{$code}{$new_imagefield}) {
											my $image_number = 2;
											while (defined $images_ref->{$code}{$imagefield . '.' . $image_number}) {
												$image_number++;
											}
											$new_imagefield = $imagefield . '.' . $image_number;
										}

										$log->debug("assigning image file",
											{new_imagefield => $new_imagefield, file => $file})
											if $log->is_debug();
										(defined $images_ref->{$code}) or $images_ref->{$code} = {};
										$images_ref->{$code}{$new_imagefield} = $file;

										$downloaded_image = 1;
									}
								}
								else {
									$log->debug("could not download image file", {file => $file, response => $response})
										if $log->is_debug();
								}
							}
						}
					}
					else {
						$log->warn("no image download dir specified", {}) if $log->is_warn();
					}
				}
			}
		}

		# Upload images

		if (defined $images_ref->{$code}) {

			$stats_ref->{products_with_images}{$code} = 1;

			if (    (not $args_ref->{test})
				and (not((defined $args_ref->{do_not_upload_images}) and ($args_ref->{do_not_upload_images}))))
			{

				$log->debug("uploading images for product", {code => $code}) if $log->is_debug();

				my $images_ref = $images_ref->{$code};

				# Keep track of the images we select so that we don't select multiple images for the same field
				my %selected_images = ();

				foreach my $imagefield (sort keys %{$images_ref}) {

					$log->debug("uploading image for product", {imagefield => $imagefield, code => $code})
						if $log->is_debug();

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

					# Skip PDF file has we have issues to convert them, and they are sometimes not images about the product
					# but multi-pages product sheets, certificates etc.
					if ($file =~ /\.pdf$/) {
						$log->debug("skipping PDF file", {file => $file, imagefield => $imagefield, code => $code})
							if $log->is_debug();
					}
					elsif (-e "$file") {
						$log->debug("found image file", {file => $file, imagefield => $imagefield, code => $code})
							if $log->is_debug();

						# upload a photo
						my $imgid;
						my $debug;
						my $return_code
							= process_image_upload($product_id, "$file", $user_id, undef, $product_comment, \$imgid,
							\$debug);
						$log->debug(
							"process_image_upload",
							{
								file => $file,
								imagefield => $imagefield,
								code => $code,
								return_code => $return_code,
								imgid => $imgid,
								imagefield_with_lc => $imagefield_with_lc,
								debug => $debug
							}
						) if $log->is_debug();

						if (($imgid > 0) and ($imgid > $current_max_imgid)) {
							$stats_ref->{products_images_added}{$code} = 1;
						}

						my $x1 = $imported_product_ref->{"image_" . $imagefield . "_x1"} || -1;
						my $y1 = $imported_product_ref->{"image_" . $imagefield . "_y1"} || -1;
						my $x2 = $imported_product_ref->{"image_" . $imagefield . "_x2"} || -1;
						my $y2 = $imported_product_ref->{"image_" . $imagefield . "_y2"} || -1;
						my $coordinates_image_size
							= $imported_product_ref->{"image_" . $imagefield . "_coordinates_image_size"} || $crop_size;
						my $angle = $imported_product_ref->{"image_" . $imagefield . "_angle"} || 0;
						my $normalize = $imported_product_ref->{"image_" . $imagefield . "_normalize"} || "false";
						my $white_magic = $imported_product_ref->{"image_" . $imagefield . "_white_magic"} || "false";

						$log->debug(
							"select and crop image?",
							{
								code => $code,
								imgid => $imgid,
								current_max_imgid => $current_max_imgid,
								imagefield_with_lc => $imagefield_with_lc,
								x1 => $x1,
								y1 => $y1,
								x2 => $x2,
								y2 => $y2,
								angle => $angle,
								normalize => $normalize,
								white_magic => $white_magic
							}
						) if $log->is_debug();

						# select the photo
						if (
							($imagefield_with_lc =~ /front|ingredients|nutrition|packaging/)
							and (
								(
									not(    (defined $args_ref->{only_select_not_existing_images})
										and ($args_ref->{only_select_not_existing_images}))
								)
								or (   (not defined $product_ref->{images})
									or (not defined $product_ref->{images}{$imagefield_with_lc}))
							)
							)
						{

							if (($imgid > 0) and ($imgid > $current_max_imgid)) {

								$log->debug(
									"assigning image imgid to imagefield_with_lc",
									{
										code => $code,
										current_max_imgid => $current_max_imgid,
										imgid => $imgid,
										imagefield_with_lc => $imagefield_with_lc,
										x1 => $x1,
										y1 => $y1,
										x2 => $x2,
										y2 => $y2,
										angle => $angle,
										normalize => $normalize,
										white_magic => $white_magic
									}
								) if $log->is_debug();
								$selected_images{$imagefield_with_lc} = 1;
								eval {
									process_image_crop($user_id, $product_id, $imagefield_with_lc, $imgid, $angle,
										$normalize, $white_magic, $x1, $y1, $x2, $y2, $coordinates_image_size);
								};
								# $modified++;

							}
							else {
								$log->debug(
									"returned imgid $imgid not greater than the previous max imgid: $current_max_imgid",
									{imgid => $imgid, current_max_imgid => $current_max_imgid}
								) if $log->is_debug();

								# overwrite already selected images
								# if the selected image is not the same
								# or if we have non null crop coordinates that differ
								if (
										($imgid > 0)
									and (exists $product_ref->{images})
									and (
										(not exists $product_ref->{images}{$imagefield_with_lc})
										or (
											(
												   ($product_ref->{images}{$imagefield_with_lc}{imgid} != $imgid)
												or
												(($x1 > 1) and ($product_ref->{images}{$imagefield_with_lc}{x1} != $x1))
												or
												(($x2 > 1) and ($product_ref->{images}{$imagefield_with_lc}{x2} != $x2))
												or
												(($y1 > 1) and ($product_ref->{images}{$imagefield_with_lc}{y1} != $y1))
												or
												(($y2 > 1) and ($product_ref->{images}{$imagefield_with_lc}{y2} != $y2))
												or ($product_ref->{images}{$imagefield_with_lc}{angle} != $angle)
											)
										)
									)
									)
								{
									$log->debug(
										"re-assigning image imgid to imagefield_with_lc",
										{
											code => $code,
											imgid => $imgid,
											imagefield_with_lc => $imagefield_with_lc,
											x1 => $x1,
											y1 => $y1,
											x2 => $x2,
											y2 => $y2,
											coordinates_image_size => $coordinates_image_size,
											angle => $angle,
											normalize => $normalize,
											white_magic => $white_magic
										}
									) if $log->is_debug();
									$selected_images{$imagefield_with_lc} = 1;
									eval {
										process_image_crop($user_id, $product_id, $imagefield_with_lc, $imgid, $angle,
											$normalize, $white_magic, $x1, $y1, $x2, $y2, $coordinates_image_size);
									};
									# $modified++;
								}

							}
						}
						# If the image type is "other" and we don't have a front image, assign it
						# This is in particular for producers that send us many images without specifying their type: assume the first one is the front
						elsif ( ($imgid > 0)
							and ($imagefield_with_lc =~ /^other/)
							and (not defined $product_ref->{images}{"front_" . $product_ref->{lc}})
							and (not defined $selected_images{"front_" . $product_ref->{lc}}))
						{
							$log->debug(
								"selecting front image as we don't have one",
								{
									imgid => $imgid,
									imagefield => $imagefield,
									front_imagefield => "front_" . $product_ref->{lc},
									x1 => $x1,
									y1 => $y1,
									x2 => $x2,
									y2 => $y2,
									coordinates_image_size => $coordinates_image_size,
									angle => $angle,
									normalize => $normalize,
									white_magic => $white_magic
								}
							) if $log->is_debug();
							# Keep track that we have selected an image, so that we don't select another one after,
							# as we don't reload the product_ref after calling process_image_crop()
							$selected_images{"front_" . $product_ref->{lc}} = 1;
							eval {
								process_image_crop($user_id, $product_id, "front_" . $product_ref->{lc},
									$imgid, $angle, $normalize, $white_magic, $x1, $y1, $x2, $y2,
									$coordinates_image_size);
							};
						}
					}
					else {
						$log->debug("did not find image file",
							{file => $file, imagefield => $imagefield, code => $code})
							if $log->is_debug();
					}
				}
			}
		}
		else {
			$log->debug("no images for product", {code => $code}) if $log->is_debug();
			$stats_ref->{products_without_images}{$code} = 1;
		}

		undef $product_ref;
	}

	$log->debug(
		"import done",
		{
			products => $i,
			new_products => $new,
			existing_products => $existing,
			differing_products => $differing,
			differing_fields => \%differing_fields
		}
	) if $log->is_debug();

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

	return $stats_ref;
}

=head2 update_export_status_for_csv_file( ARGUMENTS )

Once products from a CSV file have been exported from the producers platform
and imported on the public platform, update_export_status_for_csv_file()
marks them as exported on the producers platform.

=head3 Arguments

Arguments are passed through a single hash reference with the following keys:

=head4 user_id - required

User id to which the changes (new products, added or changed values, new images)
will be attributed.

=head4 org_id - optional

Organization id to which the changes (new products, added or changed values, new images)
will be attributed.

=head4 owner_id - optional

For databases with private products, owner (user or org) that the products belong to.
Values are of the form user-[user id] or org-[organization id].

If not set, for databases with private products, it will be constructed from the user_id
and org_id parameters.

The owner can be overrode if the CSV file contains a org_name field.
In that case, the owner is set to the value of the org_name field, and
a new org is created if it does not exist yet.

=head4 csv_file - required

Path and file name of the CSV file to import.

The CSV file needs to be in the Open Food Facts CSV format, encoded in UTF-8
with tabs as separators.

=head4 exported_t - required

Time of the export.

=cut

sub update_export_status_for_csv_file ($args_ref) {

	$User_id = $args_ref->{user_id};
	$Org_id = $args_ref->{org_id};
	$Owner_id = get_owner_id($User_id, $Org_id, $args_ref->{owner_id});

	$log->debug("starting update_export_status_for_csv_file",
		{User_id => $User_id, Org_id => $Org_id, Owner_id => $Owner_id})
		if $log->is_debug();

	my $csv = Text::CSV->new({binary => 1, sep_char => "\t"})    # should set binary attribute.
		or die "Cannot use CSV: " . Text::CSV->error_diag();

	my $i = 0;

	$log->debug("updating export status for products", {}) if $log->is_debug();

	open(my $io, '<:encoding(UTF-8)', $args_ref->{csv_file}) or die("Could not open " . $args_ref->{csv_file} . ": $!");

	my $columns_ref = $csv->getline($io);
	$csv->column_names(@{deduped_colnames($columns_ref)});

	while (my $imported_product_ref = $csv->getline_hr($io)) {

		$i++;

		# By default, use the orgid passed in the arguments
		# it may be overridden later on a per product basis
		my $org_id = $args_ref->{org_id};

		# The option import_owner is used when exporting from the producers database to the public database
		if (    ($args_ref->{import_owner})
			and (defined $imported_product_ref->{owner})
			and ($imported_product_ref->{owner} =~ /^org-(.+)$/))
		{
			$org_id = $1;
			$Owner_id = "org-" . $org_id;
		}

		my $code = $imported_product_ref->{code};
		$code = normalize_code($code);
		my $product_id = product_id_for_owner($Owner_id, $code);

		$log->debug("update export status for product", {i => $i, code => $code, product_id => $product_id})
			if $log->is_debug();

		if ($code eq '') {
			$log->error("Error - empty code",
				{i => $i, code => $code, product_id => $product_id, imported_product_ref => $imported_product_ref})
				if $log->is_error();
			next;
		}

		if ($code !~ /^\d\d\d\d\d\d\d\d(\d*)$/) {
			$log->error("Error - code not a number with 8 or more digits",
				{i => $i, code => $code, product_id => $product_id, imported_product_ref => $imported_product_ref})
				if $log->is_error();
			next;
		}

		my $product_ref = retrieve_product($product_id);

		if (defined $product_ref) {
			$product_ref->{last_exported_t} = $args_ref->{exported_t};
			if ($product_ref->{last_exported_t} > $product_ref->{last_modified_t}) {
				add_tag($product_ref, "states", "en:exported");
				remove_tag($product_ref, "states", "en:to-be-exported");
				remove_tag($product_ref, "states", "en:to-be-automatically-exported");
			}
			else {
				add_tag($product_ref, "states", "en:to-be-exported");
				remove_tag($product_ref, "states", "en:exported");
			}
			$product_ref->{states} = join(',', @{$product_ref->{states_tags}});
			compute_field_tags($product_ref, $product_ref->{lc}, "states");

			# Update the product without creating a new revision
			my $path = product_path($product_ref);
			store("$BASE_DIRS{PRODUCTS}/$path/product.sto", $product_ref);
			$product_ref->{code} = $product_ref->{code} . '';
			# Use the obsolete collection if the product is obsolete
			my $products_collection = get_products_collection({obsolete => $product_ref->{obsolete}});
			$products_collection->replace_one({"_id" => $product_ref->{_id}}, $product_ref, {upsert => 1});
		}
	}

	$log->debug("update export status done", {products => $i}) if $log->is_debug();

	print STDERR "\n\nupdate export status done\n\n";
	return;
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

Organization id to which the changes (new products, added or changed values, new images)
will be attributed.

=head4 owner_id - required

Owner of the products on the producers platform.

=cut

sub import_products_categories_from_public_database ($args_ref) {

	my $user_id = $args_ref->{user_id};
	$Org_id = $args_ref->{org_id};
	$Owner_id = get_owner_id($User_id, $Org_id, $args_ref->{owner_id});

	my $query_ref = {owner => $Owner_id};

	my $products_collection = get_products_collection();

	my $cursor = $products_collection->query($query_ref)->fields({_id => 1, code => 1, owner => 1});
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
			print STDERR "code field undefined for product id: "
				. $product_ref->{id}
				. " _id: "
				. $product_ref->{_id} . "\n";
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
				$log->debug("import_product_categories - unable to load public product file",
					{code => $code, file => $file})
					if $log->is_debug();
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
						$tagid = get_taxonomyid($imported_product_ref->{lc},
							canonicalize_taxonomy_tag($imported_product_ref->{lc}, $field, $tag));
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
					$log->debug("import_product_categories - new categories", {categories => $product_ref->{$field}})
						if $log->is_debug();
					compute_field_tags($product_ref, $product_ref->{lc}, $field);
					if ((defined $options{product_type}) and ($options{product_type} eq "food")) {
						$log->debug("Food::special_process_product") if $log->is_debug();
						ProductOpener::Food::special_process_product($product_ref);
					}
					compute_nutriscore($product_ref);
					compute_nova_group($product_ref);
					compute_nutrient_levels($product_ref);
					compute_unknown_nutrients($product_ref);
					ProductOpener::DataQuality::check_quality($product_ref);
					store_product($user_id, $product_ref, "imported categories from public database");
				}

			}
			else {
				$log->debug("import_product_categories - unable to load private product file", {code => $code})
					if $log->is_debug();
			}
		}

		$n++;
	}

	return;
}

1;

