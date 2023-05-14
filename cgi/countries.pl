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
use CGI qw/:cgi :form escapeHTML/;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::URL qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Tags qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

# This script returns a list of countries in the language of the interface in a JSON format
# it is used to display the dropdown list of countries

ProductOpener::Display::init_request();

my $term = decode utf8 => single_param('term');

my %result = ();
foreach my $country (
	sort {
		(          get_string_id_for_lang("no_language", $translations_to{countries}{$a}{$lang})
				|| get_string_id_for_lang("no_language", $translations_to{countries}{$a}{'en'}))
			cmp(   get_string_id_for_lang("no_language", $translations_to{countries}{$b}{$lang})
				|| get_string_id_for_lang("no_language", $translations_to{countries}{$b}{'en'}))
	}
	keys %{$properties{countries}}
	)
{

	my $cc = country_to_cc($country);
	if (not(defined $cc)) {
		next;
	}

	my $tag = display_taxonomy_tag($lang, 'countries', $country);
	if (   (not defined $term)
		or ($term eq '')
		or ($tag =~ /$term/i))
	{
		$result{$cc} = $tag;
	}
}

my $data = encode_json(\%result);

print "Content-Type: application/manifest+json; charset=UTF-8\r\nCache-Control: max-age=86400\r\n\r\n" . $data;

