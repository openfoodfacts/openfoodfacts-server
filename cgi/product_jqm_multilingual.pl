#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use Modern::Perl '2017';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::SiteQuality qw/:all/;


use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Log::Any qw($log);

ProductOpener::Display::init();

my $comment = '(app)';

my $interface_version = '20150316.jqm2';

my %response = ();

my $code = normalize_code(param('code'));

$log->debug("start", { code => $code, lc => $lc }) if $log->is_debug();

if ($code !~ /^\d+$/) {

	$log->info("invalid code", { code => $code }) if $log->is_info();
	$response{status} = 0;
	$response{status_verbose} = 'no code or invalid code';

}
else {

	my $product_ref = retrieve_product($code);
	if (not defined $product_ref) {
		$product_ref = init_product($code);
		$product_ref->{interface_version_created} = $interface_version;
	}


	# Process edit rules

	$log->debug("phase 0 - checking edit rules", { code => $code}) if $log->is_debug();

	my $proceed_with_edit = process_product_edit_rules($product_ref);

	$log->debug("phase 0", { code => $code, proceed_with_edit => $proceed_with_edit }) if $log->is_debug();

	if (not $proceed_with_edit) {

		$response{status} = 0;
		$response{status_verbose} = 'Edit against edit rules';


		my $data =  encode_json(\%response);

		print header( -type => 'application/json', -charset => 'utf-8' ) . $data;

		exit(0);

	}

	exists $product_ref->{new_server} and delete $product_ref->{new_server};

	my @errors = ();

	# 26/01/2017 - disallow barcode changes until we fix bug #677
	if ($admin and (defined param('new_code'))) {

		change_product_server_or_code($product_ref, param('new_code'), \@errors);
		$code = $product_ref->{code};
	}

	#my @app_fields = qw(product_name brands quantity);
	my @app_fields = qw(product_name generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link expiration_date purchase_places stores countries  );

	# admin field to set a creator
	if (($User_id eq 'stephane') or ($User_id eq 'teolemon')) {
		push @app_fields, "creator";
	}

	# generate a list of potential languages for language specific fields
	my %param_langs = ();
	foreach my $param (param()) {
		if ($param =~ /^(.*)_(\w\w)$/) {
			if (defined $language_fields{$1}) {
				$param_langs{$2} = 1;
			}
		}
		# some apps may send pt-BR
		elsif ($param =~ /^(.*)_(\w\w)-(\w\w)$/) {
			if (defined $language_fields{$1}) {
				$param_langs{$2} = 1;
				# set the product_name_pt value to the value of product_name_pt-BR
				param($1 . "_" . $2, param($1 . "_" . $2 . "-" . $3));
			}
		}
	}
	my @param_langs = keys %param_langs;

	# 01/06/2019 --> Yuka always sends fr fields even for Spanish products, try to correct it

	if ((defined $User_id) and ($User_id eq 'kiliweb') and (defined param('cc'))) {

		my $param_cc = lc(param('cc'));
		$param_cc =~ s/^en://;

		my %lc_overrides = (
				au => "en",
				br => "pt",
				co => "es",
				es => "es",
				it => "it",
				de => "de",
				uk => "en",
				gb => "en",
				pt => "pt",
				nl => "nl",
				no => "no",
				us => "en",
				ie => "en",
				nz => "en",
		);

		if (defined $lc_overrides{$param_cc}) {
			$lc = $lc_overrides{$param_cc};
		}
	}

	foreach my $field (@app_fields, 'nutrition_data_per', 'serving_size', 'traces', 'ingredients_text','lang') {




		# 11/6/2018 --> force add_brands and add_countries for yuka / kiliweb
		if ((defined $User_id) and ($User_id eq 'kiliweb')
			and (defined param($field))
			and (($field eq 'brands') or ($field eq 'countries'))) {

			param(-name => "add_" . $field, -value => param($field));
			print STDERR "product_jqm_multilingual.pm - yuka / kiliweb - force $field -> add_$field - code: $code\n";

		}

		# add_brands=additional brand : only add if it does not exist yet
		if ((defined $tags_fields{$field}) and (defined param("add_$field"))) {

			my $additional_fields = remove_tags_and_quote(decode utf8=>param("add_$field"));

			add_tags_to_field($product_ref, $lc, $field, $additional_fields);

			print STDERR "product_jqm_multilingual.pl - lc: $lc - adding value to field $field - additional: $additional_fields - existing: $product_ref->{$field}\n";

			compute_field_tags($product_ref, $lc, $field);

		}

		elsif (defined param($field)) {

			# Do not allow edits / removal through API for data provided by producers (only additions for non existing fields)
			if ((has_tag($product_ref,"data_sources","producers")) and (defined $product_ref->{$field}) and ($product_ref->{$field} ne "")) {
				print STDERR "product_jqm_multilingual.pm - code: $code - producer data already exists for field $field\n";
			}
			else {
				$product_ref->{$field} = remove_tags_and_quote(decode utf8=>param($field));

				if ((defined $language_fields{$field}) and (defined $product_ref->{lc})) {
					my $field_lc = $field . "_" . $product_ref->{lc};
					$product_ref->{$field_lc} = $product_ref->{$field};
				}

				compute_field_tags($product_ref, $lc, $field);
			}
		}

		if (defined $language_fields{$field}) {

			foreach my $param_lang (@param_langs) {
				my $field_lc = $field . '_' . $param_lang;
				if (defined param($field_lc)) {

					# Do not allow edits / removal through API for data provided by producers (only additions for non existing fields)
					if ((has_tag($product_ref,"data_sources","producers")) and (defined $product_ref->{$field_lc}) and ($product_ref->{$field_lc} ne "")) {
						print STDERR "product_jqm_multilingual.pm - code: $code - producer data already exists for field $field_lc\n";
					}
					else {

						$product_ref->{$field_lc} = remove_tags_and_quote(decode utf8=>param($field_lc));
						compute_field_tags($product_ref, $lc, $field_lc);
					}
				}
			}
		}
	}


	# Food category rules for sweeetened/sugared beverages
	# French PNNS groups from categories

	if ($server_domain =~ /openfoodfacts/) {
		ProductOpener::Food::special_process_product($product_ref);
	}


	if ((defined $product_ref->{nutriments}{"carbon-footprint"}) and ($product_ref->{nutriments}{"carbon-footprint"} ne '')) {
		push @{$product_ref->{"labels_hierarchy" }}, "en:carbon-footprint";
		push @{$product_ref->{"labels_tags" }}, "en:carbon-footprint";
	}

	# Language and language code / subsite

	if (defined $product_ref->{lang}) {
		# strip variants fr-BE fr_BE
		$product_ref->{lang} =~ s/^([a-z][a-z])(-|_).*/$1/ig;
		$product_ref->{lang} = lc($product_ref->{lang});
		$product_ref->{lc} = $product_ref->{lang};
	}

	if (not defined $lang_lc{$product_ref->{lc}}) {
		$product_ref->{lc} = 'xx';
	}


	# For fields that can have different values in different languages, copy the main language value to the non suffixed field

	foreach my $field (keys %language_fields) {
		if ($field !~ /_image/) {
			if (defined $product_ref->{$field . "_$product_ref->{lc}"}) {
				$product_ref->{$field} = $product_ref->{$field . "_$product_ref->{lc}"};
			}
		}
	}

	compute_languages($product_ref); # need languages for allergens detection and cleaning ingredients

	# Ingredients classes
	clean_ingredients_text($product_ref);
	extract_ingredients_from_text($product_ref);
	extract_ingredients_classes_from_text($product_ref);
	detect_allergens_from_text($product_ref);
	compute_carbon_footprint_from_ingredients($product_ref);
	compute_carbon_footprint_from_meat_or_fish($product_ref);

	# Nutrition data

	# Do not allow nutrition edits through API for data provided by producers
	if ((has_tag($product_ref,"data_sources","producers")) and (defined $product_ref->{"nutriments"})) {
		print STDERR "product_jqm_multilingual.pm - code: $code - nutrition data provided by producer exists, skip nutrients\n";
	}
	else {

		if (defined param("no_nutrition_data")) {
			$product_ref->{no_nutrition_data} = remove_tags_and_quote(decode utf8=>param("no_nutrition_data"));
		}

		my $no_nutrition_data = 0;
		if ((defined $product_ref->{no_nutrition_data}) and ($product_ref->{no_nutrition_data} eq 'on')) {
			$no_nutrition_data = 1;
		}

		defined $product_ref->{nutriments} or $product_ref->{nutriments} = {};

		my @unknown_nutriments = ();
		foreach my $nid (sort keys %{$product_ref->{nutriments}}) {
			next if $nid =~ /_/;
			if ((not exists $Nutriments{$nid}) and (defined $product_ref->{nutriments}{$nid . "_label"})) {
				push @unknown_nutriments, $nid;
				$log->debug("unknown nutrient", { nid => $nid }) if $log->is_debug();
			}
		}

		my @new_nutriments = ();
		my $new_max = remove_tags_and_quote(param('new_max'));
		for (my $i = 1; $i <= $new_max; $i++) {
			push @new_nutriments, "new_$i";
		}

		# fix_salt_equivalent always prefers the 'salt' value of the product by default
		# the 'sodium' value should be preferred, though, if the 'salt' parameter is not
		# present. Therefore, delete the 'salt' value and let it be fixed by
		# fix_salt_equivalent afterwards.
		foreach my $product_type ("", "_prepared") {
			my $saltnid = "salt${product_type}";
			my $sodiumnid = "sodium${product_type}";

			my $salt = param("nutriment_${saltnid}");
			my $sodium = param("nutriment_${sodiumnid}");

			if (((not defined $salt) or ($salt eq ''))
				and (defined $sodium) and ($sodium ne ''))
			{
				delete $product_ref->{nutriments}{$saltnid};
				delete $product_ref->{nutriments}{$saltnid . "_unit"};
				delete $product_ref->{nutriments}{$saltnid . "_value"};
				delete $product_ref->{nutriments}{$saltnid . "_modifier"};
				delete $product_ref->{nutriments}{$saltnid . "_label"};
				delete $product_ref->{nutriments}{$saltnid . "_100g"};
				delete $product_ref->{nutriments}{$saltnid . "_serving"};
			}
		}

		foreach my $nutriment (@{$nutriments_tables{$nutriment_table}}, @unknown_nutriments, @new_nutriments) {
			next if $nutriment =~ /^\#/;

			my $nid = $nutriment;
			$nid =~ s/^(-|!)+//g;
			$nid =~ s/-$//g;

			next if $nid =~ /^nutrition-score/;

			my $enid = encodeURIComponent($nid);

			# do not delete values if the nutriment is not provided
			next if not defined param("nutriment_${enid}");

			my $value = remove_tags_and_quote(decode utf8=>param("nutriment_${enid}"));
			my $unit = remove_tags_and_quote(decode utf8=>param("nutriment_${enid}_unit"));
			my $label = remove_tags_and_quote(decode utf8=>param("nutriment_${enid}_label"));

			my $modifier = undef;

			normalize_nutriment_value_and_modifier(\$value, \$modifier);

			# New label?
			my $new_nid = undef;
			if ((defined $label) and ($label ne '')) {
				$new_nid = canonicalize_nutriment($lc,$label);
				$log->debug("unknown nutrient", { nid => $nid, lc => $lc, canonicalize_nutriment => $new_nid }) if $log->is_debug();

				if ($new_nid ne $nid) {
					delete $product_ref->{nutriments}{$nid};
					delete $product_ref->{nutriments}{$nid . "_unit"};
					delete $product_ref->{nutriments}{$nid . "_value"};
					delete $product_ref->{nutriments}{$nid . "_modifier"};
					delete $product_ref->{nutriments}{$nid . "_label"};
					delete $product_ref->{nutriments}{$nid . "_100g"};
					delete $product_ref->{nutriments}{$nid . "_serving"};
					$log->debug("unknown nutrient, but known canonical new id", { nid => $nid, lc => $lc, canonicalize_nutriment => $new_nid }) if $log->is_debug();
					$nid = $new_nid;
				}
				$product_ref->{nutriments}{$nid . "_label"} = $label;
			}

			if (($nid eq '') or (not defined $value) or ($value eq '')) {
					delete $product_ref->{nutriments}{$nid};
					delete $product_ref->{nutriments}{$nid . "_unit"};
					delete $product_ref->{nutriments}{$nid . "_value"};
					delete $product_ref->{nutriments}{$nid . "_modifier"};
					delete $product_ref->{nutriments}{$nid . "_label"};
					delete $product_ref->{nutriments}{$nid . "_100g"};
					delete $product_ref->{nutriments}{$nid . "_serving"};
			}
			else {
				assign_nid_modifier_value_and_unit($product_ref, $nid, $modifier, $value, $unit);
			}
		}

		if ($no_nutrition_data) {
			# Delete all non-carbon-footprint nids.
			foreach my $key (keys %{$product_ref->{nutriments}}) {
				next if $key =~ /_/;
				next if $key eq 'carbon-footprint';

				delete $product_ref->{nutriments}{$key};
				delete $product_ref->{nutriments}{$key . "_unit"};
				delete $product_ref->{nutriments}{$key . "_value"};
				delete $product_ref->{nutriments}{$key . "_modifier"};
				delete $product_ref->{nutriments}{$key . "_label"};
				delete $product_ref->{nutriments}{$key . "_100g"};
				delete $product_ref->{nutriments}{$key . "_serving"};
			}
		}
	}


	# Compute nutrition data per 100g and per serving

	$log->trace("compute_serving_size_date") if ($admin and $log->is_trace());

	fix_salt_equivalent($product_ref);

	compute_serving_size_data($product_ref);

	compute_nutrition_score($product_ref);

	compute_nova_group($product_ref);

	compute_nutrient_levels($product_ref);

	compute_unknown_nutrients($product_ref);

	ProductOpener::SiteQuality::check_quality($product_ref);


	$log->info("saving product", { code => $code }) if ($log->is_info() and not $log->is_debug());
	$log->debug("saving product", { code => $code, product => $product_ref }) if ($log->is_debug() and not $log->is_info());

	$product_ref->{interface_version_modified} = $interface_version;


	my $time = time();
	$comment = $comment . remove_tags_and_quote(decode utf8=>param('comment'));
	if (store_product($product_ref, $comment)) {
		# Notify robotoff
		send_notification_for_product_change($product_ref, "updated");

		$response{status} = 1;
		$response{status_verbose} = 'fields saved';
	}
	else {
		$response{status} = 0;
		$response{status_verbose} = 'not modified';
	}
}

my $data =  encode_json(\%response);

print header( -type => 'application/json', -charset => 'utf-8' ) . $data;


exit(0);

