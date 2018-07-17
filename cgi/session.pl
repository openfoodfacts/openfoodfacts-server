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

use Modern::Perl '2012';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Log::Any qw($log);

ProductOpener::Display::init();
use ProductOpener::Lang qw/:all/;



my $html = '';

if (defined $User_id) {
	$html = "<p>" . $Lang{hello}{$lang} . ' ' . $User{name} . separator_before_colon($lc) . "!" . "</p>";
	
	$html .= "<h3>" . lang("you_can_also_help_us") . "</h3>\n";
	$html .= "<p>" . lang("bottom_content") . "</p>\n";	
	
	my $next_action = param('next_action');
	my $code = param('code');
	my $r = shift;
	my $referer = $r->headers_in->{Referer};
	my $url;
	
	if ((defined $next_action) and ($code =~ /^(\d+)$/)) {
		if ($next_action eq 'product_add') {
			$url = "/cgi/product.pl?type=add&code=$code";
		}
		elsif ($next_action eq 'product_edit') {
			$url = "/cgi/product.pl?type=edit&code=$code";
		}
	}
	elsif ((defined $referer) and ($referer =~ /^https?:\/\/$subdomain\.$server_domain/) and (not ($referer =~ /(?:session|user)\.pl/))) {
		$url = $referer;
	}
	
	if (defined $url) {
		
		$log->info("redirecting after login", { url => $url }) if $log->is_info();
	
        $r->err_headers_out->add('Set-Cookie' => $cookie);
		$r->headers_out->set(Location =>"$url");
		$r->status(301);
		return 301;	
	}
}
else {
	$html = $Lang{goodbye}{$lang};
}

if (param('jqm')) {

	my %response;
	if (defined $User_id) {
		$response{user_id} = $User_id;
		$response{name} = $User{name};
	}
	else {
		$response{error} = "undefined user";
	}
	my $data =  encode_json(\%response);
	
	print header( -type => 'application/json', -charset => 'utf-8', -access_control_allow_origin => '*' ) . $data;
	
}
else {
	display_new( {
		title => lang('session_title'),
		content_ref => \$html
	});
}

