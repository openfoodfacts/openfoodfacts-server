#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Tags qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Images qw/:all/;
use Blogs::Lang qw/:all/;
use Blogs::Mail qw/:all/;
use Blogs::Products qw/:all/;
use Blogs::Food qw/:all/;
use Blogs::Ingredients qw/:all/;
use Blogs::Images qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

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

