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
use MIME::Base64;


# Get a list of all products



	use HTTP::Request::Common;
	use LWP::UserAgent;
	use LWP::Authen::Digest;

	# Settings
	my $key = "6boshzcjfsqyxmnl9znd";
	my $secret = "ZunCQ56gcp53GhZb";

	# Boilerplate
	my $browser = LWP::UserAgent->new();
	$browser->credentials("api.moodstocks.com:80","Moodstocks API",$key,$secret);
	my $ep = "http://api.moodstocks.com/v2";
	
	my $url = "$ep/stats/refs";
	my $response = $browser->request(HTTP::Request->new("GET", $url));
	#print "stats -> url: $url\nreponse -> " . $response->content . "\n";	
	
	my $content = $response->content;
	#  {"count":44,"ids":["fairtrade","bioab","bioeurope","carbone","fairtrade2","domaine-de-l-echauguette","Montagny-1er-cru-2008",
	#$content =~ s/\\/\\/g;
	
	my @ids = split(/"/, $content);
	
	my $j = 0;
	
	foreach my $id (@ids) {
		
		next if $id =~ /,|:|\[|\]/;
		next if $id eq 'count';
		next if $id eq 'ids';
		
		$id =~ s/\\n/\n/g;
		
		$j++;

		print "id: $id\n";
		
		next if ($id !~ /^8715/);
		
		print "deleting id: $id\n";
		my $response = $browser->request(HTTP::Request->new("DELETE","$ep/ref/$id"));
		print "response -> " . $response->content . "\n";	
		last;
	
	
	}
		
		print "deleted $j products\n";

exit(0);

