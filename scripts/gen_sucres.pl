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
use ProductOpener::Lang qw/:all/;
use URI::Escape::XS qw/uri_escape uri_unescape/;
  

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

# Generate a list of the top brands, categories, users, additives etc.

my @fields = qw (
brands 
categories
packaging 
origins 
ingredients 
labels 
nutriments 
traces 
users
photographers
informers
correctors
checkers
additives
allergens
emb_codes
cities
purchase_places
stores
ingredients_from_palm_oil
ingredients_that_may_be_from_palm_oil
states
);



my %langs = ();
my $total = 0;

# foreach my $l (values %lang_lc) {

foreach my $l ('fr') {

	$lc = $l;
	$lang = $l;
	
	my $fields_ref = {code => 1, product_name => 1, brands => 1, quantity => 1, nutriments => 1};
	my %tags = ();

	

	my $query_ref = {lc=>$lc, states_tags=>'en:complete'};
	#$query_ref->{"nutriments.sugars_100g"}{ '$gte'}  = 0.01;
	# -> does not seem to work for sugars, maybe some string values?!
		
	my $cursor = $products_collection->query($query_ref);
	my $count = $cursor->count();
	
	$langs{$l} = $count;
	$total += $count;
		
	print STDERR "lc: $lc - $count products\n";


	my %codes = ();
	my $html = '';

			$html .= <<HTML
HTML
;

	$html .= '<table id="tagstable"><thead><tr><th>code</th><th>name</th><th>complete name</th><th>brands</th><th>quantity</th><th>g / cl</th><th>sucre g</th><th>cubes</th><th>sucres/100g|cl</th></tr></thead><tbody>';
		
		


		
	my @ids = ();

	my $k = 0;
	my $kk = 0;
		
	while (my $product_ref = $cursor->next) {

		$k++;

		(not defined $product_ref->{"nutriments"}{"sugars_100g"}) and next;
		($product_ref->{"nutriments"}{"sugars_100g"}) < 0.01 and next;

		$kk++;

		($kk % 1000 == 0) and print STDERR "$kk products kept - $k total\n";
		
		my $code = $product_ref->{code};
		
		my $q = $product_ref->{quantity};
		$q =~ s/.*=//;
		$q = lc($q);
		
		my $x = 1;
		if ($q =~ /(mg)$/) {
			$q  = $`;
			$x = 0.1;
		}	
		if ($q =~ /(kg)$/) {
			$q  = $`;
			$x = 1000;
		}
		if ($q =~ /(g)$/) {
			$q  = $`;
			$x = 1;
		}			
		if ($q =~ /(ml)$/) {
			$q  = $`;
			$x = 1
		}
		if ($q =~ /(cl)$/) {
			$q  = $`;
			$x = 10;
		}
		if ($q =~ /(dl)$/) {
			$q  = $`;
			$x = 100;
		}			
		if ($q =~ /(l)$/) {
			$q  = $`;
			$x = 1000;
		}			

		if (exists $product_ref->{product_quantity}) {
			$q = $product_ref->{product_quantity};
		}
		else {
			next;
		}
		
		#my $qx = $q * $x;

		my $qx = $q;
	
		my $s = $qx * $product_ref->{"nutriments"}{"sugars_100g"} / 100;
		my $sucres_g = int($s + 0.4999);
		my $sc = $s / 4;
		my $small = int($sc + 0.4999);
		my $big = $s / 6;
		my $cubes = sprintf("%.1f", $sc);
		my $cubes_small = sprintf("%.1f", $sc);
		my $cubes_big = sprintf("%.1f", $big);
		my $producturl = product_url($product_ref);
		$producturl =~ s/^\//https:\/\/fr.openfoodfacts.org\//;
		
		my $code = $product_ref->{"code"};
		

		
		if (($product_ref->{quantity} =~ /^\d+\s?(mg|g|kg|ml|dl|cl|l)\s*$/i) and ($qx <= 2000) and ($sc <= 75) and ($sc > 1)) {
		
		my $firstbrand = $product_ref->{brands};
		$firstbrand =~ s/,.*//;
		
		my $generic = '';
		if ($product_ref->{generic_name} =~ /\w/) {
			$generic = $product_ref->{generic_name} . "<br/>";
		}
		
		my $marques;
		my $brands = $product_ref->{brands};
		if ($brands =~ /,/) {
			$marques = "Marques : <b>$brands</b>";
			$marques =~ s/,/, /g;
		}
		else {
			$marques = "Marque: <b>$brands</b>";
		}
		
		my $quantity = lc($product_ref->{quantity});
		$quantity =~ s/(\d)([a-z])/$1 $2/i;
		$quantity =~ s/l/L/;
		
		my $name = $product_ref->{product_name};
		$name =~ s/$firstbrand$//e;
		$name =~ s/(\s|-|\/)+$//;
		if ($name !~ /$firstbrand/) {
			$name .= " " . $firstbrand;
		}
		
		my $escapedname = uri_escape($name);
		
		$name =~ s/"//g;
		
		my $id = get_fileid($name);		
		
		$html .= "<tr><td>" . $product_ref->{code} . "</td><td><a href=\"https://combiendesucres.fr/$id\">" . $product_ref->{product_name} . "</a></td><td>" . $name . "</td><td>" . $product_ref->{brands} . "</td><td>" . $product_ref->{quantity} 
			. "</td><td>$q x $x = $qx</td><td>$s</td><td>$sc</td><td>" . $product_ref->{"nutriments"}{"sugars_100g"} . "</td></tr>\n";
			


		
		my $description = "Combien de sucre y a-t-il dans $name ? Devinez quel est l'équivalent en morceaux de sucres avec notre jeu instructif, simple et rapide.";
		
		$product_ref->{jqm} = 1;
		my $img = display_image($product_ref, 'front', 200);
		$img =~ s/src="\//src="https:\/\/fr.openfoodfacts.org\//;
		my $img_url = '';
		my $zoom = '';
		if ($img =~ /src="(.*?)"/) {
			$img_url = $1;
			$img_url =~ s/\.200/\.400/g;
			$zoom = '<a href="' . $img_url . '" class="nivoZoom topRight">' . $img . '</a>';
		}
		else {
			next;
		}
			
		my $page = <<HTML
<!DOCTYPE html>
<html>
<head>

<title>Combien de sucres dans le produit $name ?</title>
<meta http-equiv="content-type" content="text/html; charset=UTF-8" />
<meta name="language" content="fr-FR" />

<meta property="fb:admins" content="706410516" />
<meta property="og:site_name" content="Combien de sucres ?"/>
<meta property="fb:app_id" content="472618429477645" />
<meta property="og:type" content="food"/>
<meta property="og:title" content="Combien de sucres ?"/>
<meta property="og:url" content="https://combiendesucres.fr/$id"/>

<meta property="og:image" content="https://combiendesucres.fr/combien_de_sucres.png"/>
<meta property="og:image" content="$img_url"/>
<meta property="og:description" content="$description"/>
<meta name="description" content="$description" />

<script type="text/javascript" src="pixi.js"></script>
<script type="text/javascript" src="Box2dWeb-2.1.a.3.min.js"></script>


<link rel="stylesheet" href="https://code.jquery.com/ui/1.10.2/themes/start/jquery-ui.css" />
<script src="https://code.jquery.com/jquery-1.9.1.js"></script>
<script src="https://code.jquery.com/ui/1.10.2/jquery-ui.js"></script>
<script src="jquery.html5storage.min.js"></script>
<script type="text/javascript" src="sucres.js"></script>

<link rel="stylesheet" href="nivo-zoom-off.css" type="text/css" media="screen" />
<script src="jquery.nivo.zoom.pack.js" type="text/javascript"></script>	

<style type="text/css" media="all">



body,html {
	min-height:101%;
	font-family: "Arial", "Helvetica", "Verdana", "sans-serif";
	font-size: 100%;
	padding:0px;
	margin:0px;
	width:100%;
	background:#d5e5ff;
}

h1 {
	font-size:20px;
}

#page {
width:930px;
padding:30px;
padding-top:0px;
margin:auto;
position:relative;
background: #3163ca;
min-height:101%;
color:white;
}

#main {
width:410px;
height:750px;
padding-left:20px;
padding-right:20px;
float:left;
margin-right:30px;
background: white url("sucres_bgl.png") no-repeat top; 
position: relative;
}

#progress {
	position:absolute;
	bottom:20px;
	color:darkblue;
	width:410px;
}

#progressmsg {
	margin-bottom:10px;
}

#sugar_cubes {
width:450px;
height:750px;
padding:0px;
margin:0px;
border:none;
overflow:hidden;
cursor: hand; cursor: pointer;
position:relative;
margin-bottom:5px;
}

#sugar_cubes:active { 
cursor: hand; cursor: pointer; cursor: move;
}


#content {
width:930px;
color:white;
clear:left;
font-size:0.8em;
}


#sharebuttons {
	clear:both;
}

.sharebutton { float:left; padding-right:10px;padding-bottom:5px;}	

a, a:visited {
	color:yellow;
	text-decoration:none;
}

a:hover {
	color:orange;
}

h1 {
	margin-top:0px;
	color:white;
}

#description {
	color:white;
	font-size:0.9em;
}

#product {
	background-color:white;
	text-align:center;
	display:block;
	width:200px;;
	height:220px;
	padding:10px;

	float:right;
	margin-left:20px;
	margin-bottom:20px;
}

#products {
	width:200px;
	height:200px;
	line-height:200px;
	text-align:center;
	padding:0px;
	margin:0px;
	display: table-cell;
	vertical-align:middle;
	background:white;
}

#products img {
	vertical-align:middle;
}

#info, #answer {
	font-size:0.9em;
	margin-bottom:10px;
}

#cubes {
	font-size:64px;
}

#results {
	position:absolute;
	width:311px;
	height:311px;
	bottom:120px;
	left:54px;
	background: transparent url("score_bg.png") no-repeat top; 
	color:black;
	display:none;
	padding:20px;
}

#score {
	text-align:center;
	font-size:40px;
}

#logo {
	border:none;
}

#help {
	position:absolute;
	left:20px;
	top:20px;
	width:250px;
	padding:20px;
	background-color:#ccffff;
	color:black;
	display:none;
}

#your_answer {
	color:#aff;
}

</style>

<script type="text/javascript">
var code = "$code";
var name = "$name";
var small = $small;
var small_f = $cubes_small;
var big = $cubes_big;
</script>

<script type="text/javascript">

  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', 'UA-31851927-3']);
  _gaq.push(['_trackPageview']);

  (function() {
    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'https://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
  })();

</script>
	
</head>
<body>

<div id="page">

<div id="main">

<a href="/"><img id="logo" src="combien_de_sucres.png" width="381" height="160" alt="Combien de sucres ?" /></a>
<br/>

<h1 id="title">Combien de sucres dans le produit $name ?</h1>


<div id="product">
<div id="products">
$zoom
</div>
<div style="text-align:center;font-style:italic;color:black;font-size:0.9em;margin-top:4px;">Cliquez pour zoomer</div>
</div>

<p id="description">$generic$marques<br />Quantité : <b>$quantity</b></p>

<div id="info" >&Agrave; combien de petits morceaux de sucre (4g) équivaut $quantity de $name ?</div>

<div id="answer" style="display:none">$quantity de <a href="$producturl">$name</a> contient $sucres_g g de sucre, soit l'équivalent de $cubes_small petits morceaux de sucres (4g) ou $cubes_big grands morceaux (6g).</div>

<div id="sharebuttons">
<div style="float:left;margin-right:15px;width:150px;color:darkblue;background:white;padding:10px;">Posez la question à vos amis !</div>
<div style="float:left;padding-right:15px;" class="sharebutton"><iframe allowtransparency="true" frameborder="0" scrolling="no" role="presentation" 
src="https://platform.twitter.com/widgets/tweet_button.html?via=CombienDeSucres&amp;count=vertical&amp;lang=fr&amp;text=Combien%20de%20sucres%20dans%20$escapedname%20%3F" style="width:65px; height:63px;"></iframe></div>
<div style="float:left;padding-right:15px;" class="sharebutton"><fb:like href="https://combiendesucres.fr/$id" layout="box_count"></fb:like></div>
<div style="float:left;padding-right:15px;padding-bottom:10px;" class="sharebutton"><g:plusone size="tall" count="true" href="https://combiendesucres.fr/$id"></g:plusone></div>
</div>


<div id="progress">
<div id="progressmsg"></div>
<div id="progressbar"></div>
</div>


</div>

<div id="sugar_cubes">
<canvas id="c" width="450" height="750">Pour voir les sucres tomber, il faut un navigateur plus récent.</canvas>

<div id="help" >Utilisez les boutons <b>+</b> pour indiquer à combien de petits morceaux de sucre (4g) équivaut $quantity de $name.<br/><br/>
Appuyez ensuite sur le bouton <b>✓</b> pour valider et vérifier votre réponse.</div>

<div id="results">
<div id="score"></div>
<div id="score_share"></div>
<div id="score_stats"></div>
</div>
</div>


<div id="mice" style="float:left;width:410px;margin-right:30px;padding:20px;">
<p>Les souris aiment le sucre ! Utilisez la vôtre pour attraper les morceaux et les empiler comme il vous plait.</p>
<form style="display:none">
<input type="button" name="saveButton" id="saveButton" value="Enregistrer" onclick="save_drawing(); return false;">
</form>
</div>

<div style="float:left;width:450px;text-align:center;vertical-align:center;color:white;">
<div id="cubes">0</div><div id="cubes2">&nbsp;petits morceaux de sucre&nbsp;</div><div id="your_answer"></div>
</div>


<div id="content">

<h2>Source des données</h2>

<div style="float:right;margin-left:20px;margin-bottom:20px;"><a href="https://fr.openfoodfacts.org"><img src="openfoodfacts-logo-fr.png" alt="Open Food Facts" style="background-color:white;padding:5px;display:block"/></a></div>

<p>Les données sur les produits et les photos proviennent de la base collaborative <a href="https://fr.openfoodfacts.org">Open Food Facts</a>.
Les données sont disponibles sous la licence ouverte <a href="https://opendatacommons.org/licenses/odbl/1.0/">Open Database License</a> et les photos sous la licence
<a href="https://creativecommons.org/licenses/by-sa/3.0/deed.fr">Creative Commons Attribution Partage à l'identique</a>. Les marques citées sont la propriété de leurs propriétaires respectifs.</p>
<p>La base de données est constituée de manière collaborative, il n'est pas possible de garantir qu'elle soit exempte d'erreurs. La composition des produits peut également avoir changé.
Si vous constatez une erreur, <a href="mailto:stephane\@combiendesucres.fr">merci de nous la signaler</a> afin qu'elle soit corrigée.</p>

<h2>Contact</h2>

<p>Le jeu "Combien de sucres ?" a été créé par Stéphane Gigandet. Vous pouvez me contacter à l'adresse <a href="mailto:stephane\@combiendesucres.fr">stephane\@combiendesucres.fr</a></p>
<p>&rarr; <a href="/">description du jeu et informations sur "Combien de sucres ?"</a></p>

</div>

</div>

<div id="fb-root"></div>

    <script type="text/javascript">
      window.fbAsyncInit = function() {
        FB.init({appId: '472618429477645', status: true, cookie: true,
                 xfbml: true});
     };
	 
      (function() {
        var e = document.createElement('script');
        e.type = 'text/javascript';
        e.src = document.location.protocol +
          '//connect.facebook.net/fr_FR/all.js';
        e.async = true;
        document.getElementById('fb-root').appendChild(e);
      }());
	  

    </script>	

<script type="text/javascript" src="https://apis.google.com/js/plusone.js">
  {lang: 'fr'}
</script>

</body>
</html>		
HTML
;

		open (my $OUT, ">:encoding(UTF-8)", "/srv/sucres/html/$id.html");
		print $OUT $page;
		close $OUT;
			
		push @ids, $id;
			
		}

	}


	$html .= "</tbody></table>";
		
	open (my $OUT, ">:encoding(UTF-8)", "$data_root/lang/$lang/texts/sugar.html");
	print $OUT $html;
	close $OUT;
	
	store("/srv/sucres/data/products_ids.sto", \@ids);
	
	print "$k products, $kk products kept\n";
}



#open (OUT, ">:encoding(UTF-8)", "$www_root/langs.html");
#print OUT $html;
#close OUT;

exit(0);

