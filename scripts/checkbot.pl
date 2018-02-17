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

use Encode;

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
use JSON;

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
my $server_endpoint = "https://hooks.slack.com/services/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";


sub send_msg($) {

	my $msg = shift;
	
# set custom HTTP request header fields
	my $req = HTTP::Request->new(POST => $server_endpoint);
	$req->header('content-type' => 'application/json');
	 
	# add POST data to HTTP request body
	my $post_data = '{"channel": "#bots", "username": "checkbot", "text": "' . $msg . '", "icon_emoji": ":hamster:" }';
	$req->content_type("text/plain; charset='utf8'");
	$req->content(Encode::encode_utf8($post_data));
	 
	my $resp = $ua->request($req);
	if ($resp->is_success) {
		my $message = $resp->decoded_content;
		print "Received reply: $message\n";
	}
	else {
		print "HTTP POST error code: " .  $resp->code . "\n";
		print "HTTP POST error message: " . $resp->message . "\n";
	}
	
}

my $cursor = $products_collection->query({})->fields({ code => 1 });;
my $count = $cursor->count();
	
	print STDERR "$count products to update\n";
	
	while (my $product_ref = $cursor->next) {
        
		
		my $code = $product_ref->{code};
		my $path = product_path($code);
		
		print STDERR "updating product $code\n";
		
		$product_ref = retrieve_product($code);
		
		if (not defined $product_ref) {
			print "product code $code not found\n";
		}
		else {
		
			if (defined $product_ref->{nutriments}) {
			
				next if has_tag($product_ref, "labels", "fr:informations-nutritionnelles-incorrectes");
				next if has_tag($product_ref, "labels", "en:incorrect-nutrition-facts-on-label");
				
				my $name = get_fileid($product_ref->{product_name});
				my $brands = get_fileid($product_ref->{brands});
			
				foreach my $nid (keys %{$product_ref->{nutriments}}) {
					next if $nid =~ /_/;
					
					if (($nid !~ /energy/) and ($nid !~ /footprint/) and ($product_ref->{nutriments}{$nid . "_100g"} > 105)) {
					
						my $msg = "Product <https://world.openfoodfacts.org/product/$code> ($name / $brands) : $nid = "
						. $product_ref->{nutriments}{$nid . "_100g"} . "g / 100g";
						
						print "$code : " . $msg . "\n";
						
						send_msg($msg);
#exit;						
			
					}
				}
				
				if ((defined $product_ref->{nutriments}{"carbohydrates_100g"}) and (($product_ref->{nutriments}{"sugars_100g"} + $product_ref->{nutriments}{"starch_100g"}) > ($product_ref->{nutriments}{"carbohydrates_100g"}) + 0.001)) {
				
						my $msg = "Product <https://world.openfoodfacts.org/product/$code> ($name / $brands) : sugars (" . $product_ref->{nutriments}{"sugars_100g"}  . ") + starch (" .  $product_ref->{nutriments}{"starch_100g"}. ") > carbohydrates (" . $product_ref->{nutriments}{"carbohydrates_100g"}  . ")";
						
						print "$code : " . $msg . "\n";
						
						send_msg($msg);				
				
				}
			}		
		
		}
	}

exit(0);


