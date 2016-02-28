#!/usr/bin/perl

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


	#my @app_fields = qw(product_name brands quantity);
	my @app_fields = qw(product_name generic_name quantity packaging brands categories labels origins manufacturing_places emb_codes link expiration_date purchase_places stores countries  );

	
	foreach my $field (@app_fields, 'nutrition_data_per', 'serving_size', 'traces', 'ingredients_text','lang') {
	

	
		if (defined param($field)) {
			$product_ref->{$field} = remove_tags_and_quote(decode utf8=>param($field));
			
			if ((defined $language_fields{$field}) and (defined $product_ref->{lc})) {
				my $field_lc = $field . "_" . $product_ref->{lc};
				$product_ref->{$field_lc} = $product_ref->{$field};
			}			
			
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
	}
	

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
		
		next if not defined param("nutriment_${nid}");
		

		my $value = remove_tags_and_quote(decode utf8=>param("nutriment_${nid}"));
		my $unit = remove_tags_and_quote(decode utf8=>param("nutriment_${nid}_unit"));
		my $label = remove_tags_and_quote(decode utf8=>param("nutriment_${nid}_label"));
		
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
		if ($value =~ /(env|environ|about|~|˜)/) {
			$value =~ s/(env|environ|about|~|˜)( )?//;
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
	
print "Content-Type: application/json; charset=UTF-8\r\n\r\n" . $data;	


exit(0);

