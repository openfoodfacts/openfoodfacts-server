#!/usr/bin/perl

use Modern::Perl '2012';
use utf8;

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:cgi :form escapeHTML/;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Tags qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;

ProductOpener::Display::init();
use ProductOpener::Lang qw/:all/;

$lc = 'fr';
$lang = 'fr';

sub display_madenearyou($) {

	my $request_ref = shift;
	
	not $request_ref->{blocks_ref} and $request_ref->{blocks_ref} = [];
	

	my $title = $request_ref->{title};
	my $description = $request_ref->{description};
	my $content_ref = $request_ref->{content_ref};
	my $blocks_ref = $request_ref->{blocks_ref};
	

	my $html = <<HTML

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xmlns:fb="http://www.facebook.com/2008/fbml">
<head>
<title>C'est emballé près de chez vous</title>
<meta http-equiv="content-type" content="text/html; charset=UTF-8" />
<meta name="language" content="fr-FR" />

<script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js"></script>
<script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jqueryui/1.8.16/jquery-ui.min.js"></script>
<link rel="stylesheet" href="https://ajax.googleapis.com/ajax/libs/jqueryui/1.8.16/themes/ui-lightness/jquery-ui.css" />
<script type="text/javascript" src="/js/jquery.cookie.min.js"></script>	

<script src="/js/jquery.iframe-transport.js"></script>
<script src="/js/jquery.fileupload.js"></script>	
<script src="/js/load-image.min.js"></script>
<script src="/js/canvas-to-blob.min.js"></script>
<script src="/js/jquery.fileupload-ip.js"></script>

$header

<script>
\$(function() {

$initjs
	
});
</script>

<link rel="stylesheet" href="/bower_components/leaflet/dist/leaflet.css">
<script src="/bower_components/leaflet/dist/leaflet.js"></script>
<link rel="stylesheet" href="/bower_components/leaflet.markercluster/dist/MarkerCluster.css" />
<link rel="stylesheet" href="/bower_components/leaflet.markercluster/dist/MarkerCluster.Default.css" />
<script src="/bower_components/leaflet.markercluster/dist/leaflet.markercluster.js"></script>

<meta property="fb:admins" content="706410516" />
<meta property="og:site_name" content="C'est emballé près de chez vous"/>
<meta property="fb:app_id" content="156259644527005" />
<meta property="og:type" content="food"/>
<meta property="og:title" content="C'est emballé près de chez vous"/>
<meta property="og:url" content="http://cestemballepresdechezvous.fr"/>

<meta property="og:image" content="http://cestemballepresdechezvous.fr/images/misc/cestemballepresdechezvous.png"/>
<meta property="og:image" content="http://cestemballepresdechezvous.fr/images/misc/cestemballepresdechezvous-carte-logo.png"/>
<meta property="og:description" content="Carte interactive des lieux de production des produits alimentaires"/>
<meta name="description" content="Carte interactive des lieux de production des produits alimentaires" />

<link rel="apple-touch-icon" sizes="180x180" href="/images/favicon-madenearme/apple-touch-icon.png">
<link rel="icon" type="image/png" href="/images/favicon-madenearme/favicon-32x32.png" sizes="32x32">
<link rel="icon" type="image/png" href="/images/favicon-madenearme/favicon-16x16.png" sizes="16x16">
<link rel="manifest" href="/images/favicon-madenearme/manifest.json">
<link rel="mask-icon" href="/images/favicon-madenearme/safari-pinned-tab.svg" color="#003380">
<link rel="shortcut icon" href="/images/favicon-madenearme/favicon.ico">
<meta name="msapplication-config" content="/images/favicon-madenearme/browserconfig.xml">
<meta name="theme-color" content="#ffffff">

<style type="text/css" media="all">

body,html {
	min-height:101%;
	font-family: "Arial", "Helvetica", "Verdana", "sans-serif";
	font-size: 100%;
	padding:0px;
	margin:0px;
	width:100%;
	background:#ffe;
}

#page {
width:1000px;
padding:20px;
padding-top:10px;
margin:auto;
position:relative;
background: #ffffff;
}

#sharebuttons {
	position:absolute;
	right:10px;
	top:30px;
	margin-right:2em;
}

.sharebutton { float:left; padding-right:10px;padding-bottom:5px;}	

a, a:visited {
	color:blue;
}

h1 {
font-family: 'Fredericka the Great', cursive;
font-size:48px;
}

</style>

<script type="text/javascript">

  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', 'UA-31851927-2']);
  _gaq.push(['_trackPageview']);

  (function() {
    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
  })();

</script>

<link href='https://fonts.googleapis.com/css?family=Fredericka+the+Great' rel='stylesheet' type='text/css'>

	
</head>
<body>

<div id="page">

<img src="/images/misc/cestemballepresdechezvous.png" alt="C'est emballé près de chez vous" width="551" height="200" />

<div id="description" style="position:absolute;width:400px;top:130px;right:0px;">C'est emballé près de chez vous, et peut être même fabriqué, transformé et conditionné près de chez vous.<br/>
Avec parfois des ingrédients qui viennent du bout du monde... </div>

<h2>Consommer local ?</h2>

<p><i>C'est emballé près de chez vous</i> montre sur une carte les lieux de production, de transformation et/ou d'emballage des produits alimentaires.
Cette carte peut vous être utile si vous êtes adepte du "consommer local", ou si vous êtes curieux de voir quels aliments sont produits près de chez vous et quelle est la provenance de leurs ingrédients.</p>

$$content_ref

<h2>C'est vous qui fabriquez cette carte !</h2>

<p>Les données des produits alimentaires proviennent de la base collaborative, libre et ouverte <a href="https://fr.openfoodfacts.org">Open Food Facts</a>.
Le lieu de production est identifié grâce aux <a href="https://fr.blog.openfoodfacts.org/news/les-codes-emballeurs-vont-vous-emballer">codes emballeurs</a> qui figurent sur les emballages et étiquettes des produits.</p>

<p>A noter que le code emballeur identifie l'entreprise qui a emballé le produit. C'est dans beaucoup de cas également l'entreprise qui a fabriqué le produit, mais les différents ingrédients peuvent bien sûr provenir d'autres régions ou pays. Il
est également possible que l'emballeur importe des aliments préparés dans d'autres pays. Lorsque la provenance des ingrédients est connue, elle est indiquée sous la photo du produit.</p>

<p>C'est très intéressant de voir que beaucoup de produits sont fabriqués ou conditionnés en France mais dont les ingrédients viennent parfois de l'autre bout de la planète !</p>

<p>Si vous ne trouvez pas de produits vraiment locaux à côté de chez vous sur cette carte (les Noix de Saint-Jacques conditionnés à Fécamp qui viennent du Pérou ? Les fameux coeurs de palmiers et les crevettes géantes tigrées d'Ivry-sur-Seine ?),
vous pouvez partir à leur recherche dans votre frigo, vos placards ou le magasin du coin et les ajouter sur le site d'<a href="https://fr.openfoodfacts.org">Open Food Facts</a>
ou avec l'app <a href="https://itunes.apple.com/fr/app/open-food-facts/id588797948">iPhone</a> ou <a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner">Android</a>. Merci d'avance !</p>

<p>Les données qui permettent de générer la carte sont issues du projet collaboratif <a href="https://openstreetmap.fr/">OpenStreetMap</a> qui créé une carte libre du monde.</p>

<p>Ces deux projets fonctionnent grâce à la collecte citoyenne de données (le <i>crowdsourcing</i> en anglais). Ce sont des personnes comme vous et moi qui scannent les codes barres des produits et les prennent en photo, ou qui ajoutent un bout de chemin
ou de route. Vous nous rejoignez ?</p>

<h2>On en discute ?</h2>

<div style="width:460px;margin-right:20px;float:left;">

<p>Auteur : <a href="mailto:stephane\@openfoodfacts.org">Stéphane Gigandet</a> -
<a href="https://fr.openfoodfacts.org/mentions-legales">Mentions légales</a></p>

<p>Retrouvez-nous aussi sur :</p>

<p>
&rarr; <a href="https://twitter.com/OpenFoodFactsFR">Twitter</a><br/>
&rarr; <a href="https://plus.google.com/u/0/b/102622509148794386660/">Google+</a><br />
&rarr; <a href="https://www.facebook.com/OpenFoodFacts.fr">Facebook</a> + <a href="https://www.facebook.com/groups/356858984359591/">groupe des contributeurs</a><br />
</p>
</div>

<div style="width:480px;float:left;">
<p>Vous pouvez ajouter des produits avec l'app iPhone ou Android :</p>

<a href="https://itunes.apple.com/fr/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_FR_135x40.png" alt="Disponible sur l'App Store" width="135" height="40" style="margin-right:30px" /></a>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Disponible sur Google Play" width="135" height="47" /></a><br/>

<p>C'est fabriqué (et pas seulement emballé !) <s>près de</s> chez vous : le plus court des circuits-courts passe par votre cuisine !
Pour trouver l'inspiration, découvrez chaque jour des dizaines de <a href="http://recettes.de/cuisine">recettes de cuisine</a> proposées par les blogueuses et blogueurs culinaires.</p>
</div>

<h2 style="clear:left;padding-top:20px;">Données ouvertes - <i>open data</i></h2>

<p>Les données d'Open Food Facts et d'OpenStreetMap sont disponibles gratuitement et pour tout usage sous la licence ouverte <a href="https://opendatacommons.org/licenses/odbl/1.0/">Open Database Licence (ODBL)</a>.</p>

<a href="https://fr.openfoodfacts.org/"><img id="logo" src="https://fr.openfoodfacts.org/images/misc/openfoodfacts-logo-fr.png" width="178" height="141" alt="Open Food Facts" /></a> &nbsp;
<a href="https://openstreetmap.fr/"><img src="https://fr.openfoodfacts.org/images/misc/OSM-FR-logo-web-avec-texte.png" alt="OpenStreetMap" style="margin-left:30px;" /></a>



<div id="sharebuttons">
<div style="float:left;padding-right:15px;" class="sharebutton"><iframe allowtransparency="true" frameborder="0" scrolling="no" role="presentation"
src="https://platform.twitter.com/widgets/tweet_button.html?via=OpenFoodFacts&amp;count=vertical&amp;lang=$lc"
style="width:65px; height:63px;"></iframe></div>
<div style="float:left;padding-right:15px;" class="sharebutton"><fb:like href="http://cestemballepresdechezvous.fr" layout="box_count"></fb:like></div>
<div style="float:left;padding-right:15px;padding-bottom:10px;" class="sharebutton"><g:plusone size="tall" count="true" href="http://cestemballepresdechezvous.fr"></g:plusone></div>
</div>

</div>

<div id="fb-root"></div>

    <script type="text/javascript">
      window.fbAsyncInit = function() {
        FB.init({appId: '156259644527005', status: true, cookie: true,
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

	print header ( -expires=>'-1d', -charset=>'UTF-8');
	
	
	binmode(STDOUT, ":encoding(UTF-8)");
	print $html;

}


my $action = param('action') || 'display';

$action = 'process';

my $request_ref = {};

if ((defined param('search_terms')) and (not defined param('action'))) {
	$action = 'process';
}

if (defined param('jqm')) {
	$request_ref->{jqm} = param('jqm');
}

if (defined param('jqm_loadmore')) {
	$request_ref->{jqm_loadmore} = param('jqm_loadmore');
}

my @search_fields = qw(brands categories packaging labels origins emb_codes purchase_places stores additives traces status );
my %search_tags_fields =  (packaging => 1, brands => 1, categories => 1, labels => 1, origins => 1, emb_codes => 1, traces => 1, purchase_places => 1, stores => 1, additives => 1, status=>1);

my @search_ingredient_classes = ('additives', 'ingredients_from_palm_oil', 'ingredients_that_may_be_from_palm_oil', 'ingredients_from_or_that_may_be_from_palm_oil');


# Read all the parameters, watch for XSS

my $tags_n = 3;
my $nutriments_n = 3;

my $search_terms = remove_tags_and_quote(decode utf8=>param('search_terms2'));	#advanced search takes precedence
if ((not defined $search_terms) or ($search_terms eq '')) {
	$search_terms = remove_tags_and_quote(decode utf8=>param('search_terms'));
}

my @search_tags = ();
my @search_nutriments = ();
my %search_ingredient_classes = {};

for (my $i = 0; $i < $tags_n ; $i++) {

	my $tagtype = remove_tags_and_quote(decode utf8=>param("tagtype_$i"));
	my $tag_contains = remove_tags_and_quote(decode utf8=>param("tag_contains_$i"));
	my $tag = remove_tags_and_quote(decode utf8=>param("tag_$i"));
		
	push @search_tags, [
		$tagtype, $tag_contains, $tag,
	];
}

foreach my $tagtype (@search_ingredient_classes) {
	
	$search_ingredient_classes{$tagtype} = param($tagtype);
	not defined $search_ingredient_classes{$tagtype} and $search_ingredient_classes{$tagtype} = 'indifferent';
}

for (my $i = 0; $i < $nutriments_n ; $i++) {

	my $nutriment = remove_tags_and_quote(decode utf8=>param("nutriment_$i"));
	my $nutriment_compare = remove_tags_and_quote(decode utf8=>param("nutriment_compare_$i"));
	my $nutriment_value = remove_tags_and_quote(decode utf8=>param("nutriment_value_$i"));
		
	push @search_nutriments, [
		$nutriment, $nutriment_compare, $nutriment_value,
	];
}

my $sort_by = remove_tags_and_quote(decode utf8=>param("sort_by"));
if (($sort_by ne 'created_t') and ($sort_by ne 'last_modified_t') and ($sort_by ne 'last_modified_t_complete_first')) {
	$sort_by = 'product_name';
}

my $limit = param('page_size') || $page_size;
if (($limit < 2) or ($limit > 1000)) {
	$limit = $page_size;
}

my $graph_ref = {graph_title=>remove_tags_and_quote(decode utf8=>param("graph_title"))};
my $map_title = remove_tags_and_quote(decode utf8=>param("map_title"));



if ($action eq 'process') {

	# Display the search results or construct CSV file for download

	# analyze parameters and construct query
	
	my $current_link = "/cgi/search.pl?action=process";
	
	my $query_ref = {};

	my $page = param('page') || 1;
	if (($page < 1) or ($page > 1000)) {
		$page = 1;
	}
	
	# Search terms
	
	if ((defined $search_terms) and ($search_terms ne '')) {
	
		my %terms = ();	
	
		foreach my $term (split(/,|'|\s/, $search_terms)) {
			if (length(get_fileid($term)) >= 2) {
				$terms{normalize_search_terms(get_fileid($term))} = 1;
			}
		}
		if (scalar keys %terms > 0) {
			$query_ref->{_keywords} = { '$all' => [keys %terms]};
			$current_link .= "\&search_terms=" . URI::Escape::XS::encodeURIComponent($search_terms);
		}
			
	}
	
	# Tags criteria
	
	my $and;
	
	for (my $i = 0; $i < $tags_n ; $i++) {
	
		my ($tagtype, $contains, $tag) = @{$search_tags[$i]};
		
		if (($tagtype ne 'search_tag') and ($tag ne '')) {
		
			my $tagid = get_fileid(canonicalize_tag2($tagtype, $tag));
			
			if ($tagtype eq 'additives') {
				$tagid =~ s/-.*//;
			}	
			
			if ($tagid ne '') {
			
				# 2 or 3 criterias on the same field?
				my $remove = 0;
				if (defined $query_ref->{$tagtype . "_tags"}) {
					$remove = 1;
					$and = [{ $tagtype . "_tags" => $query_ref->{$tagtype . "_tags"} }];
				}
			
				if ($contains eq 'contains') {
					$query_ref->{$tagtype . "_tags"} = $tagid;
				}
				else {
					$query_ref->{$tagtype . "_tags"} =  { '$ne' => $tagid };
				}
				
				if ($remove) {
					push @$and, { $tagtype . "_tags" => $query_ref->{$tagtype . "_tags"} };
					delete $query_ref->{$tagtype . "_tags"};
					$query_ref->{"\$and"} = $and;
				}
				
				$current_link .= "\&tagtype_$i=$tagtype\&tag_contains_$i=$contains\&tag_$i=" . URI::Escape::XS::encodeURIComponent($tag);
				
				# TODO: 2 or 3 criterias on the same field
				# db.foo.find( { $and: [ { a: 1 }, { a: { $gt: 5 } } ] } ) ?
			}
		}
	}	
	
	# Ingredient classes
	
	foreach my $tagtype (@search_ingredient_classes) {
	
		if ($search_ingredient_classes{$tagtype} eq 'with') {
			$query_ref->{$tagtype . "_n"}{ '$gte'} = 1;
			$current_link .= "\&$tagtype=with";
		}
		elsif ($search_ingredient_classes{$tagtype} eq 'without') {
			$query_ref->{$tagtype . "_n"}{ '$lt'} = 1;
			$current_link .= "\&$tagtype=without";
		}
	}
	
	# Nutriments
	
	for (my $i = 0; $i < $nutriments_n ; $i++) {
	
		my ($nutriment, $compare, $value, $unit) = @{$search_nutriments[$i]};
		
		if (($nutriment ne 'search_nutriment') and ($value ne '')) {
					
			if ($compare eq 'eq') {
				$query_ref->{"nutriments.${nutriment}_100g"} = $value + 0.0; # + 0.0 to force scalar to be treated as a number
			}
			elsif ($compare =~ /^(lt|lte|gt|gte)$/) {
				if (defined $query_ref->{"nutriments.${nutriment}_100g"}) {
					$query_ref->{"nutriments.${nutriment}_100g"}{ '$' . $compare}  = $value + 0.0;
				}
				else {
					$query_ref->{"nutriments.${nutriment}_100g"} = { '$' . $compare  => $value + 0.0 };
				}
			}				
			$current_link .= "\&nutriment_$i=$nutriment\&nutriment_compare_$i=$compare\&nutriment_value_$i=" . URI::Escape::XS::encodeURIComponent($value);
			
			# TODO support range queries: < and > on the same nutriment
			# my $doc32 = $collection->find({'x' => { '$gte' => 2, '$lt' => 4 }});
		}
	}		

	
	my @fields = keys %tag_type_singular;
	
	foreach my $field (@fields) {
	
		next if defined $search_ingredient_classes{$field};

		if ((defined param($field)) and (param($field) ne '')) {
		
			$query_ref->{$field} = decode utf8=>param($field);
			$current_link .= "\&$field=" . URI::Escape::XS::encodeURIComponent(decode utf8=>param($field));
		}	
	}
	
	if (defined $sort_by) {
		$current_link .= "&sort_by=$sort_by";
	}
	
	$current_link .= "\&page_size=$limit";
	
	# Graphs
	
	foreach my $axis ('x','y') {
		if (param("axis_$axis") ne '') {
			$current_link .= "\&axis_$axis=" .  URI::Escape::XS::encodeURIComponent(decode utf8=>param("axis_$axis"));
		}
	}	
	
	if (param('graph_title') ne '') {
		$current_link .= "\&graph_title=" . URI::Escape::XS::encodeURIComponent(decode utf8=>param("graph_title"));
	}
	
	if (param('map_title') ne '') {
		$current_link .= "\&map_title=" . URI::Escape::XS::encodeURIComponent(decode utf8=>param("map_title"));
	}
		
	foreach my $series (@search_series) {

		next if $series eq 'default';
		if ($graph_ref->{"series_$series"}) {
			$current_link .= "\&series_$series=on";
		}
	}
	
	$request_ref->{current_link_query} = $current_link;
	
	my $html = '';
	
	use Data::Dumper;
	print STDERR "search.pl - query: \n" . Dumper($query_ref) . "\n";
	
	$query_ref->{lc} = $lc;
	
	# Graph, map, export or search


	
		$request_ref->{current_link_query} .= "&generate_map=1";
		
		# We want products with emb codes
		$query_ref->{"emb_codes_tags"} = { '$exists' => 1 };	
		
		${$request_ref->{content_ref}} .= $html . search_and_map_products($request_ref, $query_ref, $graph_ref);

		$request_ref->{title} = lang("search_title_map");
		if ($map_title ne '') {
			$request_ref->{title} = $map_title . " - " . lang("search_map");
		}
		$request_ref->{full_width} = 1;
		
		
		my $html =	<<HTML
<div id="container" style="height: 600px"></div>
HTML
;
		$request_ref->{content_ref} = \$html;

	display_madenearyou($request_ref);
	
}
