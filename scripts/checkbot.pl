#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Foss�s, France
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

my $usage = <<TXT
checkbot.pl is a script that controls product quality and sends alerts to
a slack channel.

Usage:

checkbot.pl --max_sendings=2 --country=France --order=random --channel=\#bot-alerts
Only --channel is mandatory.
--max_sending: max number of alerts to be sent; default: 10
--country: a country name in english, eg. "belgium"; all countries if omited
--order: last modified products if omited; "random" sends products in random order
--channel: name of the slack channel: #fr, for example, or \@UserName to make tests

TXT
;
# use "--channel=STDIN" to print results on STDIN and not send any message to Slack

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
use ProductOpener::Data qw/:all/;
use ProductOpener::Data qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Getopt::Long;

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;

# Initial settings
my $max_sendings = 10; # maximum number of alerts sent by the bot
# The bot use "incoming webhooks" of slack
#   Doc: https://api.slack.com/incoming-webhooks
#   OFF webhooks settings: https://openfoodfacts.slack.com/services/B033QD1T1
my $server_endpoint = "https://hooks.slack.com/services/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";
my $channel;
my $country = '';
my $product_order = '';


# Beginning
GetOptions (
	'max_sendings:i' => \$max_sendings,
	'country:s' => \$country,
	'order:s' => \$product_order,
	'channel=s' => \$channel 				# channel is mandatory
	) or die ("Error in command line arguments:\n\n$usage");

if (not defined $channel) {
	die ("--channel parameter is mandatory.\n\n$usage");
}

my $sendings = 0; # Number of alerts sent by the bot

sub send_msg($) {

	# Don't send and exit if the number of alerts sent equal the maximum allowed
	if ($sendings == $max_sendings) {
		exit(0);
	}
	$sendings++;
	my $msg = shift;

	# if "channel=STDIN" don't send any message on slack
	if ($channel eq "STDIN") {
		return;
	}

	# set custom HTTP request header fields
	my $req = HTTP::Request->new(POST => $server_endpoint);
	$req->header('content-type' => 'application/json');

	# add POST data to HTTP request body
	#   * tests can be made with "channel": "@YourAccount" instead of "#bots-alert"
	my $post_data = '{"channel": "' . $channel . '", "username": "checkbot", "text": "' . $msg . '", "icon_emoji": ":hamster:"}';
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

my $query = {};

# If --country is specified, build the query with the country
if ($country ne "") {
	$country =~ s/^(en:)?(.*)/en:$2/g; # "en:Country" or "Country" => "en:Country"
	$query = { 'countries_tags' => $country };
}

# Select the products in reverse order
my $cursor = get_products_collection()->query($query)->fields({ code => 1 })->sort({code =>-1});
my $count = $cursor->count();
print STDERR "$count products to update\n";

# If --order parameter is random, select all the products again, but in a random order
if ($product_order eq "random") {
	my $aggregate_parameters = [
		{ "\$match" => $query },
		{ "\$sample" => { "size" => $count } }
	];
	$cursor = get_products_collection()->aggregate($aggregate_parameters);
}

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

						my $msg = "Product <https://world.openfoodfacts.org/product/$code> ($name / $brands) : *$nid* = "
						. $product_ref->{nutriments}{$nid . "_100g"} . "g / 100g";

						print "$code : " . $msg . "\n";

						send_msg($msg);

					}
				}

				# Control that require computation and not just comparison
				if (defined $product_ref->{nutriments}{"carbohydrates_100g"}) {
					my $sugars = $product_ref->{nutriments}{"sugars_100g"} // 0;
					my $starch = $product_ref->{nutriments}{"starch_100g"} // 0;
					if ($sugars + $starch > $product_ref->{nutriments}{"carbohydrates_100g"} + 0.001) {

						my $msg = "Product <https://world.openfoodfacts.org/product/$code> ($name / $brands) : sugars (" . $sugars  . ") + starch (" .  $starch . ") > carbohydrates (" . $product_ref->{nutriments}{"carbohydrates_100g"}  . ")";

						print "$code : " . $msg . "\n";

						send_msg($msg);
					}
				}
			}

		}
	}

exit(0);
