#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

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
use JSON;

ProductOpener::Display::init();

$debug = 1;

my $comment = '(app)';

my $interface_version = '20130323.jqm';

my %response = ();

my $code = normalize_code(param('code'));

$debug and print STDERR "product_jqm.pl - code $code - lc $lc\n";

if ($code !~ /^\d+$/) {

	$debug and print STDERR "product_jqm.pl - invalid code $code \n";
	$response{status} = 0;
	$response{status_verbose} = 'no code or invalid code';

}
else {

	my $product_ref = retrieve_product($code);
	if (not defined $product_ref) {
		$product_ref = init_product($code);
		$product_ref->{interface_version_created} = $interface_version;
	}


	my @app_fields = qw(product_name brands quantity expiration_date packaging);
	
	foreach my $field (@app_fields) {
		if (defined param($field)) {
			$product_ref->{$field} = remove_tags_and_quote(decode utf8=>param($field));
			
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

