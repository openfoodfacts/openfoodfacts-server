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

my $text = decode utf8=>param('text');

my $html = <<HTML
<p>Liste des ingrédients :</p>
<form>
<textarea name="text" id="text" cols="80" rows="10">
$text
</textarea>
<br/>
<input type="submit">
</form>
HTML
;

if ($text ne '') {
		
	my $product_ref = { code => 0, ingredients_text => $text };
	extract_ingredients_from_text($product_ref);
	
	
	if (not defined $product_ref->{ingredients}) {
		$html .= "<p>Pas d'ingrédients reconnus</p>";
	}
	else {
		$html .= <<HTML
<table>
<theader>
<th>Rank</th>
<th>id</th>
<th>Name (in the list)</th>
<th>%</th>
</theader>
<tbody>		
HTML
;		
		foreach my $i (@{$product_ref->{ingredients}}) {
	
			$html .= "<tr><td>" . $i->{rank}. "</td><td>" . $i->{id} . "</td><td>" . $i->{text} . "</td><td>" . $i->{percent} . "</td></tr>\n";
	
		}	

		$html .= <<HTML
</tbody>
</table>
HTML
;		
	}
}

display_new( {
	blog_ref=>undef,
	blogid=>'all',
	tagid=>'all',
	title=>'ingredient parser',
	content_ref=>\$html,
	full_width=>1,
});

exit(0);

