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

use Geo::IP;
my $gi = Geo::IP->new(GEOIP_MEMORY_CACHE);

# 82.226.239.239 - - [10/Oct/2013:13:59:37 +0200] "GET /cgi/display.pl?/api/v0.1/product/5449000058560.jqm.json HTTP/1.1" 200 17176 "-" "Mozilla/5.0 (Linux; U; Android 4.0.4; fr-fr; WIKO-CINK SLIM Build/IMM76D) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30"

my %codes = ();

# to remove searches
my %seen_ip = ();

my $i = 0;
my $searches = 0;
my $skipped = 0;

while (<STDIN>)
{
		my $line = $_;
		my $ip = $_;
		$ip =~ s/\s.*//;
		chomp($ip);
		
		if ($line =~ /cgi\/search/) {
			$seen_ip{$ip} = $i;
			$searches++;
		}

        if ($line =~ /\/(\d+)\.jqm\.json/)
        {
		$i++;
		my $code = $1;
		
		# skip if the ip was searching just before
		if ((defined $seen_ip{$ip}) and (($seen_ip{$ip} + 20) > $i)) {
			$skipped++;
			next;
		}
		

		defined $codes{$code} or $codes{$code} = {n => 0, ips => {}};
                $codes{$code}{n}++;
                $codes{$code}{ips}{$ip}++;
        }
}


my $i = 0;

my $changed_products = 0;
my $added_countries = 0;

foreach my $code (sort { $codes{$a}{n} <=> $codes{$b}{n}} keys %codes)
{
		$i++;
		
		my $scans_n = $codes{$code}{n};
		my $unique_scans_n = (scalar keys %{$codes{$code}{ips}});

		my $bot = '';
		
		my %countries = ();
		foreach my $ip (keys %{$codes{$code}{ips}}) {
			my $countrycode = $gi->country_code_by_addr($ip);
			$countries{$countrycode}++;
		}

		print "$i\t$code\t$codes{$code}{n}\t" . $unique_scans_n . "\t";
		
		$bot .= "product code $code scanned $scans_n times (from $unique_scans_n ips) - ";
		
		foreach my $cc (sort { $countries{$b} <=> $countries{$a} } keys %countries) {
			print "$cc:$countries{$cc} ";
			$bot .= "$cc:$countries{$cc} ";
		}
		print "\n";

		$bot .= " -- ";
		
		if ($unique_scans_n > 0) {
		
		my $path = product_path($code);
		
		print  "$i - checking product $code - scans: $scans_n unique_scans: $unique_scans_n \n";
		
		my $product_ref = retrieve_product($code);
		
		if ((defined $product_ref) and ($code ne '')) {
		
		$lc = $product_ref->{lc};
		
		
		$product_ref->{unique_scans_n} = $unique_scans_n + 0;
		$product_ref->{scans_n} = $scans_n + 0;
		
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
			if ($countries{$cc} >= 3) {
				my $country = canonicalize_taxonomy_tag('en', "countries", $cc);
				if (not exists $existing{$country}) {
					print "- adding $country to $product_ref->{countries}\n";
					$product_ref->{countries} .= ", $country";
					$bot .= "+$country ";
					$added_countries++;
				}
			}
		}
		
		# next if ($code ne '3017620401473');
		
		if ($product_ref->{$field} ne $current_countries) {
			$product_ref->{"countries.beforescanbot"} = $current_countries;
			$changed_products++;
		
		if ($product_ref->{$field} =~ /^, /) {
			$product_ref->{$field} = $';
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
			
			
		my $comment = $bot;
			
		#if ($code eq '3033710073511') {
		if (1) {
			# notify slack
			#  payload={"text": "A very important thing has occurred! <https://alert-system.com/alerts/1234|Click here> for details!"}
			
			# curl -X POST --data-urlencode 'payload={"channel": "#general", "username": "webhookbot", "text": "This is posted to #general and comes from a bot named webhookbot.", "icon_emoji": ":ghost:"}' https://openfoodfacts.slack.com/services/hooks/incoming-webhook?token=jMDE8Fzkz9qD7uC9Lq04fbZH
			
			# my $data =  encode_json(\%response);
			
			$bot .= " -- <https://world.openfoodfacts.org/product/$code>";
			
			print "notifying slack: $bot\n";
			
			use LWP::UserAgent;
 
			my $ua = LWP::UserAgent->new;
			 
			my $server_endpoint = "https://openfoodfacts.slack.com/services/hooks/incoming-webhook?token=jMDE8Fzkz9qD7uC9Lq04fbZH";
			 
			# set custom HTTP request header fields
			my $req = HTTP::Request->new(POST => $server_endpoint);
			$req->header('content-type' => 'application/json');
			 
			# add POST data to HTTP request body
			my $post_data = '{"channel": "#bots", "username": "scanbot", "text": "' . $bot . '", "icon_emoji": ":ghost:" }';
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
		
		$User_id = 'scanbot';
		store_product($product_ref, $comment);
		
		
		
		}
		else {
			print "updating scan count for $code\n";
			store("$data_root/products/$path/product.sto", $product_ref);		
			get_products_collection()->save($product_ref);
		}
		
		#update the number of scans
		
			
		# Store
		if ($code eq '!3033710076017') 
		{
		#store("$data_root/products/$path/product.sto", $product_ref);		
		#get_products_collection()->save($product_ref);
		}
		

		
		}		
		
		}
}

if (($changed_products > 0) and ($added_countries > 0)) {

	my $msg = "\nI added $added_countries countries to $changed_products products\n\n";
	print $msg;
	
use LWP::UserAgent;
 
			my $ua = LWP::UserAgent->new;
			 
			my $server_endpoint = "https://openfoodfacts.slack.com/services/hooks/incoming-webhook?token=jMDE8Fzkz9qD7uC9Lq04fbZH";
			 
			# set custom HTTP request header fields
			my $req = HTTP::Request->new(POST => $server_endpoint);
			$req->header('content-type' => 'application/json');
			 
			# add POST data to HTTP request body
			my $post_data = '{"channel": "#bots", "username": "scanbot", "text": "' . $msg . '", "icon_emoji": ":ghost:" }';
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
 
print "searches: $searches -- skipped: $skipped\n";

