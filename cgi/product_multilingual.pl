#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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

use Modern::Perl '2012';
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
use ProductOpener::URL qw/:all/;
use ProductOpener::SiteQuality qw/:all/;

use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form escapeHTML :cgi-lib/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Log::Any qw($log);

ProductOpener::Display::init();

if ($User_id eq 'unwanted-user-french') { 
	display_error("<b>Il y a des problèmes avec les modifications de produits que vous avez effectuées. Ce compte est temporairement bloqué, merci de nous contacter.</b>", 403);
}



sub normalize_nutriment_value_and_modifier($$) {
		
	my $value_ref = shift;
	my $modifier_ref = shift;
	
	if ($$value_ref =~ /nan/i) {
		$$value_ref = '';
	}		
	
	if ($$value_ref =~ /(\&lt;=|<=|\N{U+2264})( )?/) {
		$$value_ref =~ s/(\&lt;=|<=|\N{U+2264})( )?//;
		$modifier_ref = "\N{U+2264}";
	}
	if ($$value_ref =~ /(\&lt;|<|max|maxi|maximum|inf|inférieur|inferieur|less)( )?/) {
		$$value_ref =~ s/(\&lt;|<|min|minimum|max|maxi|maximum|environ)( )?//;
		$$modifier_ref = '<';
	}
	if ($$value_ref =~ /(\&gt;=|>=|\N{U+2265})/) {
		$$value_ref =~ s/(\&gt;=|>=|\N{U+2265})( )?//;
		$modifier_ref = "\N{U+2265}";
	}
	if ($$value_ref =~ /(\&gt;|>|min|mini|minimum|greater|more)/) {
		$$value_ref =~ s/(\&gt;|>|min|mini|minimum|greater|more)( )?//;
		$$modifier_ref = '>';
	}
	if ($$value_ref =~ /(env|environ|about|~|≈)/) {
		$$value_ref =~ s/(env|environ|about|~|≈)( )?//;
		$$modifier_ref = '~';
	}			
	if ($$value_ref =~ /trace|traces/) {
		$$value_ref = 0;
		$$modifier_ref = '~';
	}
	if ($$value_ref !~ /\./) {
		$$value_ref =~ s/,/\./;
	}
}



my $type = param('type') || 'search_or_add';
my $action = param('action') || 'display';

my $comment = 'Modification : ';

my @errors = ();

my $html = '';
my $code = normalize_code(param('code'));

my $product_ref = undef;

my $interface_version = '20120622';

local $log->context->{type} = $type;
local $log->context->{action} = $action;

# Search or add product
if ($type eq 'search_or_add') {

	# barcode in image?
	my $filename;
	if ((not defined $code) or ($code !~ /^\d+$/)) {
		$code = process_search_image_form(\$filename);
	}
	
	my $r = Apache2::RequestUtil->request();
	my $method = $r->method();
	if ((not defined $code) and ((not defined param("imgupload_search")) or ( param("imgupload_search") eq '')) and ($method eq 'POST')) {
		$code = 2000000000001; # Codes beginning with 2 are for internal use
		
		my $internal_code_ref = retrieve("$data_root/products/internal_code.sto");
		if ((defined $internal_code_ref) and ($$internal_code_ref > $code)) {
			$code = $$internal_code_ref;
		}
		
		while (-e ("$data_root/products/" . product_path($code))) {
		
			$code++;
		}
		
		store("$data_root/products/internal_code.sto", \$code);
		
	}
	
	my %data = ();
	my $location;
	
	if (defined $code) {
		$data{code} = $code;
		$log->debug("we have a code", { code => $code }) if $log->is_debug();
		
		$product_ref = product_exists($code); # returns 0 if not
		
		if ($product_ref) {
			$log->info("product exists, redirecting to page", { code => $code }) if $log->is_info();
			$location = product_url($product_ref);
			
			# jquery.fileupload ?
			if (param('jqueryfileupload')) {
				
				$type = 'show';
			}
			else {
				my $r = shift;
				$r->headers_out->set(Location =>$location);
				$r->status(301);  
				return 301;
			}
		}
		else {
			$log->info("product does not exist, creating product", { code => $code }) if $log->is_info();
			$product_ref = init_product($code);
			$product_ref->{interface_version_created} = $interface_version;
			store_product($product_ref, 'product_created');
			my $imgid;
			process_image_upload($code,$filename,$User_id, time(),'image with barcode from web site Add product button',\$imgid);
			$type = 'add';
			$action = 'display';
			$location = "/cgi/product.pl?type=add&code=$code";
		}
	}
	else {
		if (defined param("imgupload_search")) {
			$log->info("no code found in image") if $log->is_info();
			$data{error} = lang("image_upload_error_no_barcode_found_in_image_short");
			$html .= lang("image_upload_error_no_barcode_found_in_image_long");
		}
		else {
			$log->info("no code found in text") if $log->is_info();
			$html .= lang("image_upload_error_no_barcode_found_in_text");
		}
	}
	
	$data{type} = $type;
	$data{location} = $location;
	
	# jquery.fileupload ?
	if (param('jqueryfileupload')) {
	
		my $data = encode_json(\%data);

		$log->debug("jqueryfileupload JSON data output", { data => $data }) if $log->is_debug();

		print header( -type => 'application/json', -charset => 'utf-8' ) . $data;
		exit();	
	}
	
}

else {
	# We should have a code
	if ((not defined $code) or ($code eq '')) {
		display_error($Lang{no_barcode}{$lang}, 403);
	}
	else {
		$product_ref = retrieve_product_or_deleted_product($code, $admin);
		if (not defined $product_ref) {
			display_error(sprintf(lang("no_product_for_barcode"), $code), 404);
		}
	}
}

if (($type eq 'delete') and (not $admin)) {
	display_error($Lang{error_no_permission}{$lang}, 403);
}

if ($User_id eq 'unwanted-bot-id') {
	my $r = Apache2::RequestUtil->request();
	$r->status(500);  
	return 500;
}

if (($type eq 'add') or ($type eq 'edit') or ($type eq 'delete')) {

	if (not defined $User_id) {
	
		my $submit_label = "login_and_" .$type . "_product";
	
		$html = <<HTML
<p>$Lang{login_to_add_products}{$lang}</p>

<form method="post" action="/cgi/session.pl">
<div class="row">
<div class="small-12 columns">
	<label>$Lang{login_username_email}{$lc}
		<input type="text" name="user_id" autocomplete="username" />
	</label>
</div>
<div class="small-12 columns">
	<label>$Lang{password}{$lc}
		<input type="password" name="password" autocomplete="current-password" />
	</label>
</div>
<div class="small-12 columns">
	<label>
		<input type="checkbox" name="remember_me" value="on" />
		$Lang{remember_me}{$lc}
	</label>
</div>
</div>
<input type="submit" name=".submit" value="$Lang{login_register_title}{$lc}" class="button small" />
<input type="hidden" name="code" value="$code" />
<input type="hidden" name="next_action" value="product_$type" />
</form>

HTML
;
			$action = 'login';

	}
}


my @fields = @ProductOpener::Config::product_fields;


if (($action eq 'process') and (($type eq 'add') or ($type eq 'edit'))) {

	# Process edit rules
	
	$log->debug("phase 0 - checking edit rules", { code => $code, type => $type }) if $log->is_debug();
	
	my $proceed_with_edit = process_product_edit_rules($product_ref);

	$log->debug("phase 0", { code => $code, type => $type, proceed_with_edit => $proceed_with_edit }) if $log->is_debug();

	if (not $proceed_with_edit) {
	
		display_error("Edit against edit rules", 403);
	}

	$log->debug("phase 1", { code => $code, type => $type }) if $log->is_debug();
	
	exists $product_ref->{new_server} and delete $product_ref->{new_server};
	
	# 26/01/2017 - disallow barcode changes until we fix bug #677
	if ($admin and (defined param('new_code'))) {
		my $new_code = param('new_code');
		my $new_server = "";
		my $new_data_root = $data_root;
		
		if ($new_code =~ /^([a-z]+)$/) {
			$new_server = $1;
			if ((defined $options{other_servers}) and (defined $options{other_servers}{$new_server})
				and ($options{other_servers}{$new_server}{data_root} ne $data_root)) {
				$new_code = $code;
				$new_data_root = $options{other_servers}{$new_server}{data_root};
			}
		}
		
		$new_code = normalize_code($new_code);
		if ($new_code =~ /^\d+$/) {
		# check that the new code is available
			if (-e "$new_data_root/products/" . product_path($new_code)) {
				push @errors, lang("error_new_code_already_exists");
				$log->warn("cannot change product code, because the new code already exists", { code => $code, new_code => $new_code, new_server => $new_server }) if $log->is_warn();
			}
			else {
				$product_ref->{old_code} = $code;
				$code = $new_code;
				$product_ref->{code} = $code;
				if ($new_server ne '') {
					$product_ref->{new_server} = $new_server;
				}
				$log->info("changing code", { old_code => $product_ref->{old_code}, code => $code, new_server => $new_server }) if $log->is_info();
			}
		}
	}
	
	my @param_fields = ();

	my @param_sorted_langs = ();
	if (defined param("sorted_langs")) {
		foreach my $display_lc (split(/,/, param("sorted_langs"))) {
			if ($display_lc =~ /^\w\w$/) {
				push @param_sorted_langs, $display_lc;
			}
		}
	}
	else {
		push @param_sorted_langs, $product_ref->{lc};
	}
	
	$product_ref->{"debug_param_sorted_langs"} = \@param_sorted_langs;
	
	foreach my $field ('product_name', 'generic_name', @fields, 'nutrition_data_per', 'nutrition_data_prepared_per', 'serving_size', 'allergens', 'traces', 'ingredients_text','lang') {
	
		if (defined $language_fields{$field}) {
			foreach my $display_lc (@param_sorted_langs) {
				push @param_fields, $field . "_" . $display_lc;
			}
		}
		else {
			push @param_fields, $field;
		}
	}
	
	
	foreach my $field (@param_fields) {
	
		if (defined param($field)) {
			$product_ref->{$field} = remove_tags_and_quote(decode utf8=>param($field));
			if ($field eq 'emb_codes') {
				# French emb codes
				$product_ref->{emb_codes_orig} = $product_ref->{emb_codes};
				$product_ref->{emb_codes} = normalize_packager_codes($product_ref->{emb_codes});						
			}
			$log->debug("before compute field_tags", { code => $code, field_name => $field, field_value => $product_ref->{$field}}) if $log->is_debug();
			if ($field =~ /ingredients_text/) {
				# the ingredients_text_with_allergens[_$lc] will be recomputed after
				my $ingredients_text_with_allergens = $field;
				$ingredients_text_with_allergens =~ s/ingredients_text/ingredients_text_with_allergens/;
				delete $product_ref->{$ingredients_text_with_allergens};
			}

			compute_field_tags($product_ref, $field);
			
		}
		else {
			$log->debug("could not find field in params", { field => $field }) if $log->is_debug();
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
	
	if ((defined $product_ref->{nutriments}{"glycemic-index"}) and ($product_ref->{nutriments}{"glycemic-index"} ne '')) {
		push @{$product_ref->{"labels_hierarchy" }}, "en:glycemic-index";
		push @{$product_ref->{"labels_tags" }}, "en:glycemic-index";
	}
	
	# Language and language code / subsite
	
	if (defined $product_ref->{lang}) {
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
					
	
	# Ingredients classes
	extract_ingredients_from_text($product_ref);
	extract_ingredients_classes_from_text($product_ref);

	compute_languages($product_ref); # need languages for allergens detection
	detect_allergens_from_text($product_ref);
	
	# Nutrition data
	
	my $params_ref = Vars;
	
	# FIXME : there is no way to know if we get an unchecked value because the field was not there, or if the box is unchecked
	# the browser does not send anything when a box is unchecked... 
	# this is an issue because we can't have the API check or uncheck a box
	
	$product_ref->{no_nutrition_data} = remove_tags_and_quote(decode utf8=>param("no_nutrition_data"));	

	$product_ref->{nutrition_data} = remove_tags_and_quote(decode utf8=>param("nutrition_data"));	

	$product_ref->{nutrition_data_prepared} = remove_tags_and_quote(decode utf8=>param("nutrition_data_prepared"));	
	
		
	defined $product_ref->{nutriments} or $product_ref->{nutriments} = {};

	my @unknown_nutriments = ();
	my %seen_unknown_nutriments = ();
	foreach my $nid (keys %{$product_ref->{nutriments}}) {
	
		next if (($nid =~ /_/) and ($nid !~ /_prepared$/)) ;
		
		$nid =~ s/_prepared$//;

		if ((not exists $Nutriments{$nid}) and (defined $product_ref->{nutriments}{$nid . "_label"})
			and (not defined $seen_unknown_nutriments{$nid})) {
			push @unknown_nutriments, $nid;
			$log->debug("unknown_nutriment", { nid => $nid }) if $log->is_debug();
		}
	}
	
	my @new_nutriments = ();
	my $new_max = remove_tags_and_quote(param('new_max'));
	for (my $i = 1; $i <= $new_max; $i++) {
		push @new_nutriments, "new_$i";
	}
		
	foreach my $nutriment (@{$nutriments_tables{$nutriment_table}}, @unknown_nutriments, @new_nutriments) {
		next if $nutriment =~ /^\#/;
		
		my $nid = $nutriment;
		$nid =~ s/^(-|!)+//g;
		$nid =~ s/-$//g;		

		next if $nid =~ /^nutrition-score/;

		my $enid = encodeURIComponent($nid);
		
		# for prepared product
		my $nidp = $nid . "_prepared";
		my $enidp = encodeURIComponent($nidp);		
		
		# do not delete values if the nutriment is not provided
		next if ((not defined param("nutriment_${enid}")) and (not defined param("nutriment_${enidp}"))) ;		
		
		my $value = remove_tags_and_quote(decode utf8=>param("nutriment_${enid}"));
		my $valuep = remove_tags_and_quote(decode utf8=>param("nutriment_${enidp}"));
		my $unit = remove_tags_and_quote(decode utf8=>param("nutriment_${enid}_unit"));
		my $label = remove_tags_and_quote(decode utf8=>param("nutriment_${enid}_label"));
		
		if ($nid eq 'alcohol') {
			$unit = '% vol';
		}
		
		my $modifier = undef;
		my $modifierp = undef;
		
		normalize_nutriment_value_and_modifier(\$value, \$modifier);
		normalize_nutriment_value_and_modifier(\$valuep, \$modifierp);
		
		$log->debug("prepared nutrient info", { nid => $nid, value => $value, nidp => $nidp, valuep => $valuep }) if $log->is_debug();
	
		# New label?
		my $new_nid = undef;
		if ((defined $label) and ($label ne '')) {
			$new_nid = canonicalize_nutriment($lc,$label);
			$log->debug("unknown nutrient", { nid => $nid, lc => $lc, canonicalize_nutriment => $new_nid }) if $log->is_debug();
			
			if ($new_nid ne $nid) {
				delete $product_ref->{nutriments}{$nid};
				delete $product_ref->{nutriments}{$nid . "_unit"};
				delete $product_ref->{nutriments}{$nid . "_label"};				
				delete $product_ref->{nutriments}{$nid . "_value"};
				delete $product_ref->{nutriments}{$nid . "_modifier"};
				delete $product_ref->{nutriments}{$nid . "_100g"};
				delete $product_ref->{nutriments}{$nid . "_serving"};
				delete $product_ref->{nutriments}{$nid . "_prepared_value"};
				delete $product_ref->{nutriments}{$nid . "_prepared_modifier"};
				delete $product_ref->{nutriments}{$nid . "_prepared_100g"};
				delete $product_ref->{nutriments}{$nid . "_prepared_serving"};	
				$log->debug("unknown nutrient", { nid => $nid, lc => $lc, known_nid => $new_nid }) if $log->is_debug();
				$nid = $new_nid;
				$nidp = $new_nid . "_prepared";
			}
			$product_ref->{nutriments}{$nid . "_label"} = $label;
		}
		
		if (defined param("nutriment_${enid}")) {
			if (($nid eq '') or (not defined $value) or ($value eq '')) {
					delete $product_ref->{nutriments}{$nid};
					delete $product_ref->{nutriments}{$nid . "_modifier"};
					delete $product_ref->{nutriments}{$nid . "_100g"};
					delete $product_ref->{nutriments}{$nid . "_serving"};
			}
			else {
				if ((defined $modifier) and ($modifier ne '')) {
					$product_ref->{nutriments}{$nid . "_modifier"} = $modifier;
				}
				else {
					delete $product_ref->{nutriments}{$nid . "_modifier"};
				}
				$product_ref->{nutriments}{$nid . "_unit"} = $unit;		
				$product_ref->{nutriments}{$nid . "_value"} = $value;
				
				if (((uc($unit) eq 'IU') or (uc($unit) eq 'UI')) and (exists $Nutriments{$nid}) and ($Nutriments{$nid}{iu} > 0)) {
					$value = $value * $Nutriments{$nid}{iu} ;
					$unit = $Nutriments{$nid}{unit};
				}
				elsif  (($unit eq '% DV') and (exists $Nutriments{$nid}) and ($Nutriments{$nid}{dv} > 0)) {
					$value = $value / 100 * $Nutriments{$nid}{dv} ;
					$unit = $Nutriments{$nid}{unit};
				}
				if ($nid eq 'water-hardness') {
					$product_ref->{nutriments}{$nid} = unit_to_mmoll($value, $unit);
				}
				else {
					$product_ref->{nutriments}{$nid} = unit_to_g($value, $unit);
				}
			}
		}
		
		if (defined param("nutriment_${enidp}")) {
			if (($nid eq '') or (not defined $valuep) or ($valuep eq '')) {
					delete $product_ref->{nutriments}{$nidp};
					delete $product_ref->{nutriments}{$nidp . "_modifier"};
					delete $product_ref->{nutriments}{$nidp . "_100g"};
					delete $product_ref->{nutriments}{$nidp . "_serving"};
			}
			else {
				if ((defined $modifierp) and ($modifierp ne '')) {
					$product_ref->{nutriments}{$nidp . "_modifier"} = $modifierp;
				}
				else {
					delete $product_ref->{nutriments}{$nidp . "_modifier"};
				}		
				$product_ref->{nutriments}{$nidp . "_value"} = $valuep;
				
				if (((uc($unit) eq 'IU') or (uc($unit) eq 'UI')) and (exists $Nutriments{$nid}) and ($Nutriments{$nid}{iu} > 0)) {
					$valuep = $valuep * $Nutriments{$nid}{iu} ;
					$unit = $Nutriments{$nid}{unit};
				}
				elsif  (($unit eq '% DV') and (exists $Nutriments{$nid}) and ($Nutriments{$nid}{dv} > 0)) {
					$valuep = $valuep / 100 * $Nutriments{$nid}{dv} ;
					$unit = $Nutriments{$nid}{unit};
				}
				if ($nid eq 'water-hardness') {
					$product_ref->{nutriments}{$nidp} = unit_to_mmoll($valuep, $unit);
				}
				else {
					$product_ref->{nutriments}{$nidp} = unit_to_g($valuep, $unit);
				}
			}
		}		
		
		if (($nid eq '') or (not defined $value) or ($value eq '')) {
			delete $product_ref->{nutriments}{$nid . "_value"};	
			delete $product_ref->{nutriments}{$nid . "_modifier"};	
		}
		
		if (($nid eq '') or (not defined $valuep) or ($valuep eq '')) {
			delete $product_ref->{nutriments}{$nidp . "_value"};	
			delete $product_ref->{nutriments}{$nidp . "_modifier"};	
		}		
		
		if (($nid eq '') or
			(((not defined $value) or ($value eq '')) and ((not defined $valuep) or ($valuep eq ''))))  {
				delete $product_ref->{nutriments}{$nid . "_unit"};
				delete $product_ref->{nutriments}{$nid . "_label"};				
		}
		
	}
	
	# Compute nutrition data per 100g and per serving
	
	$log->trace("compute_serving_size_date - start") if $log->is_trace();
	
	fix_salt_equivalent($product_ref);
		
	compute_serving_size_data($product_ref);
	
	compute_nutrition_score($product_ref);
	
	compute_nova_group($product_ref);
	
	compute_nutrient_levels($product_ref);
	
	compute_unknown_nutrients($product_ref);
	
	ProductOpener::SiteQuality::check_quality($product_ref);
	
	$log->trace("end compute_serving_size_date - end") if $log->is_trace();
	
	if ($#errors >= 0) {
		$action = 'display';
	}	
}


# Display the product edit form

my %remember_fields = ('purchase_places'=>1, 'stores'=>1);

# Display each field

sub display_field($$) {
	
	my $product_ref = shift;
	my $field = shift;	# can be in %language_fields and suffixed by _[lc]
	
	my $fieldtype = $field;
	my $display_lc = undef;
	
	if (($field =~ /^(.*?)_(..|new_lc)$/) and (defined $language_fields{$1})) {
		$fieldtype = $1;
		$display_lc = $2;
	}

	my $tagsinput = '';
	if (defined $tags_fields{$fieldtype}) {
		$tagsinput = ' tagsinput';
		
		my $autocomplete = "";
		if ((defined $taxonomy_fields{$fieldtype}) or ($fieldtype eq 'emb_codes')) {
			my $world = format_subdomain('world');
			$autocomplete = ",
	'autocomplete_url': '$world/cgi/suggest.pl?lc=$lc&tagtype=$fieldtype&'";
		}
		
		my $default_text = "";
		if (defined $Lang{$field . "_tagsinput"}) {
			$default_text = $Lang{$field . "_tagsinput"}{$lang};
		}

		$initjs .= <<HTML
\$('#$field').tagsInput({
	'height':'3rem',
	'width':'100%',
	'interactive':true,
	'minInputWidth':130,
	'delimiter': [','],
	'defaultText':"$default_text"$autocomplete
});
HTML
;					
	}
	
	my $value = $product_ref->{$field};
	if (defined $product_ref->{$field . "_orig"}) {
		$value = $product_ref->{$field . "_orig"};
	}
	if ((defined $value) and (defined $taxonomy_fields{$field})) {
		$value = display_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field . "_hierarchy"});
		# Remove tags
		$value =~ s/<(([^>]|\n)*)>//g;
	}			
	if (not defined $value) {
		$value = "";
	}

	my $html = <<HTML
<label for="$field">$Lang{$fieldtype}{$lang}</label>
<input type="text" name="$field" id="$field" class="text${tagsinput}" value="$value" lang="${display_lc}" />		
HTML
;
	if (defined $Lang{$fieldtype . "_note"}{$lang}) {
		$html .= <<HTML
<p class="note">&rarr; $Lang{$fieldtype . "_note"}{$lang}</p>			
HTML
;
	}
	
	if (defined $Lang{$fieldtype . "_example"}{$lang}) {
	
		my $examples = $Lang{example}{$lang};
		if ($Lang{$fieldtype . "_example"}{$lang} =~ /,/) {
			$examples = $Lang{examples}{$lang};
		}
	
		$html .= <<HTML
<p class="example">$examples $Lang{$fieldtype . "_example"}{$lang}</p>
HTML
;
	}

	return $html;
}
	



if (($action eq 'display') and (($type eq 'add') or ($type eq 'edit'))) {

	$log->debug("displaying product", { code => $code }) if $log->is_debug();
	
	# Lang strings for product.js
	
	$scripts .=<<JS
<script type="text/javascript">
var admin = $admin;
var Lang = {
JS
;

	foreach my $key (sort keys %Lang) {
		next if $key !~ /^product_js_/;
		$scripts .= '"' . $' . '" : "' . lang($key) . '",' . "\n";
	}
	
	$scripts =~ s/,\n$//s;
	$scripts .=<<JS
};
</script>
JS
;

	$header .= <<HTML
<link rel="stylesheet" type="text/css" href="https://cdnjs.cloudflare.com/ajax/libs/cropper/2.3.4/cropper.min.css" />
<link rel="stylesheet" type="text/css" href="/js/jquery.tagsinput.20160520/jquery.tagsinput.min.css" />
<link rel="stylesheet" type="text/css" href="/css/product-multilingual.css" />

HTML
;


#<!-- Autocomplete -->
#<script type='text/javascript' src='https://xoxco.com/x/tagsinput/jquery-autocomplete/jquery.autocomplete.min.js'></script>
#<link rel="stylesheet" type="text/css" href="https://xoxco.com/x/tagsinput/jquery-autocomplete/jquery.autocomplete.css" ></link>

	$scripts .= <<HTML
<script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/cropper/2.3.4/cropper.min.js"></script>
<script type="text/javascript" src="/js/jquery.tagsinput.20160520/jquery.tagsinput.min.js"></script>
<script type="text/javascript" src="/js/jquery.form.js"></script>
<script type="text/javascript" src="/js/jquery.autoresize.js"></script>
<script type="text/javascript" src="/js/jquery.rotate.js"></script>
<script type="text/javascript" src="/js/jquery.iframe-transport.js"></script>
<script type="text/javascript" src="/js/jquery.fileupload.js"></script>	
<script type="text/javascript" src="/js/load-image.min.js"></script>
<script type="text/javascript" src="/js/canvas-to-blob.min.js"></script>
<script type="text/javascript" src="/js/jquery.fileupload-ip.js"></script>
<script type="text/javascript" src="/foundation/js/foundation/foundation.tab.js"></script>
<script type="text/javascript" src="/js/product-multilingual.js"></script>
HTML
;


	if ($#errors >= 0) {
		$html .= "<p>Merci de corriger les erreurs suivantes :</p>";
		foreach my $error (@errors) {
			$html .= "<p class=\"error\">$error</p>\n";
		}
	}
	
	$html .= start_multipart_form(-id=>"product_form") ;
	
	my $thumb_selectable_size = $thumb_size + 20;
	
	
	my $old = <<CSS
label, input { display: block;  }
input[type="checkbox"] { padding-top:10px; display: inline; }

.checkbox_label { display: inline; }
input.text { width:98% }
CSS
;
	
	$styles .= <<CSS

.ui-selectable { list-style-type: none; margin: 0; padding: 0; }
.ui-selectable li { margin: 3px; padding: 0px; float: left; width: ${thumb_selectable_size}px; height: ${thumb_selectable_size}px;
line-height: ${thumb_selectable_size}px; text-align: center; }
.ui-selectable img { 
  vertical-align:middle;
}
.ui-selectee:hover { background: #FECA40; }
.ui-selected { background: #F39814; color: white; }	

.command { margin-bottom:5px; }
		
label { margin-top: 20px; }

fieldset { margin-top: 15px; margin-bottom:15px;}

legend { font-size: 1.375em; margin-top:2rem; }

textarea {  height:8rem; }

.cropbox, .display { float:left; margin-top:10px;margin-bottom:10px; max-width:400px; }
.cropbox { margin-right: 20px; }

.upload_image_div {
	padding-top:0.5rem;
}

.button_div {
	margin-top:0.5rem;
}

#label_new_code, #new_code { display: inline; margin-top: 0px; width:200px; }

th {
	font-weight:bold;
}
CSS
;

	my $label_new_code = $Lang{new_code}{$lang};
	
	# 26/01/2017 - disallow barcode changes until we fix bug #677
	if ($admin) {
		$html .= <<HTML
<label for="new_code" id="label_new_code">${label_new_code}</label>
<input type="text" name="new_code" id="new_code" class="text" value="" />
HTML
;
	}

	$html .= <<HTML
<div data-alert class="alert-box info store-state" id="warning_3rd_party_content" style="display:none;">
<span>$Lang{warning_3rd_party_content}{$lang}
 <a href="#" class="close">&times;</a>
</div>

<div data-alert class="alert-box secondary store-state" id="licence_accept" style="display:none;">
<span>$Lang{licence_accept}{$lang}</span>
 <a href="#" class="close">&times;</a>
</div>
HTML
;
	
	$scripts .= <<JS
<script type="text/javascript">
'use strict';
\$(function() {
  var alerts = \$('.alert-box.store-state');
  \$.each(alerts, function( index, value ) {
    var display = \$.cookie('state_' + value.id);
    if (display !== undefined) {
      value.style.display = display;
    } else {
      value.style.display = 'block';
    }
  });
  alerts.on('close.fndtn.alert', function(event) {
    \$.cookie('state_' + \$(this)[0].id, 'none', { path: '/', expires: 365, domain: '$server_domain' });
  });
});
</script>
JS
;
	
	# Main language

	$html .= "<label for=\"lang\">" . $Lang{lang}{$lang} . "</label>";
	
	my @lang_values = @Langs;
	push @lang_values, "other";
	my %lang_labels = ();
	foreach my $l (@lang_values) {
		next if (length($l) > 2);
		$lang_labels{$l} = lang("lang_$l");
		if ($lang_labels{$l} eq '') {
			if (defined $Langs{$l}) {
				$lang_labels{$l} = $Langs{$l};
			}
			else {
				$lang_labels{$l} = $l;
			}
		}
	}
	my $lang_value = $lang;
	if (defined $product_ref->{lc}) {
		$lang_value = $product_ref->{lc};
	}
	
	$html .= popup_menu(-name=>'lang', -default=>$lang_value, -values=>\@lang_values, -labels=>\%lang_labels);


	
	$scripts .= <<JS
<script type="text/javascript">

function toggle_manage_images_buttons() {
		\$("#delete_images").addClass("disabled");
		\$("#move_images").addClass("disabled");
		\$( "#manage .ui-selected"  ).first().each(function() {
			\$("#delete_images").removeClass("disabled");
			\$("#move_images").removeClass("disabled");
		});
}

</script>	
JS
;	
	
	if ($admin) {
		$html .= <<HTML
<ul id="manage_images_accordion" class="accordion" data-accordion>
  <li class="accordion-navigation">
<a href="#manage_images_drop"><i class="fi-page-multiple"></i> $Lang{manage_images}{$lc}</a>


<div id="manage_images_drop" class="content" style="background:#eeeeee">

HTML
. display_select_manage($product_ref) .
<<HTML

	<p>$Lang{manage_images_info}{$lc}</p>
	<a id="delete_images" class="button small disabled"><i class="fi-trash"></i> $Lang{delete_the_images}{$lc}</a><br/>
	<div class="row">
		<div class="small-12 medium-5 columns">
			<button id="move_images" class="button small disabled"><i class="fi-arrow-right"></i> $Lang{move_images_to_another_product}{$lc}</a>
		</div>
		<div class="small-4 medium-2 columns">
			<label for="move_to" class="right inline">$Lang{barcode}{$lc}</label>
		</div>
		<div class="small-8 medium-5 columns">
			<input type="text" id="move_to" name="move_to" />
		</div>
	</div>
	<input type="checkbox" id="copy_data" name="copy_data"><label for="copy_data">$Lang{copy_data}{$lc}</label>
	<div id="moveimagesmsg"></div>
</div>
</li>
</ul>

HTML
;

	$styles .= <<CSS
.show_for_manage_images {
line-height:normal;
font-weight:normal;
font-size:0.8rem;
}

.select_manage .ui-selectable li { height: 180px }

CSS
;


	$initjs .= <<JS
	
\$('#manage_images_accordion').on('toggled', function (event, accordion) {

	toggle_manage_images_buttons();
});



\$("#delete_images").click({},function(event) {

event.stopPropagation();
event.preventDefault();


if (! \$("#delete_images").hasClass("disabled")) {

	\$("#delete_images").addClass("disabled");
	\$("#move_images").addClass("disabled");
	
 \$('div[id="moveimagesmsg"]').html('<img src="/images/misc/loading2.gif" /> ' + Lang.deleting_images);
 \$('div[id="moveimagesmsg"]').show();	
	
	var imgids = '';
	var i = 0;
	\$( "#manage .ui-selected"  ).each(function() {
		var imgid = \$( this ).attr('id');
		imgid = imgid.replace("manage_","");
		imgids += imgid + ',';
		i++;
});
	if (i) {
		// remove trailing comma
		imgids = imgids.substring(0, imgids.length - 1);
	}
	
 \$("#product_form").ajaxSubmit({

  url: "/cgi/product_image_move.pl",
  data: { code: code, move_to_override: "trash", imgids : imgids },
  dataType: 'json',
  beforeSubmit: function(a,f,o) {
  },
  success: function(data) {

	if (data.error) {
		\$('div[id="moveimagesmsg"]').html(Lang.images_delete_error + ' - ' + data.error);
	}
	else {
		\$('div[id="moveimagesmsg"]').html(Lang.images_deleted);
	}
	\$([]).selectcrop('init_images',data.images);
	\$(".select_crop").selectcrop('show');
	
  },
  error : function(jqXHR, textStatus, errorThrown) {
	\$('div[id="moveimagesmsg"]').html(Lang.images_delete_error + ' - ' + textStatus);
  },
  complete: function(XMLHttpRequest, textStatus) {

	}
 });	

}
 
});



\$("#move_images").click({},function(event) {

event.stopPropagation();
event.preventDefault();


if (! \$("#move_images").hasClass("disabled")) {

	\$("#delete_images").addClass("disabled");
	\$("#move_images").addClass("disabled");
	
 \$('div[id="moveimagesmsg"]').html('<img src="/images/misc/loading2.gif" /> ' + Lang.moving_images);
 \$('div[id="moveimagesmsg"]').show();	
	
	var imgids = '';
	var i = 0;
	\$( "#manage .ui-selected"  ).each(function() {
		var imgid = \$( this ).attr('id');
		imgid = imgid.replace("manage_","");
		imgids += imgid + ',';
		i++;
});
	if (i) {
		// remove trailing comma
		imgids = imgids.substring(0, imgids.length - 1);
	}
	
 \$("#product_form").ajaxSubmit({

  url: "/cgi/product_image_move.pl",
  data: { code: code, move_to_override: \$("#move_to").val(), copy_data_override: \$("#copy_data").prop( "checked" ), imgids : imgids },
  dataType: 'json',
  beforeSubmit: function(a,f,o) {
  },
  success: function(data) {

	if (data.error) {
		\$('div[id="moveimagesmsg"]').html(Lang.images_move_error + ' - ' + data.error);
	}
	else {
		\$('div[id="moveimagesmsg"]').html(Lang.images_moved + ' &rarr; ' + data.link);
	}
	\$([]).selectcrop('init_images',data.images);
	\$(".select_crop").selectcrop('show');
	
  },
  error : function(jqXHR, textStatus, errorThrown) {
	\$('div[id="moveimagesmsg"]').html(Lang.images_move_error + ' - ' + textStatus);
  },
  complete: function(XMLHttpRequest, textStatus) {
		\$("#move_images").addClass("disabled");
		\$("#move_images").addClass("disabled");
		\$( "#manage .ui-selected"  ).first().each(function() {
			\$("#move_images").removeClass("disabled");
			\$("#move_images").removeClass("disabled");
		});
	}
 });	

}
 
});	


JS
;

			}		
	
	


$styles .= <<CSS

// add borders to Foundation 5 tabs
// \@media only screen and (min-width: 40.063em) {  /* min-width 641px, medium screens */
  ul.tabs {
     > li > a {
       border-width: 1px;
       border-style: solid;
       border-color: #ccc #ccc #fff;
       margin-right: -1px;
     }
     > li:not(.active) > a {
       border-bottom: solid 1px #ccc;
     }
   }
  .tabs-content {
    border: 1px solid #ccc;
    .content {
      padding: .9375rem;
      margin-top: 0;
    }
    margin: -1px 0 .9375rem 0;
  }
//}

// if tabs container has a background color
.tabs-content { background-color: #fff; }

.contained {
	border:1px solid #ccc;
	padding:1rem;
}

ul.tabs {
	border-top:1px solid #ccc;
	border-left:1px solid #ccc;
	border-right:1px solid #ccc;
	background-color:#EFEFEF;
}

.tabs dd>a, .tabs .tab-title>a {
padding:0.5rem 1rem;
}

.tabs-content {
	background-color:white;
	padding:1rem;
	border-bottom:1px solid #ccc;
	border-left:1px solid #ccc;
	border-right:1px solid #ccc;	
}

.select_add_language {
	border:0;
}


.select2-container--default .select2-selection--single {
	height:2.5rem;
	top:0;
	border:0;
  background-color: #0099ff;
  color: #FFFFFF;
  transition: background-color 300ms ease-out;
}

.select2-container--default .select2-selection--single:hover, .select2-container--default .select2-selection--single:focus {
background-color: #007acc;
color:#FFFFFF;
}

.select2-container--default .select2-selection--single .select2-selection__arrow b {
    border-color: #fff transparent transparent transparent;
}

.select2-container--default .select2-selection--single .select2-selection__placeholder {
	color:white;
}

.select2-container--default .select2-selection--single .select2-selection__rendered {
	line-height:2.5rem;
}

.select2-container--default .select2-selection--single .select2-selection__arrow b {
	margin-top:4px;
}

CSS
;
	
	$initjs .= <<JS
\$(".select_add_language").select2({
	placeholder: "$Lang{add_language}{$lang}",
    allowClear: true
	}
	).on("select2:select", function(e) {
	var lc =  e.params.data.id;
	var language = e.params.data.text;
	add_language_tab (lc, language);
	\$(".select_add_language_" + lc).remove();
	\$(this).val("").trigger("change");
	var new_sorted_langs = \$("#sorted_langs").val() + "," + lc;
	\$("#sorted_langs").val(new_sorted_langs);
})
;	

\$(document).foundation({
    tab: {
      callback : function (tab) {
	  
\$('.tabs').each(function(i, obj) {
	\$(this).removeClass('active');
});	  
	  
        var id = tab[0].id;	 // e.g. tabs_front_image_en_tab
		var lc = id.replace(/.*(..)_tab/, "\$1");
		\$(".tabs_" + lc).addClass('active');
		
\$(document).foundation('tab', 'reflow');		
		
      }
    }
  });

JS
;	
	
	
	
	$html .= "<div class=\"fieldset\"><legend>$Lang{product_image}{$lang}</legend>";

	
	$product_ref->{langs_order} = { fr => 0, nl => 1, en => 1, new => 2 };
	
	# sort function to put main language first, other languages by alphabetical order, then add new language tab
	
	defined $product_ref->{lc} or $product_ref->{lc} = $lc;
	defined $product_ref->{languages_codes} or $product_ref->{languages_codes} = {};
	
	$product_ref->{sorted_langs} = [ $product_ref->{lc} ];
	
	foreach my $olc (sort keys %{$product_ref->{languages_codes}}) {
		if ($olc ne $product_ref->{lc}) {
			push @{$product_ref->{sorted_langs}}, $olc;
		}
	}
	
	$html .= "\n<input type=\"hidden\" id=\"sorted_langs\" name=\"sorted_langs\" value=\"" . join(',', @{$product_ref->{sorted_langs}}) . "\" />\n";
		
	my $select_add_language = <<HTML

<select class="select_add_language" style="width:100%">
<option></option>
HTML
;

	foreach my $olc (sort keys %Langs) {
		if (($olc ne $product_ref->{lc}) and (not defined $product_ref->{languages}{$olc})) {
			my $olanguage = display_taxonomy_tag($lc,'languages',$language_codes{$olc}); # $Langs{$olc}
			$select_add_language .=<<HTML
 <option value="$olc" class="select_add_language_$olc">$olanguage</option>
HTML
;
		}
	}

	$select_add_language .= <<HTML
</select>
		</li>
		
HTML
;

	
	

sub display_tabs($$$$$$) {

	my $product_ref = shift;
	my $select_add_language = shift;
	my $tabsid = shift;
	my $tabsids_array_ref = shift;
	my $tabsids_hash_ref = shift;
	my $fields_array_ref = shift;
	
	my $html_header = "";
	my $html_content = "";
	
	$html_header .= <<HTML
<ul id="tabs_$tabsid" class="tabs" data-tab>
HTML
;

	$html_content .= <<HTML
<div id="tabs_content_$tabsid" class="tabs-content">	
HTML
;


	my $active = " active";
	foreach my $tabid (@$tabsids_array_ref, 'new_lc','new') {
	
		my $new_lc = '';
		if ($tabid eq 'new_lc') {
			$new_lc = ' new_lc hide';
		}
		elsif ($tabid eq 'new') {
			$new_lc = ' new';
		}
	
		my $language = "";
	
		if ($tabid eq 'new') {
		
		$html_header .= <<HTML
	<li class="tabs tab-title$active$new_lc tabs_new">$select_add_language</li>
HTML
;		
		
		}
		else {
	
			if ($tabid ne "new_lc") {
				$language = display_taxonomy_tag($lc,'languages',$language_codes{$tabid});	 # instead of $tabsids_hash_ref->{$tabid}
			}
	
			$html_header .= <<HTML
	<li class="tabs tab-title$active$new_lc tabs_${tabid}"  id="tabs_${tabsid}_${tabid}_tab"><a href="#tabs_${tabsid}_${tabid}" class="tab_language">$language</a></li>
HTML
;

		}

		my $html_content_tab = <<HTML
<div class="tabs content$active$new_lc tabs_${tabid}" id="tabs_${tabsid}_${tabid}">
HTML
;

		if ($tabid ne 'new') {
		
			my $display_lc = $tabid;

			foreach my $field (@{$fields_array_ref}) {
			
				if ($field =~ /^(.*)_image/) {
				
					my $image_field = $1 . "_" . $display_lc;
					$html_content_tab .= display_select_crop($product_ref, $image_field);
				
				}
				elsif ($field eq 'ingredients_text') {
				
					my $value = $product_ref->{"ingredients_text_" . ${display_lc}};
					my $id = "ingredients_text_" . ${display_lc};
				
					$html_content_tab .= <<HTML
<label for="$id">$Lang{ingredients_text}{$lang}</label>
<textarea id="$id" name="$id" lang="${display_lc}">$value</textarea>
<p class="note">&rarr; $Lang{ingredients_text_note}{$lang}</p>			
<p class="example">$Lang{example}{$lang} $Lang{ingredients_text_example}{$lang}</p>			
HTML
;
				
				}
				else {
					$log->debug("display_field", { field_name => $field, field_value => $product_ref->{$field} }) if $log->is_debug();
					$html_content_tab .= display_field($product_ref, $field . "_" . $display_lc);
				}
			}


			# add (language name) in all field labels
		
			$html_content_tab =~ s/<\/label>/ (<span class="tab_language">$language<\/span>)<\/label>/g;

		
		}
		else {
		
		
		}
		
		$html_content_tab .= <<HTML
</div>
HTML
;
		
		$html_content .= $html_content_tab;

		$active = "";

	}
	
	$html_header .= <<HTML
</ul>
HTML
;

	$html_content .= <<HTML
</div>
HTML
;

	return $html_header . $html_content;
}


	$html .= display_tabs($product_ref, $select_add_language, "front_image", $product_ref->{sorted_langs}, \%Langs, ["front_image"]);
	
	$html .= "</div><!-- fieldset -->";	
	
	$html .= <<HTML

<div class="fieldset">
<legend>$Lang{product_characteristics}{$lang}</legend>
HTML
;
	
	$html .= display_tabs($product_ref, $select_add_language, "product", $product_ref->{sorted_langs}, \%Langs, ["product_name", "generic_name"]);
	
	
	foreach my $field (@fields) {
		$log->debug("display_field", { field_name => $field, field_value => $product_ref->{$field} }) if $log->is_debug();
		$html .= display_field($product_ref, $field);
	}
	
	

	$html .= "</div><!-- fieldset -->\n";
	

	$html .= "<div class=\"fieldset\"><legend>$Lang{ingredients}{$lang}</legend>\n";

	
	$html .= display_tabs($product_ref, $select_add_language, "ingredients_image", $product_ref->{sorted_langs}, \%Langs, ["ingredients_image", "ingredients_text"]);


	# $initjs .= "\$('textarea#ingredients_text').autoResize();";
	# ! with autoResize, extracting ingredients from image need to update the value of the real textarea
	# maybe calling $('textarea.growfield').data('AutoResizer').check(); 
	
	$html .= display_field($product_ref, "allergens");
	
	$html .= display_field($product_ref, "traces");

$html .= "</div><!-- fieldset -->
<div class=\"fieldset\" id=\"nutrition\"><legend>$Lang{nutrition_data}{$lang}</legend>\n";

	my $checked = '';
	my $tablestyle = 'display: table;';
	my $disabled = '';
	if ((defined $product_ref->{no_nutrition_data}) and ($product_ref->{no_nutrition_data} eq 'on')) {
		$checked = 'checked="checked"';
		$tablestyle = 'display: none;';
		$disabled = 'disabled="disabled"';
	}

	$html .= <<HTML
<input type="checkbox" id="no_nutrition_data" name="no_nutrition_data" $checked />	
<label for="no_nutrition_data" class="checkbox_label">$Lang{no_nutrition_data}{$lang}</label><br/>
HTML
;

	$initjs .= <<JS
\$('#no_nutrition_data').change(function() {
	if (\$(this).prop('checked')) {
		\$('#nutrition_data_table input').prop('disabled', true);
		\$('#nutrition_data_table select').prop('disabled', true);
		\$('#multiple_nutrition_data').prop('disabled', true);		
		\$('#multiple_nutrition_data').prop('checked', false);		
		\$('#nutrition_data_table input.nutriment_value').val('');
		\$('#nutrition_data_table').hide();
	} else {
		\$('#nutrition_data_table input').prop('disabled', false);
		\$('#nutrition_data_table select').prop('disabled', false);
		\$('#multiple_nutrition_data').prop('disabled', false);		
		\$('#nutrition_data_table').show();
	}

	\$(document).foundation('equalizer', 'reflow');
});
JS
;



	$html .= display_tabs($product_ref, $select_add_language, "nutrition_image", $product_ref->{sorted_langs}, \%Langs, ["nutrition_image"]);
	
	$initjs .= display_select_crop_init($product_ref);
	
	
	my $hidden_inputs = '';
	
	#<p class="note">&rarr; $Lang{nutrition_data_table_note}{$lang}</p>
	
	$html .= display_field($product_ref, "serving_size");
	
	
	# Display 2 checkbox to indicate the nutrition values present on the product
	
	if (not defined $product_ref->{nutrition_data}) {
		# by default, display the nutrition data entry column for the product as sold
		$product_ref->{nutrition_data} = "on";
	}
	if (not defined $product_ref->{nutrition_data_prepared}) {
		# by default, do not display the nutrition data entry column for the prepared product
		$product_ref->{nutrition_data_prepared} = "";
	}	
	
	my %column_display_style = {};
	my %nutrition_data_per_display_style = {};
	
	# keep existing field ids for the product as sold, and append _prepared_product for the product after it has been prepared
	foreach my $product_type ("", "_prepared") {
	
		my $nutrition_data = "nutrition_data" . $product_type;
		my $nutrition_data_exists = "nutrition_data" . $product_type . "_exists";
		my $nutrition_data_instructions = "nutrition_data" . $product_type . "_instructions";
	
		my $checked = '';
		$column_display_style{$nutrition_data} = '';
		my $hidden = '';
		if (($product_ref->{$nutrition_data} eq 'on')) {
			$checked = 'checked="checked"';	
		}
		else {
			$column_display_style{$nutrition_data} = 'style="display:none"';
			$hidden = 'style="display:none"';		
		}

		$html .= <<HTML
<input type="checkbox" id="$nutrition_data" name="$nutrition_data" $checked />	
<label for="$nutrition_data" class="checkbox_label">$Lang{$nutrition_data_exists}{$lang}</label> &nbsp; 
HTML
;
		my $checked_per_serving = '';
		my $checked_per_100g = 'checked="checked"';
		$nutrition_data_per_display_style{$nutrition_data . "_serving"} = ' style="display:none"';
		$nutrition_data_per_display_style{$nutrition_data . "_100g"} = '';
		
	
		my $nutrition_data_per = "nutrition_data" . $product_type . "_per";
	
		if ($product_ref->{$nutrition_data_per} eq 'serving') {
			$checked_per_serving = 'checked="checked"';
			$checked_per_100g = '';
			$nutrition_data_per_display_style{$nutrition_data . "_serving"} = '';
			$nutrition_data_per_display_style{$nutrition_data . "_100g"} = ' style="display:none"';			
		}
	
		$html .= <<HTML
<input type="radio" id="${nutrition_data_per}_100g" value="100g" name="${nutrition_data_per}" $checked_per_100g /><label for="${nutrition_data_per}_100g">$Lang{nutrition_data_per_100g}{$lang}</label>
<input type="radio" id="${nutrition_data_per}_serving" value="serving" name="${nutrition_data_per}" $checked_per_serving /><label for="${nutrition_data_per}_serving">$Lang{nutrition_data_per_serving}{$lang}</label><br/>
HTML
;

		if ((exists $Lang{$nutrition_data_instructions}) and ($Lang{$nutrition_data_instructions} ne '')) {
			$html .= <<HTML
<p id="$nutrition_data_instructions" $hidden>$Lang{$nutrition_data_instructions}{$lang}</p>
HTML
;
		}
		
		my $nutriment_col_class = "nutriment_col" . $product_type;

		$initjs .= <<JS
\$('#$nutrition_data').change(function() {
	if (\$(this).prop('checked')) {
		\$('#$nutrition_data_instructions').show();
		\$('.$nutriment_col_class').show();
	} else {
		\$('#$nutrition_data_instructions').hide();
		\$('.$nutriment_col_class').hide();
	}
	update_nutrition_image_copy();
	\$(document).foundation('equalizer', 'reflow');
});

\$('input[name=$nutrition_data_per]').change(function() {
	if (\$('input[name=$nutrition_data_per]:checked').val() == '100g') {
		\$('#${nutrition_data}_100g').show();
		\$('#${nutrition_data}_serving').hide();
	} else {
		\$('#${nutrition_data}_100g').hide();
		\$('#${nutrition_data}_serving').show();
	}
	update_nutrition_image_copy();
	\$(document).foundation('equalizer', 'reflow');
});
JS
;	
	

		
	}
	
	
	
	$html .= <<HTML
<div style="position:relative">


<table id="nutrition_data_table" class="data_table" style="$tablestyle">
<thead class="nutriment_header">
<th>
$Lang{nutrition_data_table}{$lang}
</th>
<th class="nutriment_col" $column_display_style{"nutrition_data"}>
$Lang{product_as_sold}{$lang}<br/>
<span id="nutrition_data_100g" $nutrition_data_per_display_style{"nutrition_data_100g"}>$Lang{nutrition_data_per_100g}{$lang}</span>
<span id="nutrition_data_serving" $nutrition_data_per_display_style{"nutrition_data_serving"}>$Lang{nutrition_data_per_serving}{$lang}</span>
</th>
<th class="nutriment_col_prepared" $column_display_style{"nutrition_data_prepared"}>
$Lang{prepared_product}{$lang}<br/>
<span id="nutrition_data_prepared_100g" $nutrition_data_per_display_style{"nutrition_data_prepared_100g"}>$Lang{nutrition_data_per_100g}{$lang}</span>
<span id="nutrition_data_prepared_serving" $nutrition_data_per_display_style{"nutrition_data_prepared_serving"}>$Lang{nutrition_data_per_serving}{$lang}</span>
</th>
<th>
$Lang{unit}{$lang}
</th>
</thead>

<tbody>
HTML
;

	my $html2 = ''; # for ecological footprint

	defined $product_ref->{nutriments} or $product_ref->{nutriments} = {};

	my @unknown_nutriments = ();
	my %seen_unknown_nutriments = ();
	foreach my $nid (keys %{$product_ref->{nutriments}}) {
	
		next if (($nid =~ /_/) and ($nid !~ /_prepared$/)) ;
		
		$nid =~ s/_prepared$//;

		$log->trace("detect unknown nutriment", { nid => $nid }) if $log->is_trace();
		
		if ((not exists $Nutriments{$nid}) and (defined $product_ref->{nutriments}{$nid . "_label"})
			and (not defined $seen_unknown_nutriments{$nid})) {
			push @unknown_nutriments, $nid;
			$log->debug("unknown nutriment detected", { nid => $nid }) if $log->is_debug();
		}
	}
	
	
	foreach my $nutriment (@{$nutriments_tables{$nutriment_table}}, @unknown_nutriments, 'new_0', 'new_1') {
		
		next if $nutriment =~ /^\#/;
		my $nid = $nutriment;
		$nid =~ s/^(-|!)+//g;
		$nid =~ s/-$//g;
		
		next if $nid =~ /^nutrition-score/;		
		
		my $class = 'main';
		my $prefix = '';
		
		my $shown = 0;
		
		if  (($nutriment !~ /-$/)
			or ((defined $product_ref->{nutriments}{$nid}) and ($product_ref->{nutriments}{$nid} ne ''))
			or ($nid eq 'new_0') or ($nid eq 'new_1')) {
			$shown = 1;
		}
			
		if (($shown) and ($nutriment =~ /^-/)) {
			$class = 'sub';
			$prefix = $Lang{nutrition_data_table_sub}{$lang} . " ";
			if ($nutriment =~ /^--/) {
				$prefix = "&nbsp; " . $prefix;
			}
		}
		
		
		my $display = '';
		if ($nid eq 'new_0') {
			$display = ' style="display:none"';
		}
		
		my $enid = encodeURIComponent($nid);
		
		# for prepared product
		my $nidp = $nid . "_prepared";
		my $enidp = encodeURIComponent($nidp);
		
		
		my $label = '';
		if ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{$lang})) {
			$label = <<HTML
<label class="nutriment_label" for="nutriment_$enid">${prefix}$Nutriments{$nid}{$lang}</label>
HTML
;
		}
		elsif ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{en})) {
			$label = <<HTML
<label class="nutriment_label" for="nutriment_$enid">${prefix}$Nutriments{$nid}{en}</label>
HTML
;
		}		
		elsif (defined $product_ref->{nutriments}{$nid . "_label"}) {
			my $label_value = $product_ref->{nutriments}{$nid . "_label"};
			$label = <<HTML
<input class="nutriment_label" id="nutriment_${enid}_label" name="nutriment_${enid}_label" value="$label_value" />
HTML
;
		}
		else {	# add a nutriment
			$label = <<HTML
<input class="nutriment_label" id="nutriment_${enid}_label" name="nutriment_${enid}_label" placeholder="$Lang{product_add_nutrient}{$lang}"/>
HTML
;
		}
		
		my $unit = 'g';
		if ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{"unit_$cc"})) {
			$unit = $Nutriments{$nid}{"unit_$cc"};
		}		
		elsif ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{unit})) {
			$unit = $Nutriments{$nid}{unit};
		}
		my $value; # product as sold
		my $valuep; # prepared product
		
		if ($nid eq 'water-hardness') {
			$value = mmoll_to_unit($product_ref->{nutriments}{$nid}, $unit);
			$valuep = mmoll_to_unit($product_ref->{nutriments}{$nidp}, $unit);
		}
		else {
			$value = g_to_unit($product_ref->{nutriments}{$nid}, $unit);
			$valuep = g_to_unit($product_ref->{nutriments}{$nidp}, $unit);
		}
		
		# user unit and value ? (e.g. DV for vitamins in US)
		if (defined $product_ref->{nutriments}{$nid . "_unit"}) {
			$unit = $product_ref->{nutriments}{$nid . "_unit"};
			if (defined $product_ref->{nutriments}{$nid . "_value"}) {
				$value = $product_ref->{nutriments}{$nid . "_value"};
				if (defined $product_ref->{nutriments}{$nid . "_modifier"}) {
					$product_ref->{nutriments}{$nid . "_modifier"} eq '<' and $value = "&lt; $value";
					$product_ref->{nutriments}{$nid . "_modifier"} eq "\N{U+2264}" and $value = "&le; $value";
					$product_ref->{nutriments}{$nid . "_modifier"} eq '>' and $value = "&gt; $value";
					$product_ref->{nutriments}{$nid . "_modifier"} eq "\N{U+2265}" and $value = "&ge; $value";
					$product_ref->{nutriments}{$nid . "_modifier"} eq '~' and $value = "~ $value";
				}
			}
			if (defined $product_ref->{nutriments}{$nidp . "_value"}) {
				$valuep = $product_ref->{nutriments}{$nidp . "_value"};
				if (defined $product_ref->{nutriments}{$nidp . "_modifier"}) {
					$product_ref->{nutriments}{$nidp . "_modifier"} eq '<' and $valuep = "&lt; $valuep";
					$product_ref->{nutriments}{$nidp . "_modifier"} eq "\N{U+2264}" and $valuep = "&le; $valuep";
					$product_ref->{nutriments}{$nidp . "_modifier"} eq '>' and $valuep = "&gt; $valuep";
					$product_ref->{nutriments}{$nidp . "_modifier"} eq "\N{U+2265}" and $valuep = "&ge; $valuep";
					$product_ref->{nutriments}{$nidp . "_modifier"} eq '~' and $valuep = "~ $valuep";
				}
			}			
		}
		
		my $disabled_backup = $disabled;
		if ($nid eq 'carbon-footprint') {
			# Workaround, so that the carbon footprint, that could be in a location different from actual nutrition facts,
			# will never be disabled.
			$disabled = '';
		}
		
		my $input = '';
		
		
		$input .= <<HTML
<tr id="nutriment_${enid}_tr" class="nutriment_$class"$display>
<td>$label</td>
<td class="nutriment_col" $column_display_style{"nutrition_data"}>
<input class="nutriment_value" id="nutriment_${enid}" name="nutriment_${enid}" value="$value" $disabled />
</td>
<td class="nutriment_col_prepared" $column_display_style{"nutrition_data_prepared"}>
<input class="nutriment_value" id="nutriment_${enidp}" name="nutriment_${enidp}" value="$valuep" $disabled/>
</td>
HTML
;

		if ($nid ne 'alcohol') {
		

		my @units = ('g','mg','µg');
		if ($nid =~ /^energy/) {
			@units = ('kJ','kcal');
		}
		elsif ($nid eq 'alcohol') {
			@units = ('% vol');
		}
		elsif ($nid eq 'water-hardness') {
			@units = ('mol/l', 'mmol/l', 'mval/l', 'ppm', "\N{U+00B0}rH", "\N{U+00B0}fH", "\N{U+00B0}e", "\N{U+00B0}dH", 'gpg');
		}

		if (((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{dv}) and ($Nutriments{$nid}{dv} > 0))
			or ($nid =~ /^new_/)
			or ($unit eq '% DV')) {
			push @units, '% DV';
		}
		if (((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{iu}) and ($Nutriments{$nid}{iu} > 0))
			or ($nid =~ /^new_/)
			or ($unit eq 'IU')
			or ($unit eq 'UI')) {
			push @units, 'IU';
		}		
		
		my $hide_percent = '';
		my $hide_select = '';
		
		if ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{unit}) and ($Nutriments{$nid}{unit} eq '')) {
			$hide_percent = ' style="display:none"';
			$hide_select = ' style="display:none"';
			
		}
		elsif ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{unit}) and ($Nutriments{$nid}{unit} eq '%')) {
			$hide_select = ' style="display:none"';
		}
		else {
			$hide_percent = ' style="display:none"';
		}

		$input .= <<HTML
<td>
<span class="nutriment_unit_percent" id="nutriment_${enid}_unit_percent"$hide_percent>%</span>
<select class="nutriment_unit" id="nutriment_${enid}_unit" name="nutriment_${enid}_unit"$hide_select $disabled>
HTML
;		
		$disabled = $disabled_backup;

		foreach my $u (@units) {
			my $selected = '';
			if ($unit eq $u) {
				$selected = 'selected="selected" ';
			}
			$input .= <<HTML
<option value="$u" $selected>$u</option>
HTML
;
		}

		$input .= <<HTML
</select>
HTML
;
		}
		else {
			# alcohol in % vol / °
			$input .= <<HTML
<td>
<span class="nutriment_unit" >% vol / °</span>
HTML
;			
		}
		
		$input .= <<HTML
</td>
</tr>
HTML
;
		
		if ($nid eq 'carbon-footprint') {
			$html2 .= $input;
		}
		elsif ($shown) {
			$html .= $input;
		}

	}
	$html .= <<HTML
</tbody>	
</table>
<input type="hidden" name="new_max" id="new_max" value="1" />
<div id="nutrition_image_copy" style="position:absolute;bottom:0"></div>
</div>
HTML
;

	my $other_nutriments = '';
	my $nutriments = '';
	foreach my $nid (@{$other_nutriments_lists{$nutriment_table}}) {
		my $other_nutriment_value;
		if ((exists $Nutriments{$nid}{$lang}) and ($Nutriments{$nid}{$lang} ne '')) {
			$other_nutriment_value = $Nutriments{$nid}{$lang};
		}
		else {
			foreach my $olc (@{$country_languages{$cc}}, 'en') {
				next if $olc eq $lang;
				if ((exists $Nutriments{$nid}{$olc}) and ($Nutriments{$nid}{$olc} ne '')) {
					$other_nutriment_value = $Nutriments{$nid}{$olc};
					last;
				}
			}
		}

		if ((not (defined $other_nutriment_value)) or ($other_nutriment_value eq '')) {
			$other_nutriment_value = $nid;
		}

		if ((not defined $product_ref->{nutriments}{$nid}) or ($product_ref->{nutriments}{$nid} eq '')) {
			my $supports_iu = "false";
			if ((exists $Nutriments{$nid}{iu}) and ($Nutriments{$nid}{iu} > 0)) {
				$supports_iu = "true";
			}

			$other_nutriments .= '{ "value" : "' . $other_nutriment_value . '", "unit" : "' . $Nutriments{$nid}{unit} . '", "iu": ' . $supports_iu . '  },' . "\n";
		}
		$nutriments .= '"' . $other_nutriment_value . '" : "' . $nid . '",' . "\n";
	}
	$nutriments =~ s/,\n$//s;
	$other_nutriments =~ s/,\n$//s;

	$scripts .= <<HTML
<script type="text/javascript">
var nutriments = {
$nutriments
};	

var otherNutriments = [
$other_nutriments
];
</script>
HTML
;
	
	$initjs .= <<HTML

\$( ".nutriment_label" ).autocomplete({
	source: otherNutriments,
	select: select_nutriment,
	//change: add_line
});

\$("#nutriment_sodium").change( function () {
	swapSalt(\$("#nutriment_sodium"), \$("#nutriment_salt"), 2.54);
}
);

\$("#nutriment_salt").change( function () {
	swapSalt(\$("#nutriment_salt"), \$("#nutriment_sodium"), 1/2.54);
}
);

\$("#nutriment_sodium_prepared").change( function () {
	swapSalt(\$("#nutriment_sodium_prepared"), \$("#nutriment_salt_prepared"), 2.54);
}
);

\$("#nutriment_salt_prepared").change( function () {
	swapSalt(\$("#nutriment_salt_prepared"), \$("#nutriment_sodium_prepared"), 1/2.54);
}
);

function swapSalt(from, to, multiplier) {
	var source = from.val().replace(",", ".");
	var regex = /^(.*?)([\\d]+(?:\\.[\\d]+)?)(.*?)\$/g;
	var match = regex.exec(source);
	if (match) {
		var target = match[1] + (parseFloat(match[2]) * multiplier) + match[3];
		to.val(target);
	} else {
		to.val(from.val());
	}
}

\$("#nutriment_sodium_unit").change( function () {
	\$("#nutriment_salt_unit").val( \$("#nutriment_sodium_unit").val());
}
);

\$("#nutriment_salt_unit").change( function () {
	\$("#nutriment_sodium_unit").val( \$("#nutriment_salt_unit").val());
}
);

\$("#nutriment_new_0_label").change(add_line);
\$("#nutriment_new_1_label").change(add_line);

HTML
;
	
	
	$html .= <<HTML
<p class="note">&rarr; $Lang{nutrition_data_table_note}{$lang}</p>			
HTML
;	


	$html .= <<HTML
<table id="ecological_data_table" class="data_table">
<thead class="nutriment_header">
<tr><th>$Lang{ecological_data_table}{$lang}</th>
<th class="nutriment_col" $column_display_style{"nutrition_data"}>
$Lang{product_as_sold}{$lang}
</th>
<th class="nutriment_col_prepared" $column_display_style{"nutrition_data_prepared"}>
$Lang{prepared_product}{$lang}
</th>
<th>
$Lang{unit}{$lang}
</th>
</tr>
</thead>
<tbody>
$html2
</tbody>	
</table>
HTML
;

	$html .= <<HTML
<p class="note">&rarr; $Lang{ecological_data_table_note}{$lang}</p>			
HTML
;	

	$html .= "</div><!-- fieldset -->";
	
	
	$html .= ''
	. hidden(-name=>'type', -value=>$type, -override=>1)
	. hidden(-name=>'code', -value=>$code, -override=>1)
	. hidden(-name=>'action', -value=>'process', -override=>1);
	
	$html .= '<div style="position: fixed; bottom: 0; width: 100%; border-top: 1px solid #eee; background-color: white; z-index: 100; padding-top: 10px;">';

	if ($type eq 'edit') {
		$html .= <<HTML
<input id="comment" name="comment" placeholder="$Lang{edit_comment}{$lang}" value="" type="text" class="text" style="width: 70%; float: left; margin-right: 5px">
<input type="submit" name=".submit" value="$Lang{save}{$lc}" class="button small" style="float: left">
HTML
;
	}
	else {
		$html .= <<HTML
<input type="submit" name=".submit" value="$Lang{save}{$lc}" class="button small" style="float: left; margin-left: 70%;">
HTML
;
	}
	
	$html .= <<HTML
</div>
</form>
HTML
;

	$html .= display_product_history($code, $product_ref);
}
elsif (($action eq 'display') and ($type eq 'delete')) {

	$log->debug("display product", { code => $code }) if $log->is_debug();
	
	$html .= start_multipart_form(-id=>"product_form") ;
		
	$html .= <<HTML
<p>$Lang{delete_product_confirm}{$lc} ? ($Lang{product_name}{$lc} : $product_ref->{product_name}, $Lang{barcode}{$lc} : $code)</p>

HTML
;

	$html .= ''
	. hidden(-name=>'type', -value=>$type, -override=>1)
	. hidden(-name=>'code', -value=>$code, -override=>1)
	. hidden(-name=>'action', -value=>'process', -override=>1)
	. <<HTML
<label for="comment" style="margin-left:10px">$Lang{delete_comment}{$lang}</label>
<input type="text" id="comment" name="comment" value="" />
HTML
	. submit(-name=>'save', -label=>lang("delete_product_page"), -class=>"button small")
	. end_form();

}
elsif ($action eq 'process') {

	$log->debug("phase 2", { code => $code }) if $log->is_debug();
	
	$product_ref->{interface_version_modified} = $interface_version;
	
	if ($type eq 'delete') {
		$product_ref->{deleted} = 'on';
		$comment = lang("deleting_product") . separator_before_colon($lc) . ":";
	}
	elsif (($admin) and (exists $product_ref->{deleted})) {
		delete $product_ref->{deleted};	
	}
	
	my $time = time();
	$comment = $comment . remove_tags_and_quote(decode utf8=>param('comment'));
	store_product($product_ref, $comment);
	
	 my $product_url = product_url($product_ref);
	
	if (defined $product_ref->{server}) {
		# product that was moved to OBF from OFF etc.
		$product_url = "https://" . $subdomain . "." . $options{other_servers}{$product_ref->{server}}{domain} . product_url($product_ref);;
		$html .= "<p>" . lang("product_changes_saved") . "</p><p>&rarr; <a href=\"" . $product_url . "\">"
			. lang("see_product_page") . "</a></p>";
	}
	elsif ($type eq 'delete') {
		my $email = <<MAIL
$User_id $Lang{has_deleted_product}{$lc}:

$html
	
MAIL
;
		send_email_to_admin(lang("deleting_product"), $email);
	
	} else {
	
		# warning: this option is very slow
		if ((defined $options{display_random_sample_of_products_after_edits}) and ($options{display_random_sample_of_products_after_edits})) {
		
			my %request = (
				'titleid'=>get_fileid(product_name_brand($product_ref)),
				'query_string'=>$ENV{QUERY_STRING},
				'referer'=>referer(),
				'code'=>$code,
				'product_changes_saved'=>1,
				'sample_size'=>10
			);
			
			display_product(\%request);
		
		}
		else {
			$html .= "<p>" . lang("product_changes_saved") . "</p><p>&rarr; <a href=\"" . $product_url . "\">"
                . lang("see_product_page") . "</a></p>";
		}
	}
	
}

$html = "<p>" . lang("barcode") . separator_before_colon($lc) . ": $code</p>\n" . $html;

display_new( {
	blog_ref=>undef,
	blogid=>'all',
	tagid=>'all',
	title=>lang($type . '_product'),
	content_ref=>\$html,
	full_width=>1,
});


exit(0);

