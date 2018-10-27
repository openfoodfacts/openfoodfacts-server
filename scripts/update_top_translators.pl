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

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

use ProductOpener::Config qw/:all/;

use LWP::UserAgent;
use JSON::PP;

if ((not defined $crowdin_project_identifier) or ($crowdin_project_identifier eq '')) {
	die('$ProductOpener::Config::crowdin_project_identifier not specified');
}

if ((not defined $crowdin_project_key) or ($crowdin_project_key eq '')) {
	die('$ProductOpener::Config::crowdin_project_key not specified');
}

sub create_export {
	my $url = "https://api.crowdin.com/api/project/$crowdin_project_identifier/reports/top-members/export?json&format=csv&key=" . $crowdin_project_key;
	my $ua = LWP::UserAgent->new();

	my $request = HTTP::Request->new(POST => $url);
	my $res = $ua->request($request);
		
	if ($res->is_success) {

		print STDERR "create_export: success\n";

		my $json_response = $res->decoded_content;
		my $json_ref = decode_json($json_response);

		if ((defined $json_ref->{success}) and ($json_ref->{success}) and (defined $json_ref->{hash})) {
			print STDERR "create_export: found hash: " . $json_ref->{hash} . "\n";
			return (0, $json_ref->{hash});
		}
		else {
			print STDERR "create_export: hash not found in response: " . $json_response . "\n";
			return 2;
		}
	}
	else {
		print STDERR "create_export: not ok - url: $url - code: " . $res->code . " - message: " . $res->message . "\n";
		return 1;
	}
}

sub download_export {

	my $hash = shift;

	my $url = "https://api.crowdin.com/api/project/$crowdin_project_identifier/reports/top-members/download?key=" . $crowdin_project_key . "&hash=" . $hash;
	my $ua = LWP::UserAgent->new();

	my $request = HTTP::Request->new(GET => $url);
	my $res = $ua->request($request);
	
	if ($res->is_success) {

		print STDERR "download_export: success\n";

		my $csv_response = $res->decoded_content;
		my $filename = "$www_root/data/top_translators.csv";
		print STDERR "download_export: saving response to $filename\n";
		
		open (my $OUT, ">:encoding(UTF-8)", $filename);
		print $OUT $csv_response;
		close $OUT;	

		print STDERR "download_export: saved response to $filename\n";
	}
	else {
		print STDERR "download_export: not ok - url: $url - code: " . $res->code . " - message: " . $res->message . "\n";
		return 1;
	}
}

my ($status, $hash) = create_export();

if ($status > 0) {
	exit($status);
}
else {
	$status = download_export($hash);
	exit($status);
}