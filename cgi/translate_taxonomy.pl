#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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

use ProductOpener::PerlStandards;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Lang qw/$lc/;
use ProductOpener::Display qw/init_request/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Tags qw/add_user_translation/;
use ProductOpener::Users qw/$User_id/;
use ProductOpener::Text qw/remove_tags_and_quote/;

use Encode;
use CGI qw/:cgi :form escapeHTML/;
use Log::Any qw($log);
use JSON::MaybeXS;

my $request_ref = ProductOpener::Display::init_request();

my $tagtype = remove_tags_and_quote(decode utf8 => single_param('tagtype'));
my $from = remove_tags_and_quote(decode utf8 => single_param('from'));
my $to = remove_tags_and_quote(decode utf8 => single_param('to'));

my $status;

if ((defined $tagtype) and (defined $from) and (defined $to) and ($to ne "")) {
	$status = "ok";
	add_user_translation($lc, $tagtype, $User_id, $from, $to);
}
else {
	$status = "not ok - missing tagtype, from or to parameter";
}

my $data = encode_json({status => $status});

$log->debug("JSON data output", {data => $data}) if $log->is_debug();

print header(-type => 'application/json', -charset => 'utf-8') . $data;

exit(0);

