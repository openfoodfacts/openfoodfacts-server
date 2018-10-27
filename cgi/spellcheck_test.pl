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
use ProductOpener::Lang qw/:all/;
use ProductOpener::Tags qw/:all/;

use CGI qw/:cgi :form escapeHTML charset/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;


ProductOpener::Display::init();


# MIDDLE DOT with common substitutes (BULLET variants, BULLET OPERATOR and DOT OPERATOR (multiplication))
my $middle_dot = qr/(?:\N{U+00B7}|\N{U+2022}|\N{U+2023}|\N{U+25E6}|\N{U+2043}|\N{U+204C}|\N{U+204D}|\N{U+2219}|\N{U+22C5})/i;
# Unicode category 'Punctuation, Dash', SWUNG DASH and MINUS SIGN
my $dashes = qr/(?:\p{Pd}|\N{U+2053}|\N{U+2212})/i;
# ',' and synonyms - COMMA, SMALL COMMA, FULLWIDTH COMMA, IDEOGRAPHIC COMMA, SMALL IDEOGRAPHIC COMMA, HALFWIDTH IDEOGRAPHIC COMMA
my $commas = qr/(?:\N{U+002C}|\N{U+FE50}|\N{U+FF0C}|\N{U+3001}|\N{U+FE51}|\N{U+FF64})/i;
# '.' and synonyms - FULL STOP, SMALL FULL STOP, FULLWIDTH FULL STOP, IDEOGRAPHIC FULL STOP, HALFWIDTH IDEOGRAPHIC FULL STOP
my $stops = qr/(?:\N{U+002E}|\N{U+FE52}|\N{U+FF0E}|\N{U+3002}|\N{U+FE61})/i;
# '(' and other opening brackets ('Punctuation, Open' without QUOTEs)
my $obrackets = qr/^(?![\N{U+201A}|\N{U+201E}|\N{U+276E}|\N{U+2E42}|\N{U+301D}])[\p{Ps}]$/i;
# ')' and other closing brackets ('Punctuation, Close' without QUOTEs)
my $cbrackets = qr/^(?![\N{U+276F}|\N{U+301E}|\N{U+301F}])[\p{Pe}]$/i;
my $separators_except_comma = qr/(;|:|$middle_dot|\[|\{|\(|( $dashes ))|(\/)/i; # separators include the dot . followed by a space, but we don't want to separate 1.4 etc.
my $separators = qr/($stops\s|$commas|$separators_except_comma)/i;



my $type = param('type') || 'add';
my $action = param('action') || 'display';

my $tagtype= get_fileid(param('tagtype'));

not defined $tagtype and $tagtype eq 'ingredients';

my $text = remove_tags_and_quote(decode utf8=>param('text'));

my $html = '<p>The spellcheck results are based on matches in a given taxonomy.</p>
<p>For words with at least 5 characters, we consider an edit distance of 1 (insert, replace or delete).</p>
';


if ($action eq 'process') {


	$html .= "<p>Spellcheck result for taxonomy <b>$tagtype</b> and language <b>$lc</b>:</p>";
	$html .= "<table><tr><th>Input</th><th>Correction</th><th>$lc tag</th><th>Canonical tag</th></tr>";
	foreach my $token2 (split(/$separators/, $text)) {
	
		my $token = $token2;
		
		# remove %
		if ($tagtype eq 'ingredients') {
			$token =~ s/\s*(\d+((\,|\.)\d+)?)\s*\%\s*//;
		}
		
		$token =~ s/\s+$//;
		$token =~ s/^\s+//;
	
		next if get_fileid($token) eq '';
		
		my ($canon_tagid, $tagid, $tag) = spellcheck_taxonomy_tag($lc, $tagtype, $token);
		
		if ($token eq $tag) {
			$tag = "";
		}
		
		$html .= "<tr><td>$token</td><td>$tag</td><td>$tagid</td><td>$canon_tagid</td></tr>\n";
		
	}
	
	$html .= "</table>";	
	
	$action = 'display';
}


if ($action eq 'display') {
	
	$html .= start_form(-method => "GET");
	
	

	$html .= <<HTML
Taxonomy: <input type="text" name="tagtype" id="tagtype" value="$tagtype" /><br /><br />
Text (language code: $lc): <br/>

<textarea id="text" name="text" style="height:8rem;">$text</textarea>
HTML
;

	$html .= ''
	. hidden(-name=>'type', -value=>$type, -override=>1)
	. hidden(-name=>'action', -value=>'process', -override=>1);
	
	$html .= submit()
	. end_form();

}
elsif ($action eq 'process') {


}


my $full_width = 1;
if ($action ne 'display') {
	$full_width = 0;
}

display_new( {
	title=>"Spellcheck Test",
	content_ref=>\$html,
	full_width=>$full_width,
});

