#!/usr/bin/perl

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

use Apache2::RequestRec ();
use Apache2::Const ();

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

ProductOpener::Display::init();

$debug = 1;

my $comment = '(app)';

my $interface_version = '20150316.jqm2';

my %response = ();

my $code = normalize_code(param('code'));

$debug and print STDERR "product_jqm2.pl - code $code - lc $lc\n";

if ($code !~ /^\d+$/) {

	$debug and print STDERR "product_jqm2.pl - invalid code $code \n";
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
	
	process_product_edit_rules($product_ref);	
	
	#my @app_fields = qw(product_name brands quantity);
	my @app_fields = qw(product_name generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link expiration_date purchase_places stores countries  );

	
	# generate a list of potential languages for language specific fields
	my %param_langs = ();
	foreach my $param (param()) {
		if ($param =~ /^(.*)_(\w\w)$/) {
			if (defined $language_fields{$1}) {
				$param_langs{$2} = 1;
			}
		}
	}
	my @param_langs = keys %param_langs;
	
	foreach my $field (@app_fields, 'nutrition_data_per', 'serving_size', 'traces', 'ingredients_text','lang') {
	
		if (defined param($field)) {
			$product_ref->{$field} = remove_tags_and_quote(decode utf8=>param($field));
			
			if ((defined $language_fields{$field}) and (defined $product_ref->{lc})) {
				my $field_lc = $field . "_" . $product_ref->{lc};
				$product_ref->{$field_lc} = $product_ref->{$field};
			}			
			
			compute_field_tags($product_ref, $field);			
			
		}
		
		if (defined $language_fields{$field}) {
			foreach my $param_lang (@param_langs) {
				my $field_lc = $field . '_' . $param_lang;
				if (defined param($field_lc)) {
					$product_ref->{$field_lc} = remove_tags_and_quote(decode utf8=>param($field_lc));
					compute_field_tags($product_ref, $field_lc);
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

		my $enid = encodeURIComponent($nid);
		
		# do not delete values if the nutriment is not provided
		next if not defined param("nutriment_${enid}");
		
		my $value = remove_tags_and_quote(decode utf8=>param("nutriment_${enid}"));
		my $unit = remove_tags_and_quote(decode utf8=>param("nutriment_${enid}_unit"));
		my $label = remove_tags_and_quote(decode utf8=>param("nutriment_${enid}_label"));
		
		if ($value =~ /nan/i) {
			$value = '';
		}
		
		if ($nid eq 'alcohol') {
			$unit = '% vol';
		}
		
		my $modifier = undef;
		
		if ($value =~ /(\&lt;=|<=|\N{U+2264})( )?/) {
			$value =~ s/(\&lt;=|<=|\N{U+2264})( )?//;
			$modifier = "\N{U+2264}";
		}
		if ($value =~ /(\&lt;|<|max|maxi|maximum|inf|inférieur|inferieur|less)( )?/) {
			$value =~ s/(\&lt;|<|min|minimum|max|maxi|maximum|environ)( )?//;
			$modifier = '<';
		}
		if ($value =~ /(\&gt;=|>=|\N{U+2265})/) {
			$value =~ s/(\&gt;=|>=|\N{U+2265})( )?//;
			$modifier = "\N{U+2265}";
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
		if ((defined $label) and ($label ne '')) {
			$new_nid = canonicalize_nutriment($lc,$label);
			print STDERR "product_multilingual.pl - unknown nutrient $nid (lc: $lc) -> canonicalize_nutriment: $new_nid\n";
			
			if ($new_nid ne $nid) {
				delete $product_ref->{nutriments}{$nid};
				delete $product_ref->{nutriments}{$nid . "_unit"};
				delete $product_ref->{nutriments}{$nid . "_value"};
				delete $product_ref->{nutriments}{$nid . "_modifier"};
				delete $product_ref->{nutriments}{$nid . "_label"};
				delete $product_ref->{nutriments}{$nid . "_100g"};
				delete $product_ref->{nutriments}{$nid . "_serving"};			
				print STDERR "product_multilingual.pl - unknown nutrient $nid (lc: $lc) -> known $new_nid\n";
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
			if ((defined $modifier) and ($modifier ne '')) {
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
	

	$debug and print STDERR "product_jqm.pl - code $code - saving\n";
	#use Data::Dumper;
	#print STDERR Dumper($product_ref);
	
	$product_ref->{interface_version_modified} = $interface_version;
	
	
	my $time = time();
	$comment = $comment . remove_tags_and_quote(decode utf8=>param('comment'));
	store_product($product_ref, $comment);
	
	$response{status} = 1;
	$response{status_verbose} = 'fields saved';
}

my $data =  encode_json(\%response);
	
print header( -type => 'application/json', -charset => 'utf-8' ) . $data;


exit(0);

