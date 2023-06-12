package ProductOpener::SiteLang;

######################################################################
#
#	Package	SiteLang
#
#	Author:	Stephane Gigandet
#	Date:	23/01/2015
#
######################################################################

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();	# symbols to export by default
	@EXPORT_OK = qw(
	
					%SiteLang				

					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;
use strict;
use utf8;

# %SiteLang overrides the general %Lang in Lang.pm

%SiteLang = (

logo => {
	en => 'openfoodfacts-logo-en-178x150.png',
	ar => 'openfoodfacts-logo-ar-178x150.png',
	de => 'openfoodfacts-logo-de-178x150.png',
	es => 'openfoodfacts-logo-es-178x150.png',
	fr => 'openfoodfacts-logo-fr-178x150.png',
	he => 'openfoodfacts-logo-he-178x150.png',
	nl => 'openfoodfacts-logo-nl-178x150.png',
	nl_be => 'openfoodfacts-logo-nl-178x150.png',
	pl => 'openfoodfacts-logo-pl-178x150.png',
	pt => 'openfoodfacts-logo-pt-178x150.png',
	ru => 'openfoodfacts-logo-ru-178x150.png',
	vi => 'openfoodfacts-logo-vi-178x150.png',
	zh => 'openfoodfacts-logo-zh-178x150.png',
},

logo2x => {
	en => 'openfoodfacts-logo-en-356x300.png',
	ar => 'openfoodfacts-logo-ar-356x300.png',
	de => 'openfoodfacts-logo-de-356x300.png',
	es => 'openfoodfacts-logo-es-356x300.png',
	fr => 'openfoodfacts-logo-fr-356x300.png',
	he => 'openfoodfacts-logo-he-356x300.png',
	nl => 'openfoodfacts-logo-nl-356x300.png',
	nl_be => 'openfoodfacts-logo-nl-356x300.png',
	pl => 'openfoodfacts-logo-pl-356x300.png',
	pt => 'openfoodfacts-logo-pt-356x300.png',
	ru => 'openfoodfacts-logo-ru-356x300.png',
	vi => 'openfoodfacts-logo-vi-356x300.png',
	zh => 'openfoodfacts-logo-zh-356x300.png',
},

tagline => {

    ar => 'Open Food Facts بجمع المعلومات والبيانات على المنتجات الغذائية من جميع أنحاء العالم.', #ar-CHECK - Please check and remove this comment
	de => "Open Food Facts erfasst Nahrungsmittel aus der ganzen Welt.",
    cs => 'Open Food Facts shromažďuje informace a údaje o potravinářské výrobky z celého světa.', #cs-CHECK - Please check and remove this comment
	es => "Open Food Facts recopila información sobre los productos alimenticios de todo el mundo.",
	en => "Open Food Facts gathers information and data on food products from around the world.",
    it => 'Open Food Facts raccoglie informazioni e dati sui prodotti alimentari provenienti da tutto il mondo.', #it-CHECK - Please check and remove this comment
    fi => 'Open Food Facts kerää tietoja elintarvikkeiden tuotteita ympäri maailmaa.', #fi-CHECK - Please check and remove this comment
	fr => "Open Food Facts répertorie les produits alimentaires du monde entier.",
	el => "Το Open Food Facts συγκεντρώνει πληροφορίες και δεδομένα για τρόφιμα από όλο τον κόσμο.",
	he => "המיזם Open Food Facts אוסף מידע ונתונים על מוצרי מזון מכל רחבי העולם.",
    ja => 'Open Food Facts は、世界中から食料品の情報やデータを収集します。', #ja-CHECK - Please check and remove this comment
    ko => 'Open Food Facts 은 세계 각국에서 식품 제품에 대한 정보와 데이터를 수집합니다.', #ko-CHECK - Please check and remove this comment
	nl => "Open Food Facts inventariseert alle voedingsmiddelen uit de hele wereld.",
	nl_be => "Open Food Facts inventariseert alle voedingsmiddelen uit de hele wereld.",
    ru => 'Open Food Facts собирает информацию и данные о пищевых продуктах по всему миру.', #ru-CHECK - Please check and remove this comment
    pl => 'Open Food Facts gromadzi informacje i dane dotyczące produktów spożywczych z całego świata.', #pl-CHECK
    pt => "O Open Food Facts coleciona informação de produtos alimentares de todo o mundo.",
	ro => "Open Food Facts adună informații și date despre produse alimentare din întreaga lume.",
    th => 'Open Food Facts รวบรวมข้อมูลและข้อมูลเกี่ยวกับผลิตภัณฑ์อาหารจากทั่วโลก', #th-CHECK - Please check and remove this comment
    vi => 'Open Food Facts tập hợp thông tin và dữ liệu về các sản phẩm thực phẩm từ khắp nơi trên thế giới.', #vi-CHECK - Please check and remove this comment
    zh => 'Open Food Facts 来自世界各地收集有关食品的信息和数据。', #zh-CHECK - Please check and remove this comment

},

);


1;