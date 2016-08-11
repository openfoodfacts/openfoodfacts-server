package ProductOpener::Config;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();
	@EXPORT_OK = qw(
		%admins
		
		$server_domain
		$data_root
		$www_root
		$reference_timezone
		$contact_email
		$admin_email
		
		$mongodb
		
		%tag_type_from_singular
		%tag_type_singular
		
		$product
		$brand
		$ingredient
		$nutriment
		$user
		$category
		$label
		$packaging
		$mission
		
		$max_brands
		
		$thumb_size
		$crop_size
		$small_size
		$display_size
		$zoom_size
		
		$by
		$on
		
		$extension
		$all_tag
		$sandbox
		$my_blogs_tag
		$oq_tag
		$main_url
		
		$facebook_app_id
		$facebook_app_secret
		
		$max_tags
		$min_description
		$min_rss_description
		$max_description
		
		$max_index_size
		$page_size
		
		%images
		$orientation
		$banner_source_geometry
		@geometries
		
		$title_prefixes
		
		$google_analytics
		
		$menu
		$search
		
		$footer
		
		$adsense
		
		%options		
		
		%Strings
		
		$java_path
		$batik_path
		$classpath
		
		$css
		$header
		
		%stopwords
		
		$lang
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}
use vars @EXPORT_OK ; # no 'my' keyword for these
use strict;
use utf8;

use ProductOpener::Config2;
use ProductOpener::Lang;

$lang = 'fr';

%admins = ('stephane' => 1, 'stephane-gigandet' => 1);

$java_path = "/usr/";
$batik_path = "/home/src/batik-1.7";
$classpath = "/usr/share/xerces-2/lib/xercesImpl.jar:.";


# server constants
$server_domain = $ProductOpener::Config2::server_domain;

$mongodb = $ProductOpener::Config2::mongodb;

# server paths
$www_root = $ProductOpener::Config2::www_root;
$data_root = $ProductOpener::Config2::data_root;

$facebook_app_id = $ProductOpener::Config2::facebook_app_id;
$facebook_app_secret = $ProductOpener::Config2::facebook_app_secret;

$reference_timezone = 'Europe/Paris';

$contact_email = 'contact@openfoodfacts.org';
$admin_email = 'biz@joueb.com';

$by = 'par';
$on = 'theme';

$extension = 'org';
$all_tag = ''; # / is the main url.
$sandbox = "reperages";
$my_blogs_tag = 'mes-blogs-preferes';
$main_url = 'fr.openfoodfacts.org';
$oq_tag = 'questions-ouvertes';

$max_tags = 6;
$min_description = 15;
$min_rss_description = 80; # try to get it from content if less
$max_description = 255;

$max_index_size = 1000;
$page_size = 20;


%options = (
'dont_trust_tag_links' => { 'sara-miki' => 1 },
'require_an_image' => 1,
'news_classes' => 'hrecipe',
'facebook_like_buttons' => 0,
'subscribe'=>0,
'tagcloud_for_tags'=>1,
'tagcloud_for_tags_min'=>4,
'frontpage' => 'menu',
'description_filter' => "(Read this post in English)",
);

# Tags types to path components in url
%tag_type_singular = (
products => 'produit',
brands => 'marque',
categories => 'categorie',
packaging => 'conditionnement',
origins => 'origine',
ingredients => 'ingredient',
labels => 'label',
nutriments => 'nutriment',
traces => 'traces',
users => 'utilisateur',

additives => 'additif',
allergens => 'allergene',
);

foreach my $type (keys %tag_type_singular) {
	$tag_type_from_singular{$tag_type_singular{$type}} = $type;
}

$packaging = 'conditionnement';
$product = 'produit';
$brand = 'marque';
$ingredient = 'ingredient';
$nutriment = 'nutriment';
$user = 'utilisateur';
$category = 'categorie';
$label = 'label';
$mission = 'mission';

$max_brands = 5;

$thumb_size = 100;
$crop_size = 400;
$small_size = 200;
$display_size = 400;
$zoom_size = 800;

# Geometries for each image of a news

$orientation = 'landscape';

@geometries = (
'640x480',
'320x240',
'160x120',
'120x90',
'60x45'
);

$banner_source_geometry = "1000x150";

%images = (
		'banner-wide'=>'jpg',
		'background'=>'png',
		'block-title'=>'png',
		'subtitle_bg'=>'png',
		'interestingviews'=>'png',
		'gradient_bg'=>'png',
);

$google_analytics = <<HTML
<script type="text/javascript">

  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', 'UA-6257384-15']);
  _gaq.push(['_trackPageview']);

  (function() {
    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
    ga.src = ('https:' == document.location.protocol?'https://ssl':'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
  })();

</script>
HTML
;

$menu = <<HTML
<ul>
<li><a href="/a-propos" title="En savoir plus sur Open Food Facts">A propos</a></li>
<li><a href="/mode-d-emploi" title="Pour bien démarrer en deux minutes">Mode d'emploi</a></li>
<li><a href="/contact" title="Des questions, remarques ou suggestions ?">Contact</a></li>
</ul>
HTML
;

# <li><a href="/reperages" title="Les toutes dernières interviews , peut-être prochainement à la Une">Repérages</a></li>


$search = <<HTML

<form action="/cgi/search.pl" id="search">
Trouver une recette : 
<input type="text" name="q" id="q" />
<input type="submit" value="Rechercher" />
</form>

HTML
;

$search = '';

my $footer_google = <<HTML
&rarr; Suivre les interviews sur Google : <a href="http://fusion.google.com/add?source=atgs&amp;moduleurl=http%3A//interestingviews.fr/images/blogs/all/igoogle.xml"><img border="0" src="http://gmodules.com/ig/images/plus_google.gif" alt="Ajouter à Google" width="62" height="17"/></a>
HTML
;

$footer = <<HTML
<div class="footdiv">
</div>

<div class="footdiv">

</div>

<div class="footdiv">
<a href="/mentions-legales">Mentions légales</a> - 
<a href="/conditions-d-utilisation">Conditions d'utilisation</a>

</div>

HTML
;

# <iframe src="http://www.facebook.com/plugins/like.php?href=http%3A%2F%2Frecettes.de%2Fcuisine&amp;layout=standard&amp;show_faces=false&amp;width=210&amp;action=like&amp;colorscheme=light&amp;height=35" scrolling="no" frameborder="0" style="border:none; overflow:hidden; width:210px; height:35px;" allowtransparency="true"></iframe>


my $adsense_notactivated = <<HTML
<script type="text/javascript"><!--
google_ad_client = "ca-pub-3929961498340072";
/* recettes.de 300x250 */
google_ad_slot = "0852212458";
google_ad_width = 300;
google_ad_height = 250;
//-->
</script>
<script type="text/javascript"
src="http://pagead2.googlesyndication.com/pagead/show_ads.js">
</script>
HTML
;


# <a href="http://twitter.com/share" class="twitter-share-button" data-url="http://recettes.de/cuisine" data-text="Recettes de Cuisine" data-count="none" data-via="recettesde" data-lang="fr">Tweet</a><script type="text/javascript" src="http://platform.twitter.com/widgets.js"></script>


$title_prefixes = '^(( |\||\s|\.|-|:|_|\[|\])|(((ma|la|mes|les) )?(meilleure(s)? )?recette(s)?( de)?)|(un|une|des|le|la|les|ma|mon|mes) )+';

%Strings = (

site_name => 'Open Food Facts',

twitter => 'openfoodfacts',

banner_title_prefix => 'Open Food Facts',

by => 'par',
on => 'sur le thème',

tags_ => 'Thèmes :',



newsletter_description => "Etre informé par e-mail des nouveautés du site (2 e-mails par mois maximum)",
discussion_description => "M'abonner à la liste de discussion libre sur les blogs et la cuisine (trafic variable)",

blog_list_presentation => '<p><a href="http://recettes.de/cuisine">Recettes de Cuisine</a> référence les recettes de %d blogs culinaires. Si vous aussi publiez des recettes sur votre blog, et si vous désirez nous aider
 à imaginer et créer le meilleur agrégateur de recettes de cuisine, n\hésitez pas à <a href="/cgi/blog.pl">inscrire votre blog</a>.</p>', 

display_news_title => "Open Food Facts",
display_news_title_blog => "Open Food Facts par <SITE_OR_BLOG>",
display_news_title_tags => "Open Food Facts - <TAGS>",
display_news_title_tags_blog => "Open Food Facts - <TAGS> par <SITE_OR_BLOG>",
display_news_title_search => "Open Food Facts - Recherche",
display_news_title_user => "Open Food Facts - Carnet d'interview",

display_news_title_alpha => " de A à Z",
# display_news_title_top => " les plus appréciées",
display_news_title_top_before => "Les Meilleures ",

display_news_description => "Interviews de personnes passionantes.",
display_news_description_tags => "Interviews sur le thème : <tags>",
display_news_description_blog => "Interviews par <SITE_OR_BLOG> :",
display_news_description_tags_blog => "Interviews par <SITE_OR_BLOG> sur le thème : <tags> ",
display_news_description_search => "Moteur de recherche d'interviews",
display_news_description_user => "Carnet d'interviews",

display_news_description_alpha => "Les meilleures recettes de cuisine : des recettes simples, rapides, délicieuses et originales. Chaque recette est classée par ingrédients, plat et type de cuisine.",
display_news_description_tags_alpha => "Les meilleures recettes de <tags> avec de belles photos pour choisir une recette de <tags> facile, rapide, originale et toujours délicieuse :",
display_news_description_blog_alpha => "Les recettes du blog <SITE_OR_BLOG> de A à Z :",
display_news_description_tags_blog_alpha => "Les recettes de <tags> les plus appréciées du blog <SITE_OR_BLOG> de A à Z :",

display_news_order_top => "Les recettes les plus appréciées",
display_news_description_top => "Les recettes de cuisine les plus appréciées : des recettes simples, rapides, délicieuses et originales. Chaque recette de cuisine est classée par ingrédients, plat et type de cuisine.",
display_news_description_tags_top => "Les recettes de <tags> les plus appréciées. Recette de <tags> facile, rapide et délicieuse :",
display_news_description_blog_top => "Les recettes du blog <SITE_OR_BLOG> les plus appréciées :",
display_news_description_tags_blog_top => "Les recettes de <tags> les plus appréciées du blog <SITE_OR_BLOG> :",

display_news_no_tag => ' sur le thème <tags>',
display_news_0 => "<SITE_OR_BLOG> n'a pas encore publié d'interviews sur le thème <tags>.",
display_news_1 => "<SITE_OR_BLOG> a publié une interview sur le thème <tags>.",
display_news_n => "<SITE_OR_BLOG> a publié %d interviews sur le thème <tags>.",
display_news_site_0 => "Il n'y a pas encore d'interviews sur le thème <tags> publiées sur <SITE_OR_BLOG>.",
display_news_site_1 => "Une interview sur le thème <tags> a été publiée sur <SITE_OR_BLOG>.",
display_news_site_n => "%d interviews sur le thème <tags> on été publiées sur <SITE_OR_BLOG>.",
display_news_sandbox_0 => "La zone de repérages ne contient pas d'interviews sur le thème <tags>.",
display_news_sandbox_1 => "La zone de repérages contient une interview sur le thème <tags>.",
display_news_sandbox_n => "La zone de repérages contient %d interviews sur le thème <tags>.",


display_all => " (<a href=\"%s\">%d interviews par tous les auteurs</a>)",

display_news_search_0 => "Nous n'avons pas trouvé de recettes avec ces termes de recherche. Essayez d'autres termes ou moins de termes, en privilégiant les noms de plats et d'ingrédients.",
display_news_search_1 => "Une recette correspond à votre recherche.",
display_news_search_n => "%d recettes correspondent à votre recherche.",
display_news_user_0 => "Le carnet de recettes ne contient pas encore de recettes.",
display_news_user_1 => "Une recette figure dans le carnet de recettes.",
display_news_user_n => "%d recettes figurent dans le carnet de recettes.",
display_news_user_tag_0 => "Le carnet de recettes ne contient pas encore de recettes de <tags>.",
display_news_user_tag_1 => "Une recette de <tags> figure dans le carnet de recettes.",
display_news_user_tag_n => "%d recettes de <tags> figurent dans le carnet de recettes.",

display_see_all => "Voir toutes les <a href=\"%s\">recettes de <tag1></a> ou toutes les <a href=\"%s\">recettes de <tag2></a>.",
display_tag_cloud_title_blog => "Thèmes des interviews de <SITE_OR_BLOG>",
display_tag_cloud_msg_blog => "Découvrez les interviews de <SITE_OR_BLOG> sur les thèmes suivants :",
display_tag_cloud_title_tag => "Thèmes connexes au thème <SITE_OR_BLOG>",
display_tag_cloud_msg_tag => "Ajoutez un autre thème pour affiner votre sélection d'interviews sur le thème <SITE_OR_BLOG>.",
display_tag_cloud_title => "Thèmes",
display_tag_cloud_msg => "Les thèmes les plus fréquemment abordés dans les interviews :",

display_news_facebook_like_button => "Vous aimez Open Food Facts ?",
display_news_facebook_like_button_tags => "Vous vous intéressez au thème <tags> ?",
display_news_facebook_like_button_blog => "Vous appréciez les interviews de <SITE_OR_BLOG> ?",

display_articles => "Les recettes",

display_click => "Cliquez sur la photo ou le titre d'une recette de <tags> pour la lire en entier sur le blog de son auteur.",

all_tags_title => "Les recettes de <SITE_OR_BLOG> par noms de plats ou d'ingrédients",
all_tags_content => "Cliquez sur un nom de plat ou d'ingrédient pour découvrir les recettes de <SITE_OR_BLOG> correspondantes.",
all_tags_link => "Voir plus de noms de plats et d'ingrédients",
all_tags_url => "mots-cles",

tag => 'étiquette',
Tag => 'Etiquette',
tags => 'étiquettes',
Tags => 'Etiquettes',

article => 'interview',
Article => 'Interview',
articles => 'interviews',
Articles => 'Interviews',

tag_cloud_title => 'Ingrédients et plats',

session_title => 'Se connecter',

suggest_blog => 'Suggérer votre blog',
suggest_blog_msg => '<p>Si vous souhaitez référencer les recettes de votre blog sur <b>Recettes de Cuisine</b>, merci de remplir ce formulaire.</p>
<p>Vous trouverez plus d\'explications sur le site sur la page de <a href="http://recettes.de/a-propos">Présentation</a>
et sur son fonctionnement sur la page <a href="http://recettes.de/mode-d-emploi">Comment ça marche ?</a>.</p>
<p>La page dédiée à vos recettes est personnalisée à votre couleur avec un bandeau comportant le titre de votre blog et une photo de votre choix. Il suffit de choisir ci-dessous une image sur votre ordinateur
et une couleur. Le bandeau sera généré automatiquement.</p>',
suggest_blog_confirm => '<p>Merci de votre proposition de blog. Il sera visité prochainement et vous recevrez un e-mail une fois qu\'il sera validé.</p>
<p>Vous pouvez dès à présent mettre en place des mots-clés sur les dernières recettes de votre blog pour qu\'elles soient référencées automatiquement dès la validation.</p>
<p>&rarr; <a href="http://recettes.de/mode-d-emploi">Comment insérer des mots-clés ?</a></p>
<p>Un petit lien de retour sur votre blog serait très apprécié ! (par exemple quelque chose comme "Les recettes de <BLOG_TITLE> sont référencées sur <a href="http://recettes.de/cuisine">Recettes de Cuisine</a>".) Une fois votre
inscription validée, ce lien mènera directement à la page dédiée à votre blog. Merci beaucoup !</p>
<p>Vous pouvez aussi utiliser le <a href="/logos">générateur de logos</a> pour créer un logo qui vous ressemble et s\'harmonise avec les couleurs de votre blog !</p>
<a href="/logos"><img src="/images/misc/recettes-de-cuisine-logo-fille.gif" border="none" />
<img src="/images/misc/recettes-de-cuisine-logo-garcon.gif" border="none" />
<img src="/images/misc/recettes_badge.png" border="none" />
</a>
',
suggest_blog_email => ['Merci pour votre proposition de blog sur Recettes de Cuisine',
'Bonjour <NAME>,

Merci d\'avoir proposé votre blog "<BLOG>" sur http://recettes.de/cuisine pour que vos recettes y soient référencées. Il sera visité très bientôt et vous recevrez un e-mail une fois qu\'il sera validé.

Vous pouvez dès maintenant mettre en place des mots-clés sur vos dernières recettes pour qu\'elles soient référencées dès la validation du blog. La mise en place des mots-clés est expliquée sur la page :
http://recettes.de/mode-d-emploi

Merci et à bientôt !

Stéphane
http://recettes.de/cuisine
'],

confirm_blog_email => ['Inscription de <BLOG> sur Recettes de Cuisine',
'Bonjour <NAME>,

Merci beaucoup pour ton inscription !
Comment as-tu connu Recettes de Cuisine ?

Tu trouveras la page dédiée à tes recettes ici :
http://recettes.de/<BLOGID>

Si tu veux essayer d\'autres photos ou couleurs pour le bandeau, il suffit de te connecter sur le site. Il y aura un lien "Modifier" dans la colonne de droite.

Pour que tes recettes apparaissent sur plus de pages, tu peux y ajouter des mots-clés :
http://recettes.de/mode-d-emploi#mots-cles
Les mots-clés permettent de classer les recettes et de gagner des couronnes des royaumes de la cuisine :
http://blog.recettes.de/news/les-royaumes-de-la-cuisine

Si tu veux référencer tes anciennes recettes qui ne sont plus dans le fil RSS, c\'est possible, il faut y ajouter au moins un mot-clé et m\'envoyer par mail la liste des urls.

C\'est grâce aux retours des blogueurs et des lecteurs que j\'améliore le site, merci de me faire part de tes questions, remarques ou suggestions.

J\'apprécie aussi beaucoup toute aide pour faire connaître le site sur les blogs, les forums, Facebook, Twitter etc. :-)

Très bonne journée et à bientôt,

Stéphane
http://recettes.de/cuisine
http://facebook.com/recettesde
http://twitter.com/recettesde 
'],

sent_to_interviewer_email => ['Réponses de <INTERVIEWEE_NAME> à votre interview',
'Bonjour,

<INTERVIEWEE_NAME> a répondu à vos questions. Vous pouvez maintenant la passer en revue et ensuite la publier.
<URL>

A bientôt !

Open Food Facts
http://fr.openfoodfacts.org

'],

validate_blog => 'Valider un blog',
add_blog => 'Ajouter un blog',


edit_blog => 'Modifier les informations du blog',
edit_blog_msg => '<p>Vous pouvez modifier les informations de votre blog, et en particulier changer la couleur et la photo du bandeau de la page du blog.</p>',
edit_blog_confirm => '<p>Votre profil public a bien été modifié.</p>',


delete_blog => 'Effacer un blog',

add_user => "S'inscrire",

edit_user => 'Paramètres du compte',
delete_user => 'Effacer un utilisateur',

add_user_confirm => '<p>Merci de votre inscription. Vous pouvez maintenant vous identifier sur le site pour ajouter et modifier des produits.</p>',
add_user_email => ['Merci de votre inscription sur Open Food Facts',
'Bonjour <NAME>,

Merci de votre inscription sur http://fr.openfoodfacts.org
Voici un rappel de votre identifiant :

Nom d\'utilisateur : <USERID>

Vous pouvez maintenant vous identifier sur le site pour ajouter et modifier des produits.

Open Food Facts est en phase de test, je compte sur vous pour me faire de nombreux retours, par e-mail ou sur le forum des idées :
https://openfoodfactsfr.uservoice.com/

Pour bien commencer, je vous invite à lire la feuille de route :
http://fr.openfoodfacts.org/feuille-de-route-2012

et bien sûr à me dire ce que vous en pensez.

Merci et à bientôt !

Stéphane
http://fr.openfoodfacts.org
'],


reset_password_email => ['Réinitialisation de votre mot de passe sur Open Food Facts',
'Bonjour <NAME>,

Vous avez demandé une réinitialisation de votre mot de passe sur http://fr.openfoodfacts.org

pour l\'utilisateur : <USERID>

Si vous voulez poursuivre cette réinitialisation, cliquez sur le lien ci-dessous.
Si vous n\'êtes pas à l\'origine de cette demande, vous pouvez ignorer ce message.

<RESET_URL>

A bientôt,

Stéphane
http://fr.openfoodfacts.org
'],

edit_user_confirm => '<p>Les paramètres de votre compte ont bien été modifiés.</p>',

validate_news => 'Valider une recette',
add_news => 'Ajouter une recette',
edit_news => 'Modifier une recette',
delete_news => 'Effacer une recette',

add_interview => "Créer une interview",
edit_interview => "Modifier l'interview",
delete_interview => "Supprimer l'interview",
answer_interview => "Répondre à une interview",
send_to_interviewee_interview => "Bravo !",
send_to_interviewer_interview => "Merci pour vos réponses !",

edit_profile => "Modifier votre profil public",
edit_profile_msg => "Les informations ci-dessous figurent dans votre profil public. Elles sont visibles en particulier sur les pages des interviews que vous publiez.",

edit_profile_confirm => "Les modifications de votre profil public ont été enregistrées.",

login_register_title => 'Se connecter',
login_register_content => <<HTML
<p>Connectez-vous pour ajouter des produits ou modifier leurs fiches.</p>

<UNSAVED_FAVORITES>

<form method="post" action="/cgi/session.pl">
Nom d'utilisateur ou adresse e-mail :<br />
<input type="text" name="user_id" tabindex="1" style="width:220px;" /><br />
Mot de passe<br />
<input type="password" name="password" tabindex="2" style="width:220px;" /><br />
<input type="checkbox" name="remember_me" value="on" tabindex="3" /><label>Se souvenir de moi</label><br />
<input type="submit" tabindex="4" name=".submit" value="Se connecter" />
</form>
<p>Pas encore inscrit(e) ? <a href="/cgi/user.pl">Créez votre compte</a>.</p>
HTML
,

suggest_blog_title => "Inscrivez votre blog !",
suggest_blog_content => <<HTML
Si vous publiez des recettes originales sur votre blog et si vous souhaitez qu'elles soient référencées sur <b>Recettes de Cuisine</b>, <a href="/cgi/blog.pl">proposez votre blog</a> !
HTML
,

oq_block_title => "Proposez vos questions !",


on_the_blog_title => "La communauté Open Food Facts",
on_the_blog_content => "<p>Pour découvrir les projets hébergés par Open Food Facts, partager des bonnes pratiques d'interviews, suggérer des améliorations,
 rejoignez la communauté des intervieweurs sur <a href=\"http://blog.interestingviews.fr\">le blog d'Open Food Facts</a></p><p>On en discute en ce moment :</p>",


top_title => "",
top_content => <<HTML

HTML
,

bottom_title => "",
bottom_content => <<HTML

HTML
,
bottom_content_amazon => [
<<HTML
<iframe src="http://rcm-fr.amazon.fr/e/cm?t=dernmode-21&o=8&p=12&l=st1&mode=books-fr&search=gastronomie&fc1=000000&lt1=&lc1=3366FF&bg1=FFFFFF&f=ifr" marginwidth="0" marginheight="0" width="300" height="250" border="0" frameborder="0" style="border:none;" scrolling="no"></iframe>
HTML
,
<<HTML
<iframe src="http://rcm-fr.amazon.fr/e/cm?t=dernmode-21&o=8&p=12&l=st1&mode=kitchen-fr&search=gastronomie&fc1=000000&lt1=_blank&lc1=3366FF&bg1=FFFFFF&f=ifr" marginwidth="0" marginheight="0" width="300" height="250" border="0" frameborder="0" style="border:none;" scrolling="no"></iframe>
HTML
,
<<HTML
<iframe src="http://rcm-fr.amazon.fr/e/cm?t=dernmode-21&o=8&p=12&l=st1&mode=kitchen-fr&search=cuisiner&fc1=000000&lt1=_blank&lc1=3366FF&bg1=FFFFFF&f=ifr" marginwidth="0" marginheight="0" width="300" height="250" border="0" frameborder="0" style="border:none;" scrolling="no"></iframe>
HTML
,
<<HTML
<iframe src="http://rcm-fr.amazon.fr/e/cm?t=dernmode-21&o=8&p=12&l=bn1&mode=books-fr&browse=302050&fc1=000000&lt1=_blank&lc1=3366FF&bg1=FFFFFF&f=ifr" marginwidth="0" marginheight="0" width="300" height="250" border="0" frameborder="0" style="border:none;" scrolling="no"></iframe>
HTML
,
],

menu_title => "Recevez le menu du jour sur Facebook",
menu_content => <<HTML
<fb:like-box href="http://www.facebook.com/pages/Menu-du-jour/206266746065179" width="250" show_faces="true" stream="false" header="true"></fb:like-box>
HTML
,

empty_query => "Votre requête ne contient pas suffisamment de mots.",

subscribe => "S'abonner",
unsubscribe => "Se désabonner",

add_to_favorites => "Ajouter à mon carnet de recettes",
remove_from_favorites => "Retirer de mon carnet de recettes",
empty_favorites => "Il n'y a pas de recettes dans le carnet de recettes.",
my_favorites => "Mon carnet de recettes",
unsaved_favorites_1 => "<b>Attention :</b> vous avez ajouté une recette dans votre carnet de recettes, mais vous n'êtes pas connecté. Connectez-vous pour sauver votre carnet de recettes et y accèder.",
unsaved_favorites_n => "<b>Attention :</b> vous avez ajouté %d recettes dans votre carnet de recettes, mais vous n'êtes pas connecté. Connectez-vous pour sauver votre carnet de recettes et y accèder.",

my_blogs => "Mes blogs préférés",

my_blogs_info => "Vous pouvez vous abonner à vos blogs de cuisine préférés pour être sûr de ne rater aucune de leurs recettes. Cliquez sur le lien \"S'abonner\" à côté du nom des blogs dans les listes de recettes.
Toutes les recettes des blogs auxquels vous vous abonnez seront référencées sur cette page \"Mes blogs préférés\".",

my_blogs_visitor => "Connectez-vous ci-contre pour retrouver vos blogs préférés et pouvoir les consulter depuis n'importe quel ordinateur.",

my_blogs_0 => "Vous n'êtes abonné à aucun blog. Quels sont vos blogs cuisine préférés ?",
my_blogs_1 => "Vous êtes abonné à 1 blog.",
my_blogs_n => "Vous êtes abonné à %d blogs.",

my_blogs_other => "Votre blog culinaire préféré n'est pas présent dans la <a href=\"/blogs\">liste des blogs référencés</a> ? Aidez-nous à rendre ce site plus utile en suggérant à son auteur de l'inscrire.
L'inscription est très rapide et elle apportera à votre blogueuse ou blogueur préféré des nouveaux lecteurs.",



disqus => <<HTML
<div id="disqus_thread"></div>
<script type="text/javascript">
    /* * * CONFIGURATION VARIABLES: EDIT BEFORE PASTING INTO YOUR WEBPAGE * * */
    var disqus_shortname = 'interestingviews-fr'; // required: replace example with your forum shortname

    // The following are highly recommended additional parameters. Remove the slashes in front to use.
    var disqus_identifier = '<disqus_identifier>';
    var disqus_url = '<disqus_url>';
	// var disqus_developer = 1; // developer mode is on
    /* * * DON'T EDIT BELOW THIS LINE * * */
    (function() {
        var dsq = document.createElement('script'); dsq.type = 'text/javascript'; dsq.async = true;
        dsq.src = 'http://' + disqus_shortname + '.disqus.com/embed.js';
        (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(dsq);
    })();
</script>
HTML
,

disqus_comments_count => <<HTML
<script type="text/javascript">
    /* * * CONFIGURATION VARIABLES: EDIT BEFORE PASTING INTO YOUR WEBPAGE * * */
    var disqus_shortname = 'interestingviews-fr'; // required: replace example with your forum shortname

    /* * * DON'T EDIT BELOW THIS LINE * * */
    (function () {
        var s = document.createElement('script'); s.async = true;
        s.type = 'text/javascript';
        s.src = 'http://' + disqus_shortname + '.disqus.com/count.js';
        (document.getElementsByTagName('HEAD')[0] || document.getElementsByTagName('BODY')[0]).appendChild(s);
    }());
</script>
HTML
,

oq_title => 'Questions ouvertes pour ',

);


$css = <<CSS

CSS
;

$header = <<HEADER
<link rel="alternate" type="application/rss+xml" title="RSS" href="http://fr.openfoodfacts.org/rss/products.xml" />
<meta property="fb:admins" content="706410516" />
<meta property="og:site_name" content="Open Food Facts - l'information alimentaire ouverte"/>

<script type="text/javascript">
  var uvOptions = {};
  (function() {
    var uv = document.createElement('script'); uv.type = 'text/javascript'; uv.async = true;
    uv.src = ('https:' == document.location.protocol ? 'https://' : 'http://') + 'widget.uservoice.com/Mjjw72JUjigdFxd4qo6wQ.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(uv, s);
  })();
</script>
HEADER
;


my @stopwords = qw(
a
au
aux
d
de
des
du
en
est
et
j
je
l
la
le
les
m
n
on
ou
pour
s
sa
se
ses
son
sur
un
une

recette
recettes
);

$stopwords{""} = 1;
$stopwords{undef} = 1;
foreach my $word (@stopwords) {
	$stopwords{$word} = 1;
}


1;
