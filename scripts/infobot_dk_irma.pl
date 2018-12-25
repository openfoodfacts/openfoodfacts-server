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

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2012';
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


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

my %codes = ();

my $botid = "mathias";
my $bug = "https://github.com/openfoodfacts/outside-data/issues/1";

my %add_info_to_tags = (
	stores => "Irma.dk",
);

my %countries;

$countries{dk} = 1;

open (my $IN, q{<}, "dk-irma-products-list-20150602.csv") or die;

my $fields = <$IN>;
chomp($fields);

my @fields = split(/;/, $fields);
my %fields = ();
foreach (my $i = 0; $i <= $#fields ; $i++) {
	$fields{$fields[$i]} = $i;
}

my $changed_products = 0;
my $added_countries = 0;

my $i = 0;

while(<$IN>) {
	chomp;
	@fields = split(/;/, $_);
	my $code = $fields[$fields{Stregkode}];
	
	
	#next if ($code ne '3017760002073');	
	
	print STDERR "product code: $code\n";


	my $changed = 0;


	my $bot = "infobot_dk_irma - user: $botid - ";
	
	$i++;

	print "$i\t$code\t$codes{$code}{n}\t" ;
	
	$bot .= "product code $code - ";
	
	foreach my $cc (sort { $countries{$b} <=> $countries{$a} } keys %countries) {
		print "$cc:$countries{$cc} ";
		$bot .= "$cc:$countries{$cc} ";
	}
	print "\n";

	$bot .= " -- ";

	
	my $path = product_path($code);
	
	print  "$i - checking product $code \n";
	
	my $product_ref = retrieve_product($code);
		
	if ((defined $product_ref) and ($code ne '')) {
		
		$lc = $product_ref->{lc};
		
		
		# Update
		my $field = 'countries';
		
		my $current_countries = $product_ref->{$field};

		my %existing = ();
		foreach my $countryid (@{$product_ref->{countries_tags}}) {
			$existing{$countryid} = 1;
		}
		
		$bot .= " current countries: $current_countries -- adding ";
		
		foreach my $cc (sort { $countries{$b} <=> $countries{$a} } keys %countries) {
			print "$cc:$countries{$cc} ";
			if ($countries{$cc} ) {
				my $country = canonicalize_taxonomy_tag('en', "countries", $cc);
				if (not exists $existing{$country}) {
					print "- adding $country to $product_ref->{countries}\n";
					$product_ref->{countries} .= ", $country";
					$bot .= "+$country ";
					$added_countries++;
					$changed++;
					
					my $field = 'countries';
					$product_ref->{$field . "_hierarchy" } = [ gen_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field}) ];
					$product_ref->{$field . "_tags" } = [];
					foreach my $tag (@{$product_ref->{$field . "_hierarchy" }}) {
						push @{$product_ref->{$field . "_tags" }}, get_taxonomyid($tag);
					}					
				}
			}
		}
		

	
		
		if ($product_ref->{countries} =~ /^, /) {
			$product_ref->{countries} = $';
		}
		
		
		foreach my $field (keys %add_info_to_tags) {
			if ($product_ref->{$field} !~ /$add_info_to_tags{$field}/i) {
				$product_ref->{$field} .= ", " . $add_info_to_tags{$field};
				$product_ref->{$field} =~ s/^, //;
				$changed++;
				
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
				
				if (defined $hierarchy_fields{$field}) {		
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


			
		my $comment = $bot . " - $bug";
			
		#if ($code eq '3033710073511') {
		if ($changed) {
			# notify slack
			#  payload={"text": "A very important thing has occurred! <https://alert-system.com/alerts/1234|Click here> for details!"}
			
			# curl -X POST --data-urlencode 'payload={"channel": "#general", "username": "webhookbot", "text": "This is posted to #general and comes from a bot named webhookbot.", "icon_emoji": ":ghost:"}' https://openfoodfacts.slack.com/services/hooks/incoming-webhook?token=jMDE8Fzkz9qD7uC9Lq04fbZH
			
			# my $data =  encode_json(\%response);
			
			$bot .= " -- <https://world.openfoodfacts.org/product/$code>";
			
			print "notifying slack: $bot\n";
			
			use LWP::UserAgent;
 
			my $ua = LWP::UserAgent->new;
			 
			my $server_endpoint = "https://hooks.slack.com/services/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";
			 
			# set custom HTTP request header fields
			my $req = HTTP::Request->new(POST => $server_endpoint);
			$req->header('content-type' => 'application/json');
			 
			# add POST data to HTTP request body
			my $post_data = '{"channel": "#bots", "username": "infobot", "text": "' . $bot . '", "icon_emoji": ":rabbit:" }';
			$req->content($post_data);
			 
			my $resp = $ua->request($req);
			if ($resp->is_success) {
				my $message = $resp->decoded_content;
				print "Received reply: $message\n";
			}
			else {
				print "HTTP POST error code: ", $resp->code, "\n";
				print "HTTP POST error message: ", $resp->message, "\n";
			}
			
			
		
		
			$User_id = $botid;
			store_product($product_ref, $comment);
			
			$changed_products ++;
		}			
		
	}
		
	
}


close($IN);

if (($changed_products > 0) and ($added_countries > 0)) {

	my $msg = "\nI added $added_countries countries to $changed_products products\n\n";
	print $msg;
	
use LWP::UserAgent;
 
			my $ua = LWP::UserAgent->new;
			 
			my $server_endpoint = "https://hooks.slack.com/services/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";
			 
			# set custom HTTP request header fields
			my $req = HTTP::Request->new(POST => $server_endpoint);
			$req->header('content-type' => 'application/json');
			 
			# add POST data to HTTP request body
			my $post_data = '{"channel": "#bots", "username": "infobot", "text": "' . $msg . '", "icon_emoji": ":rabbit:" }';
			$req->content($post_data);
			 
			my $resp = $ua->request($req);
			if ($resp->is_success) {
				my $message = $resp->decoded_content;
				print "Received reply: $message\n";
			}
			else {
				print "HTTP POST error code: ", $resp->code, "\n";
				print "HTTP POST error message: ", $resp->message, "\n";
			}	
	
}
 
print "i :$i\n";
