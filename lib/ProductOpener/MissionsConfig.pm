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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package ProductOpener::MissionsConfig;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
			%Missions_by_lang
			%Missions
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Lang qw/:all/;

%Missions_by_lang = (

en => [

{name=>'First contribution', goal=>'Add one product', thanks=>'Thanks for contributing to Open Food Facts!',
conditions=>[[1,{}]]},

],

fr => [

{name=>'Première contribution', goal=>'Ajouter un produit', thanks=>'Merci de contribuer à Open Food Facts !',
conditions=>[[1,{}]]},

{name=>'10 produits', goal=>'Ajouter 10 produits', thanks=>'Merci de contribuer à Open Food Facts !',
conditions=>[[10,{}]]},

{name=>'25 produits', goal=>'Ajouter 25 produits', thanks=>'Merci de contribuer à Open Food Facts !',
conditions=>[[25,{}]]},

{name=>'50 produits', goal=>'Ajouter 50 produits', thanks=>'Merci de contribuer à Open Food Facts !',
conditions=>[[50,{}]]},

{name=>'100 produits', goal=>'Ajouter 100 produits', thanks=>'Merci de contribuer à Open Food Facts !',
conditions=>[[100,{}]]},

{name=>'250 produits', goal=>'Ajouter 250 produits', thanks=>'Merci de contribuer à Open Food Facts !',
conditions=>[[250,{}]]},

{name=>'500 produits', goal=>'Ajouter 500 produits', thanks=>'Merci de contribuer à Open Food Facts !',
conditions=>[[500,{}]]},

{name=>'Informateur - 100 produits', goal=>'Ajouter des informations pour 100 produits', thanks=>'Merci de contribuer à Open Food Facts !',
description=>"Ajoutez des informations (nom, marque, catégories, labels, ingrédients, informations nutritionnelles etc.) pour 100 produits. Vous pouvez ajouter les informations pour les produits que vous avez ajoutés, mais
aussi pour toutes les autres produits dont certaines informations sont manquantes.",
conditions=>[[100,{informers_tags=>'<userid>'}]]},

{name=>'Informateur - 250 produits', goal=>'Ajouter des informations pour 100 produits', thanks=>'Merci de contribuer à Open Food Facts !',
description=>"Ajoutez des informations (nom, marque, catégories, labels, ingrédients, informations nutritionnelles etc.) pour 250 produits. Vous pouvez ajouter les informations pour les produits que vous avez ajoutés, mais
aussi pour toutes les autres produits dont certaines informations sont manquantes.",
conditions=>[[250,{informers_tags=>'<userid>'}]]},

{name=>'Informateur - 500 produits', goal=>'Ajouter des informations pour 100 produits', thanks=>'Merci de contribuer à Open Food Facts !',
description=>"Ajoutez des informations (nom, marque, catégories, labels, ingrédients, informations nutritionnelles etc.) pour 500 produits. Vous pouvez ajouter les informations pour les produits que vous avez ajoutés, mais
aussi pour toutes les autres produits dont certaines informations sont manquantes.",
conditions=>[[500,{informers_tags=>'<userid>'}]]},

{name=>'Informateur - 1000 produits', goal=>'Ajouter des informations pour 100 produits', thanks=>'Merci de contribuer à Open Food Facts !',
description=>"Ajoutez des informations (nom, marque, catégories, labels, ingrédients, informations nutritionnelles etc.) pour 1000 produits. Vous pouvez ajouter les informations pour les produits que vous avez ajoutés, mais
aussi pour toutes les autres produits dont certaines informations sont manquantes.",
conditions=>[[1000,{informers_tags=>'<userid>'}]]},

{name=>'Informateur - 2500 produits', goal=>'Ajouter des informations pour 100 produits', thanks=>'Merci de contribuer à Open Food Facts !',
description=>"Ajoutez des informations (nom, marque, catégories, labels, ingrédients, informations nutritionnelles etc.) pour 2500 produits. Vous pouvez ajouter les informations pour les produits que vous avez ajoutés, mais
aussi pour toutes les autres produits dont certaines informations sont manquantes.",
conditions=>[[2500,{informers_tags=>'<userid>'}]]},

{name=>'So Saucisson!', goal=>'Ajouter 2 produits dans la catégorie Saucisson', thanks=>'Merci pour les saucissons !',
conditions=>[[2,{categories_tags=>'saucissons'}]]},

{name=>'Bio-tiful', goal=>'Ajouter 5 produits avec le label Bio', thanks=>'Merci pour les produits bio !',
conditions=>[[5,{labels_tags=>'bio'}]]},

{name=>'Serrés comme des sardines', goal=>'Ajouter 2 boîtes de sardines en conserve', thanks=>'Merci pour les sardines !',
conditions=>[[2,{categories_tags=>'sardines', packaging_tags=>'conserve'}]]},

{name=>'Jambon moyennement salé', goal=>'Ajouter 2 paquets de tranches de jambon blanc', thanks=>'Merci pour le jambon!',
description=>"Certains paquets de jambon blanc affichent une mention comme \"-25% de sel par rapport à la moyenne des autres jambons\". Cette allégation est-elle vraie ? Pour le savoir, il nous faut référencer un
maximum de paquets de tranches de jambon blanc pour que l'on puisse calculer la teneur moyenne en sel des jambons, et vérifier ainsi la véracité des allégations. Merci d'avance de mettre votre grain de sel !</p>",
conditions=>[[2,{categories_tags=>'jambons-blancs'}]]},

{name=>'Ceinture jaune de jus d\'orange', goal=>'Ajouter 3 jus d\'orange', thanks=>'Merci pour les jus d\'orange !',
description=>"Fraîchement pressé, 100% pur jus, ou jus à base de concentré : il faut ajouter 3 jus d'orange pour obtenir la ceinture jaune.",
conditions=>[[3,{categories_tags=>'jus-d-orange'}]]},

{name=>'Céréales Killer', goal=>'Ajouter 5 céréales pour petit-déjeuner', thanks=>'Merci pour les céréales !',
description=>"Afin de réaliser une étude comparative pourtant sur les céréales pour petit-déjeuner, nous avons besoin d'un maximum de références de céréales. La mission consiste à aller les traquer dans les moindres
recoins du rayon petit-déjeuner des magasins locaux, à les prendre en photo sans se faire repérer (l'utilisation du télé-objectif est possible, mais attention à ne pas avoir la main qui tremble lors du shoot), et
à les ajouter sur Open Food Facts",
conditions=>[[5,{categories_tags=>'cereales-pour-petit-dejeuner'}]]},

{name=>'Tyrosémiophilie', goal=>'Ajouter 10 fromages avec de belles étiquettes !', thanks=>'Merci pour les fromages !',
description=>"La Tyrosémiophilie est le nom donné à la collection d'étiquettes de fromages",
conditions=>[[10,{categories_tags=>'fromages'}]]},

{name=>'Des chiffres et une lettre', goal=>'Ajouter 5 produits avec au moins 6 additifs alimentaires (E330 etc.)', thanks=>'Merci pour les additifs !',
description=>"Les additifs peuvent être indiqué par leur nom, leur nom chimique, ou un nombre précédé de la lettre E.",
conditions=>[[5,{additives_n=>{ '$gte' => 6 }}]]},

{name=>'Releveur d\'empreintes', goal=>'Ajouter 3 produits avec mention de l\'empreinte carbone', thanks=>'Merci pour les empreintes !',
description=>"Le suspect a les doigts près de charbon, à vous de mener l'enquête et de relever ses empreintes ! Des informateurs l\'auraient aperçu dernièrement dans des magasins bio et dans le rayon commerce équitable des grandes surfaces.",
image=>"mission-releveur-d-empreintes.png",
conditions=>[[3,{"nutriments.carbon-footprint"=>{ '$gt' => 0 }}]]},

{name=>'Armoire à glaces', goal=>'Ajouter 3 produits de la catégorie glaces et sorbets', thanks=>'Merci pour les glaces !',
description=>"L'été s'annonce chaud, le réchauffement climatique est là, la banquise fond, et les pingouins ont absolument besoin de vous pour remplir leur armoire à glaces !",
image=>"mission-armoire-a-glaces.png",
image_legend=>"Photo de congélateur rempli de glaces dans un magasin à la Nouvelles Orléans par <a href=\"https://www.flickr.com/photos/pnoeric/2953131289/in/photostream/\">pnoeric - Eric Mueller</a>, licence Creative Commons cc-by-sa.",
conditions=>[[3,{categories_tags=>'glaces-et-sorbets'}]]},

{name=>'J\'ai la Pêche !', goal=>'Ajouter 5 produits de la catégorie Produits de la mer', thanks=>'A bientôt et merci pour tous les poissons !',
description=>"Vous avez la pêche ? Mettez votre énergie et votre enthousiasme en action pour ajouter 5 produits de la mer (poissons, crustacés, algues etc.) sur Open Food Facts !",
image=>"mission-j-ai-la-peche.png",
conditions=>[[5,{categories_tags=>'produits-de-la-mer'}]]},

{name=>'Les 2 végétaux', goal=>'Ajouter 2 laits végétaux', thanks=>'Merci pour les 2 végétaux !',
description=>"Vous savez qu'il existe des <a href=\"https://fr.openfoodfacts.org/categorie/laits-vegetaux\">laits végétaux</a> ? Le lait de soja et le lait de coco bien sûr, mais il existe aussi des laits d'avoine, de riz, d'amandes etc.
Le logo de cette mission est bien sûr une parodie du logo de la marque \"Les 2 vaches\" de Stonyfield, filiale de Danone.",
image=>"mission-les-2-vegetaux.png",
conditions=>[[2,{categories_tags=>'laits-vegetaux'}]]},

{name=>'Goûteur de goûters', goal=>'Ajouter 5 biscuits, gâteaux ou compotes', thanks=>'Merci pour les biscuits !',
description=>"Qui n'a jamais rêvé de devenir goûteur de goûters ? En ajoutant des biscuits, gâteaux, compotes et yaourts à boire,
vous contribuerez à la création de graphiques pour répertorier les goûters contenant le moins de sucre, de gras, d'additifs etc.
(comme le <a href=\"https://fr.openfoodfacts.org/cgi/search.pl?action=process&tagtype_0=categories&tag_contains_0=contains&tag_0=sodas&sort_by=product_name&page_size=20&axis_x=sugars&axis_y=additives_n&graph_title=Sucres%20et%20additifs%20dans%20les%20sodas&series_organic=on&series_fairtrade=on&series_with_sweeteners=on&generate_graph_scatter_plot=1\">graphique du sucre et des additifs dans les sodas</a> créé après l'Opération Sodas)",
image=>"mission-gouteur-de-gouters.png",
conditions=>[[5,{categories_tags=>'gouters'}]]},

{name=>'Am-Stram-Gram Où se cache l\'Aspartame ?', goal=>'Ajouter 10 produits contenant de l\'Aspartame', thanks=>'Merci pour l\'Aspartame !',
description=>"Pour <a href=\"https://fr.blog.openfoodfacts.org/news/evaluation-de-l-exposition-a-l-aspartame\">évaluer l'exposition de la population à l'aspartame</a>, il nous faut trouver le maximum de produits contenant de l'aspartame. En ajoutant des produits
contenant de l'aspartame, vous participez à la première expérience de <a href=\"https://fr.blog.openfoodfacts.org/news/science-citoyenne-et-collaborative\">science citoyenne et collaborative</a> sur Open Food Facts !",
image=>"mission-aspartame.png",
conditions=>[[10,{additives_tags=>'e951'}]]},

{name=>'Légumes secs', goal=>'Ajouter 3 légumes secs', thanks=>'Merci pour les légumes secs !',
description=>"Cette mission vous est proposée par Patrice, professeur de <a href=\"http://www.biotechno.fr/\">Biotechnologies</a> Santé et Environnement en lycée professionnel, qui a besoin pour ses cours d'un maximum de données sur les
légumes secs : haricots, pois-chiches, lentilles etc.",
conditions=>[[3,{categories_tags=>'legumes-secs'}]]},

{name=>'Sans gluten', goal=>'Ajouter 5 produits sans gluten', thanks=>'Merci pour les produits sans gluten !',
description=>"Certaines personnes sont allegiques au gluten ou présentent une intolérance au gluten (maladie cœliaque). Le gluten est présent dans de nombreuses céréales comme le blé, le seigle et l'orge. Ajoutez 5 produits labellisés sans gluten
préparés avec d'autres céréales comme le riz, le millet, le sarrasin, le maïs ou le quinoa qui ne contiennent pas de gluten.",
image=>"mission-sans-gluten.png",
image_legend=>'Photo de champ de millet à Oman par <a href="https://commons.wikimedia.org/wiki/File:Bilad_Sayt_(13).jpg">Ji-Elle</a>, licence <a href="https://creativecommons.org/licenses/by-sa/3.0/deed.en">Creative Commons cc-by</a>',
conditions=>[[5,{labels_tags=>'sans-gluten'}]]},

{name=>'Palmipède', goal=>'Ajouter 10 produits avec de l\'huile de palme', thanks=>'Merci pour les produits avec de l\'huile de palme !',
description=>"L'huile de palme se cache souvent sous l'euphémisme \"huile végétale\" mais elle est parfois clairement indiquée sur l'emballage des produits.",
image=>"mission-palmipede.514.png",
image_legend=>'Photo de palmier à huile par <a href="https://de.wikipedia.org/wiki/User:Frankrae">Frank Krämer</a>, domaine public',
conditions=>[[10,{'ingredients_from_palm_oil_tags'=>'huile-de-palme'}]]},

],

);

foreach my $l (keys %Missions_by_lang) {

	foreach my $mission_ref (@{$Missions_by_lang{$l}}) {

		$mission_ref->{id} = $l . "." . get_fileid($mission_ref->{name});
		$Missions{$mission_ref->{id}} = $mission_ref;
	}
}

1;
