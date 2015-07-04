#!/usr/bin/perl

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2015 Association Open Food Facts
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

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Tags qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Images qw/:all/;
use Blogs::Lang qw/:all/;
use Blogs::Mail qw/:all/;
use Blogs::Products qw/:all/;
use Blogs::Food qw/:all/;
use Blogs::Ingredients qw/:all/;
use Blogs::Images qw/:all/;


use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

Blogs::Display::init();

$debug = 1;

my $type = param('type') || 'search_or_add';
my $action = param('action') || 'display';

my $comment = 'Modification : ';

my @errors = ();

my $html = '';
my $code = param('code');
$code =~ s/\D//g; # Keep only digits, remove spaces, dashes and everything else

my $product_ref = undef;

my $interface_version = '20120622';

# Search or add product
if ($type eq 'search_or_add') {

	# barcode in image?
	my $filename;
	if ((not defined $code) or ($code !~ /^\d+$/)) {
		$code = process_search_image_form(\$filename);
	}
	
	if ((not defined $code) and ((not defined param("imgupload_search")) or ( param("imgupload_search") eq ''))) {
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
		print STDERR "product.pl - search_or_add - we have a code: $code\n";
		
		$product_ref = product_exists($code); # returns 0 if not
		
		if ($product_ref) {
			print STDERR "product.pl - product code $code exists, redirecting to product page\n";
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
			print STDERR "product.pl - product code $code does not exist yet, creating product\n";
			$product_ref = init_product($code);
			$product_ref->{interface_version_created} = $interface_version;
			store_product($product_ref, "Création du produit");
			process_image_upload($code,$filename);
			$type = 'add';
			$action = 'display';
			$location = "/cgi/product.pl?type=add&code=$code";
		}
	}
	else {
		if (defined param("imgupload_search")) {
			print STDERR "product.pl - search_or_add - no code found in image\n";
			$data{error} = "Pas de code barre lisible dans l'image.";
			$html .= "Le code barre de l'image n'a pas pu être lu, ou l'image ne contenait pas de code barre.
Vous pouvez essayer avec une autre image, ou entrer directement le code barre.";
		}
		else {
			print STDERR "product.pl - search_or_add - no code found in text\n";		
			$html .= "Il faut entrer les chiffres du code barre, ou envoyer une image du produit où le code barre est visible.";
		}
	}
	
	$data{type} = $type;
	$data{location} = $location;
	
	# jquery.fileupload ?
	if (param('jqueryfileupload')) {
	
		my $data =  encode_json(\%data);

		print STDERR "product.pl - jqueryfileupload - JSON data output: $data\n";
		
		print header() . $data;
		exit();	
	}
	
}

else {
	# We should have a code
	if ((not defined $code) or ($code eq '')) {
		display_error("Code manquant");
	}
	else {
		$product_ref = retrieve_product($code);
		if (not defined $product_ref) {
			display_error("Pas de produit trouvé pour ce code");
		}
	}
}

if (($type eq 'delete') and (not $admin)) {
	display_error("Permission refusée");
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
		<input type="text" name="user_id" />
	</label>
</div>
<div class="small-12 columns">
	<label>$Lang{password}{$lc}
		<input type="password" name="password" />
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


my @fields = qw(product_name generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link expiration_date purchase_places stores countries  );


if (($action eq 'process') and (($type eq 'add') or ($type eq 'edit'))) {

	$debug and print STDERR "product.pl action: process - phase 1 - type: $type code $code\n";
	
	if ((defined param('new_code')) and (param('new_code') =~ /^\d+$/)) {
		# check that the new code is available
		if (-e "$data_root/products/" . product_path(param('new_code'))) {
			push @errors, lang("error_new_code_already_exists");
			print STDERR "product.pl - cannot change code $code to " . param('new_code') . "\n";
		}
		else {
			$product_ref->{old_code} = $code;
			$code = param('new_code');
			$product_ref->{code} = $code;
			print STDERR "product.pl - changing code $product_ref->{old_code} to $code\n";
		}
	}
	
	foreach my $field (@fields, 'nutrition_data_per', 'serving_size', 'traces', 'ingredients_text','lang') {
		if (defined param($field)) {
			$product_ref->{$field} = remove_tags_and_quote(decode utf8=>param($field));
			if ($field eq 'emb_codes') {
				# French emb codes
				$product_ref->{emb_codes_orig} = $product_ref->{emb_codes};
				$product_ref->{emb_codes} = normalize_packager_codes($product_ref->{emb_codes});						
			}
			print STDERR "product.pl - code: $code - field: $field = $product_ref->{$field}\n";
			if (defined $tags_fields{$field}) {

				$product_ref->{$field . "_tags" } = [];
				if ($field eq 'emb_codes') {
					$product_ref->{"cities_tags" } = [];
				}
				foreach my $tag (split(',', $product_ref->{$field} )) {
					if (get_fileid($tag) ne '') {
						push @{$product_ref->{$field . "_tags" }}, get_fileid($tag);
						if ($field eq 'emb_codes') {
							my $city_code = get_city_code($tag);
							if (defined $emb_codes_cities{$city_code}) {
								push @{$product_ref->{"cities_tags" }}, get_fileid($emb_codes_cities{$city_code}) ;
							}
						}
					}
				}			
			}
		
			if (defined $taxonomy_fields{$field}) {
				$product_ref->{$field . "_hierarchy" } = [ gen_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field}) ];
				$product_ref->{$field . "_tags" } = [];
				foreach my $tag (@{$product_ref->{$field . "_hierarchy" }}) {
					push @{$product_ref->{$field . "_tags" }}, get_taxonomyid($tag);
				}
			}		
			elsif (defined $hierarchy_fields{$field}) {
				$product_ref->{$field . "_hierarchy" } = [ gen_tags_hierarchy($field, $product_ref->{$field}) ];
				$product_ref->{$field . "_tags" } = [];
				foreach my $tag (@{$product_ref->{$field . "_hierarchy" }}) {
					if (get_fileid($tag) ne '') {
						push @{$product_ref->{$field . "_tags" }}, get_fileid($tag);
					}
				}
			}			
		}
		else {
			print STDERR "product.pl - could not find field $field\n";
		}
	}
	
	# Food category rules for sweeetened/sugared beverages
	# French PNNS groups from categories
	
	if ($domain =~ /openfoodfacts/) {
		Blogs::Food::special_process_product($product_ref);
	}
	
	
	if ((defined $product_ref->{nutriments}{"carbon-footprint"}) and ($product_ref->{nutriments}{"carbon-footprint"} ne '')) {
		push @{$product_ref->{"labels_hierarchy" }}, "en:carbon-footprint";
		push @{$product_ref->{"labels_tags" }}, "en:carbon-footprint";
	}	
	
	# Language and language code / subsite
	
	if (not defined $product_ref->{lang}) {
		$product_ref->{lang} = 'other';
	}
	if (defined $lang_lc{$product_ref->{lang}}) {
		$product_ref->{lc} = $lang_lc{$product_ref->{lang}};
	}
	else {
		$product_ref->{lc} = 'other';
	}
	
	# Ingredients classes
	extract_ingredients_from_text($product_ref);
	extract_ingredients_classes_from_text($product_ref);

	detect_allergens_from_text($product_ref);
	
	# Nutrition data
	
	$product_ref->{no_nutrition_data} = remove_tags_and_quote(decode utf8=>param("no_nutrition_data"));	
	
	defined $product_ref->{nutriments} or $product_ref->{nutriments} = {};

	my @unknown_nutriments = ();
	foreach my $nid (sort keys %{$product_ref->{nutriments}}) {
		next if $nid =~ /_/;
		if ((not exists $Nutriments{$nid}) and (defined $product_ref->{nutriments}{$nid . "_label"})) {
			push @unknown_nutriments, $nid;
			print STDERR "product.pl - unknown_nutriment: $nid\n";
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
	
		my $value = remove_tags_and_quote(decode utf8=>param("nutriment_${nid}"));
		my $unit = remove_tags_and_quote(decode utf8=>param("nutriment_${nid}_unit"));
		my $label = remove_tags_and_quote(decode utf8=>param("nutriment_${nid}_label"));
		
		if ($value =~ /nan/i) {
			$value = '';
		}
		
		if ($nid eq 'alcohol') {
			$unit = '% vol';
		}
		
		my $modifier = undef;
		
		if ($value =~ /(\&lt;|<|max|maxi|maximum|inf|inférieur|inferieur|less)( )?/) {
			$value =~ s/(\&lt;|<|min|minimum|max|maxi|maximum|environ)( )?//;
			$modifier = '<';
		}
		if ($value =~ /(\&gt;|>|min|mini|minimum|greater|more)/) {
			$value =~ s/(\&gt;|>|min|mini|minimum|greater|more)( )?//;
			$modifier = '>';
		}
		if ($value =~ /(env|environ|about|~|≈)/) {
			$value =~ s/(env|environ|about|~|≈)( )?//;
			$modifier = '~';
		}			
		if ($value =~ /trace|traces/) {
			$value = 0;
			$modifier = '~';
		}
		if ($value !~ /\./) {
			$value =~ s/,/\./;
		}
		
		# New label?
		my $new_nid = undef;
		if (defined $label) {
			$new_nid = canonicalize_nutriment($label);
			if ($new_nid ne $nid) {
				delete $product_ref->{nutriments}{$nid};
				delete $product_ref->{nutriments}{$nid . "_unit"};
				delete $product_ref->{nutriments}{$nid . "_value"};
				delete $product_ref->{nutriments}{$nid . "_modifier"};
				delete $product_ref->{nutriments}{$nid . "_label"};
				delete $product_ref->{nutriments}{$nid . "_100g"};
				delete $product_ref->{nutriments}{$nid . "_serving"};				
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
			if (defined $modifier) {
				$product_ref->{nutriments}{$nid . "_modifier"} = $modifier;
			}
			else {
				delete $product_ref->{nutriments}{$nid . "_modifier"};
			}
			$product_ref->{nutriments}{$nid . "_unit"} = $unit;		
			$product_ref->{nutriments}{$nid . "_value"} = $value;
			if (($unit eq '% DV') and ($Nutriments{$nid}{dv} > 0)) {
				$value = $value / 100 * $Nutriments{$nid}{dv} ;
				$unit = $Nutriments{$nid}{unit};
			}
			$product_ref->{nutriments}{$nid} = unit_to_g($value, $unit);
		}
	}
	
	# Compute nutrition data per 100g and per serving
	
	$admin and print STDERR "compute_serving_size_date\n";
	
	fix_salt_equivalent($product_ref);
		
	compute_serving_size_data($product_ref);
	
	compute_nutrition_score($product_ref);
	
	compute_nutrient_levels($product_ref);
	
	compute_unknown_nutrients($product_ref);
	
	
	$admin and print STDERR "compute_serving_size_date -- done\n";	
	
	if (0) {
		push @errors, "La description est trop courte";
	}

	
	if ($#errors >= 0) {
		$action = 'display';
	}	
}


# Display the product edit form

if (($action eq 'display') and (($type eq 'add') or ($type eq 'edit'))) {

	$debug and print STDERR "product.pl action: display type: $type code $code\n";
	
	# Lang strings for product.js
	
	$scripts .=<<JS
<script type="text/javascript">
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

# <link rel="stylesheet" type="text/css" href="/js/jquery.imgareaselect-0.9.10/css/imgareaselect-default.css" />


	$header .= <<HTML
<link rel="stylesheet" type="text/css" href="/js/cropper-20150415/dist/cropper.min.css" />
<link rel="stylesheet" type="text/css" href="/js/jquery.tagsinput.20150416/jquery.tagsinput.min.css" />

HTML
;

# <script type="text/javascript" src="/js/jquery.imgareaselect-0.9.8/scripts/jquery.imgareaselect.pack.js"></script>
# <script type="text/javascript" src="/js/jquery.imgareaselect-0.9.11/scripts/jquery.imgareaselect.touch-support.js"></script>
# <script type="text/javascript" src="/js/imgareaselect-1.0.0/jquery.imgareaselect.min.js"></script> --> seems broken
  


	$scripts .= <<HTML
<script type="text/javascript" src="/js/cropper-20150415/dist/cropper.min.js"></script>
<script type="text/javascript" src="/js/jquery.tagsinput.20150416/jquery.tagsinput.min.js"></script>
<script type="text/javascript" src="/js/jquery.form.js"></script>
<script type="text/javascript" src="/js/jquery.autoresize.js"></script>
<script type="text/javascript" src="/js/jquery.rotate.js"></script>
<script type="text/javascript" src="/js/jquery.iframe-transport.js"></script>
<script type="text/javascript" src="/js/jquery.fileupload.js"></script>	
<script type="text/javascript" src="/js/load-image.min.js"></script>
<script type="text/javascript" src="/js/canvas-to-blob.min.js"></script>
<script type="text/javascript" src="/js/jquery.fileupload-ip.js"></script>
<script type="text/javascript" src="/js/product-foundation.js"></script>

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

#ocrbutton_ingredients {
	margin-top:1rem;
}

#label_new_code, #new_code { display: inline; margin-top: 0px; width:200px; }

th {
	font-weight:bold;
}
CSS
;

	my $label_new_code = $Lang{new_code}{$lang};
	
	$html .= <<HTML
<label for="new_code" id="label_new_code">${label_new_code}</label>
<input type="text" name="new_code" id="new_code" class="text" value="" />			

<div data-alert class="alert-box info">
<span>$Lang{warning_3rd_party_content}{$lang}
 <a href="#" class="close">&times;</a>
</div>

<div data-alert class="alert-box secondary">
<span>$Lang{licence_accept}{$lang}</span>
 <a href="#" class="close">&times;</a>
</div>
HTML
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
			$lang_labels{$l} = $l;
		}
	}
	my $lang_value = $lang;
	if (defined $product_ref->{lang}) {
		$lang_value = $product_ref->{lang};
	}
	
	$html .= popup_menu(-name=>'lang', -default=>$lang_value, -values=>\@lang_values, -labels=>\%lang_labels);


	$html .= "<div class=\"fieldset\"><legend>$Lang{product_image}{$lang}</legend>";
	
	$html .= display_select_crop($product_ref, "front");

	$html .= "</div><!-- fieldset -->";	
	
	$html .= <<HTML

<div class="fieldset">
<legend>$Lang{product_characteristics}{$lang}</legend>
HTML
;
	
	my %remember_fields = ('purchase_places'=>1, 'stores'=>1);
	
	sub display_field($$$) {
	
		my $product_ref = shift;
		my $html_ref = shift;
		my $field = shift;
	
		my $tagsinput = '';
		if (defined $tags_fields{$field}) {
			$tagsinput = ' tagsinput';
			
			my $remember = '';
			if (defined $remember_fields{$field}) {
				$remember = <<HTML
	'onChange': function () { \$.cookie('remember_$field', \$("#$field").val(), { expires: 30 }); },
HTML
;
			}
		
# 	
		
			$initjs .= <<HTML
\$('#$field').tagsInput({ $remember
	'height':'3rem',
	'width':'100%',
	'interactive':true,
	'minInputWidth':130,
	'delimiter': [','],
	'defaultText':"$Lang{$field . "_tagsinput"}{$lang}"
});
HTML
;			
		}
		
		my $value = $product_ref->{$field};
		if (defined $product_ref->{$field . "_orig"}) {
			$value = $product_ref->{$field . "_orig"};
		}
		if (defined $taxonomy_fields{$field}) {
			$value = display_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field . "_hierarchy"});
			# Remove tags
			$value =~ s/<(([^>]|\n)*)>//g;
		}			

		$$html_ref .= <<HTML
<label for="$field">$Lang{$field}{$lang}</label>
<input type="text" name="$field" id="$field" class="text${tagsinput}" value="$value" />		
HTML
;
		if (defined $Lang{$field . "_note"}{$lang}) {
			$$html_ref .= <<HTML
<p class="note">&rarr; $Lang{$field . "_note"}{$lang}</p>			
HTML
;
		}
		
		if (defined $Lang{$field . "_example"}{$lang}) {
		
			my $examples = $Lang{example}{$lang};
			if ($Lang{$field . "_example"}{$lang} =~ /,/) {
				$examples = $Lang{examples}{$lang};
			}
		
			$$html_ref .= <<HTML
<p class="example">$examples $Lang{$field . "_example"}{$lang}</p>			
HTML
;
		}
	
	}
	
	if ($type eq 'add') {	# must be before creating the fields with tagsinput so that the value can be taken into account
	
		$initjs .= <<HTML

if (\$.cookie('remember_purchase_places_and_stores') == 'true') {
	\$("#remember_purchase_places_and_stores").attr('checked', true);
	\$("#purchase_places").val(\$.cookie('remember_purchase_places'));
	\$("#stores").val(\$.cookie('remember_stores'));
}

\$.cookie('remember_purchase_places_and_stores', \$("#remember_purchase_places_and_stores").is(':checked'), { expires: 30 });

\$("#remember_purchase_places_and_stores").change(function () {
	\$.cookie('remember_purchase_places_and_stores', \$("#remember_purchase_places_and_stores").is(':checked'), { expires: 30 });
});


HTML
;	

	}	
	
	# print STDERR "product.pl - fields : " . join(", ", @fields) . "\n";
	
	foreach my $field (@fields) {
		print STDERR "product.pl - display_field $field - value $product_ref->{$field}\n";
		display_field($product_ref, \$html, $field);
	}
	
	if ($type eq 'add') {
	
		$html .= <<HTML
<input type="checkbox" id="remember_purchase_places_and_stores" name="remember_purchase_places_and_stores" />
<label for="remember_purchase_places_and_stores" class="checkbox_label">$Lang{remember_purchase_places_and_stores}{$lang}</label>
HTML
;

	}

	$html .= "</div><!-- fieldset -->\n";
	

	$html .= "<div class=\"fieldset\"><legend>$Lang{ingredients}{$lang}</legend>\n";

	$html .= display_select_crop($product_ref, "ingredients");
	
	$html .= <<HTML
<label for="ingredients_text">$Lang{ingredients_text}{$lang}</label>
<textarea id="ingredients_text" name="ingredients_text">$product_ref->{ingredients_text}</textarea>
<p class="note">&rarr; $Lang{ingredients_text_note}{$lang}</p>			
<p class="example">$Lang{example}{$lang} $Lang{ingredients_text_example}{$lang}</p>			
HTML
;

	# $initjs .= "\$('textarea#ingredients_text').autoResize();";
	# ! with autoResize, extracting ingredients from image need to update the value of the real textarea
	# maybe calling $('textarea.growfield').data('AutoResizer').check(); 
	
	display_field($product_ref, \$html, "traces");

$html .= "</div><!-- fieldset -->
<div class=\"fieldset\"><legend>$Lang{nutrition_data}{$lang}</legend>\n";

	my $checked = '';
	if ($product_ref->{no_nutrition_data} eq 'on') {
		$checked = 'checked="checked"';
	}

	$html .= <<HTML
<input type="checkbox" id="no_nutrition_data" name="no_nutrition_data" $checked />	
<label for="no_nutrition_data" class="checkbox_label">$Lang{no_nutrition_data}{$lang}</label><br/>
HTML
;

	$html .= display_select_crop($product_ref, "nutrition");
	
	$initjs .= display_select_crop_init($product_ref);
	
	
	my $hidden_inputs = '';
	
	#<p class="note">&rarr; $Lang{nutrition_data_table_note}{$lang}</p>
	
	display_field($product_ref, \$html, "serving_size");
	
	my $checked_per_serving = '';
	my $checked_per_100g = 'checked="checked"';
	
	if ($product_ref->{nutrition_data_per} eq 'serving') {
		$checked_per_serving = 'checked="checked"';
		$checked_per_100g = '';
	}
	
	
	
	$html .= <<HTML
<div style="position:relative">


<table id="nutrition_data_table" class="data_table">
<thead class="nutriment_header">
<th colspan="2">
$Lang{nutrition_data_table}{$lang}<br/>
<input type="radio" id="nutrition_data_per_100g" value="100g" name="nutrition_data_per" $checked_per_100g /><label for="nutrition_data_per_100g">$Lang{nutrition_data_per_100g}{$lang}</label>
<input type="radio" id="nutrition_data_per_serving" value="serving" name="nutrition_data_per" $checked_per_serving /><label for="nutrition_data_per_serving">$Lang{nutrition_data_per_serving}{$lang}</label>
</th>
</thead>

<tbody>
HTML
;

	my $html2 = ''; # for ecological footprint

	defined $product_ref->{nutriments} or $product_ref->{nutriments} = {};

	my @unknown_nutriments = ();
	foreach my $nid (keys %{$product_ref->{nutriments}}) {
	
		next if $nid =~ /_/;

		print STDERR "product.pl - unknown_nutriment: $nid ?\n";
		
		if ((not exists $Nutriments{$nid}) and (defined $product_ref->{nutriments}{$nid . "_label"})) {
			push @unknown_nutriments, $nid;
			print STDERR "product.pl - unknown_nutriment: $nid !!!\n";
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
		
		# print STDERR "product.pl - shown: $shown - nid: $nid - nutriment: $nutriment \n";
		
		my $display = '';
		if ($nid eq 'new_0') {
			$display = ' style="display:none"';
		}
		
		my $label = '';
		if ((exists $Nutriments{$nid}) and (exists $Nutriments{$nid}{$lang})) {
			$label = <<HTML
<label class="nutriment_label" for="nutriment_$nid">${prefix}$Nutriments{$nid}{$lang}</label>
HTML
;
		}
		elsif (defined $product_ref->{nutriments}{$nid . "_label"}) {
			my $label_value = $product_ref->{nutriments}{$nid . "_label"};
			$label = <<HTML
<input class="nutriment_label" id="nutriment_${nid}_label" name="nutriment_${nid}_label" value="$label_value" />
HTML
;
		}
		else {	# add a nutriment
			$label = <<HTML
<input class="nutriment_label" id="nutriment_${nid}_label" name="nutriment_${nid}_label" placeholder="$Lang{product_add_nutrient}{$lang}"/>
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
		my $value = g_to_unit($product_ref->{nutriments}{$nid}, $unit);
		
		# user unit and value ? (e.g. DV for vitamins in US)
		if ((defined $product_ref->{nutriments}{$nid . "_value"}) and (defined $product_ref->{nutriments}{$nid . "_unit"})) {
			$unit = $product_ref->{nutriments}{$nid . "_unit"};
			$value = $product_ref->{nutriments}{$nid . "_value"};
			if (defined $product_ref->{nutriments}{$nid . "_modifier"}) {
				$product_ref->{nutriments}{$nid . "_modifier"} eq '<' and $value = "&lt; $value";
				$product_ref->{nutriments}{$nid . "_modifier"} eq '>' and $value = "&gt; $value";
				$product_ref->{nutriments}{$nid . "_modifier"} eq '~' and $value = "~ $value";
			}
		}
		
		print STDERR "nutriment: $nutriment - nid: $nid - shown: $shown - class: $class - prefix: $prefix \n";
		
		my $input = '';
		
		
		$input .= <<HTML
<tr id="nutriment_${nid}_tr" class="nutriment_$class"$display>
<td>$label</td>
<td>
<input class="nutriment_value" id="nutriment_$nid" name="nutriment_$nid" value="$value" />
HTML
;

		if ($nid ne 'alcohol') {
		
		$input .= <<HTML
<select class="nutriment_unit" id="nutriment_${nid}_unit" name="nutriment_${nid}_unit">
HTML
;


		my @units = ('g','mg','µg');
		if ($nid =~ /^energy/) {
			@units = ('kJ','kcal');
		}
		elsif ($nid eq 'alcohol') {
			@units = ('% vol');
		}
		if (((exists $Nutriments{$nid}) and ($Nutriments{$nid}{dv} > 0))
			or ($nid =~ /^new_/)) {
			push @units, '% DV';
		}
		
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
		if ($product_ref->{nutriments}{$nid} eq '') {
			$other_nutriments .= '{ "value" : "' . $Nutriments{$nid}{$lang} . '", "unit" : "' . $Nutriments{$nid}{unit} . '" },' . "\n";
		}
		$nutriments .= '"' . $Nutriments{$nid}{$lang} . '" : "' . $nid . '",' . "\n";
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
	sodium = \$("#nutriment_sodium").val();
	sodium = sodium.replace(",", ".");
	\$("#nutriment_salt").val(sodium * 2.54);
}
);

\$("#nutriment_salt").change( function () {
	salt = \$("#nutriment_salt").val();
	salt = salt.replace(",", ".");
	\$("#nutriment_sodium").val(salt / 2.54);
}
);

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
<tr><th colspan="2">$Lang{ecological_data_table}{$lang}</th>
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
	
	if ($type eq 'edit') {
		$html .= <<HTML
<label for="comment" style="margin-left:10px">$Lang{edit_comment}{$lang}</label>
<input id="comment" name="comment" value="" type="text" class="text" />
HTML
	}
	
	$html .= <<HTML
<input type="submit" name=".submit" value="$Lang{save}{$lc}" class="button small" />
</form>
HTML
;

	# Display history
	
	if ($product_ref->{rev} > 0) {
	
		my $path = product_path($code);
		my $changes_ref = retrieve("$data_root/products/$path/changes.sto");
		if (not defined $changes_ref) {
			$changes_ref = [];
		}
		
		$html .= "<h2>" . lang("history") . "</h2>\n<ul>\n";
		
		my $current_rev = $product_ref->{rev};
		
		foreach my $change_ref (reverse @{$changes_ref}) {
		
			my $date = display_date($change_ref->{t});	
			my $user = "<a href=\"" . canonicalize_tag_link("users", get_fileid($change_ref->{userid})) . "\">" . $change_ref->{userid} . "</a>";
			my $comment = $change_ref->{comment};
			
			
			$comment =~ s/^Modification :\s+//;
			if (($comment =~ /^new image/) or ($comment eq 'Modification :')) {
				$comment = '';
			}
			
			if ($comment ne '') {
				$comment = "- $comment";
			}
			
			my $change_rev = $change_ref->{rev};
			
			if (not defined $change_rev) {
				$change_rev = $current_rev;
			}
			$current_rev--;
			
			# Display diffs
			# [Image upload - add: 1, 2 - delete 2], [Image selection - add: front], [Nutriments... ]
			
			my $diffs = '';
			if (defined $change_ref->{diffs}) {
				my %diffs = %{$change_ref->{diffs}};
				foreach my $group ('uploaded_images', 'selected_images', 'fields', 'nutriments') {
					if (defined $diffs{$group}) {
						$diffs .= lang("change_$group") . " ";
									
						foreach my $diff ('add','change','delete') {
							if (defined $diffs{$group}{$diff}) {
								$diffs .= "(" . lang("diff_$diff") . ' ' ;
								my @diffs = @{$diffs{$group}{$diff}};
								if ($group eq 'fields') {
									@diffs = map( lang($_), @diffs);
								}
								elsif ($group eq 'nutriments') {
									# @diffs = map( $Nutriments{$_}{$lc}, @diffs);
									# Attempt to access disallowed key 'nutrition-score' in a restricted hash at /home/off-fr/cgi/product.pl line 1039.
									my @lc_diffs = ();
									foreach my $nid (@diffs) {
										if (exists $Nutriments{$nid}) {
											push @lc_diffs, $Nutriments{$nid}{$lc};
										}
									}
								}
								$diffs .= join(", ", @diffs) ;
								$diffs .= ") ";
							}
						}
						
						$diffs .= "-- ";
					}
				}
				$diffs =~  s/-- $//;
			}
			
			$html .= "<li>$date - $user $diffs $comment - <a href=\"" . product_url($product_ref) . "?rev=$change_rev\">" . lang("view") . "</a></li>\n";
		
		}
		
		$html .= "</ul>\n";
	}
	



}
elsif (($action eq 'display') and ($type eq 'delete')) {

	$debug and print STDERR "product.pl action: display type: $type code $code\n";
	
	$html .= start_multipart_form(-id=>"product_form") ;
		
	$html .= <<HTML
<p>Etes-vous sûr de vouloir supprimer la fiche de ce produit ? (nom : $product_ref->{product_name}, code barre: $code)</p>

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
	. submit(-name=>'save', -label=>"Supprimer la fiche", -class=>"button small")
	. end_form();

}
elsif ($action eq 'process') {

	$debug and print STDERR "product.pl action: process - phase 2 - type: $type code $code\n";
	#use Data::Dumper;
	#print STDERR Dumper($product_ref);
	
	$product_ref->{interface_version_modified} = $interface_version;
	
	if ($type eq 'delete') {
		$product_ref->{deleted} = 'on';
		$comment = "Suppression : ";
	}
	
	my $time = time();
	$comment = $comment . remove_tags_and_quote(decode utf8=>param('comment'));
	store_product($product_ref, $comment);
	
	$html .= "<p>" . lang("product_changes_saved") . "</p><p>&rarr; <a href=\"" . product_url($product_ref) . "\">"
		. lang("see_product_page") . "</a></p>";
		
	if ($type eq 'delete') {
		my $email = <<MAIL
$User_id supprime :

$html
	
MAIL
;
		send_email_to_admin("Suppression produit", $email);
	
	}
	
}

$html = "<p>" . lang("barcode") . lang("sep") . ": $code</p>\n" . $html;

display_new( {
	blog_ref=>undef,
	blogid=>'all',
	tagid=>'all',
	title=>lang($type . '_product'),
	content_ref=>\$html,
	full_width=>1,
});


exit(0);

