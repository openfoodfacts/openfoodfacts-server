package Blogs::SiteLang;

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
);


my %notactive_SiteLang = (


site_name => {
	fr => 'Open Food Facts',
	en => 'Open Food Facts',
	es => 'Open Food Facts',
	de => 'Open Food Facts',
	ru => 'Open Food Facts',
	ar => 'Open Food Facts',
	pt => 'Open Food Facts',
	he => 'Open Food Facts',
},

site_description => { 
	ru => "Совместная, открытая и свободная база данных об ингридиентах, питательности и другой информации по пищевым продуктам мира", 
	fr => "Ingrédients, composition nutritionnelle et information sur les produits alimentaires du monde entier dans une base de données libre et ouverte",
	en => "A collaborative, free and open database of ingredients, nutrition facts and information on food products from around the world",
	de => "Zutaten, Nährwertangaben und weitere Informationen über Nahrungsmittel aus der ganzen Welt in einer offenen und freien Datenbank",
	es => "Ingredientes, información nutricional e información sobre los alimentos del mundo entero en una base de datos libre y abierta",
	it => "Ingredienti, composizione nutrizionale e informazioni sui prodotti alimentari del mondo intero su una base di dati libera e aperta",
	ar => "مكونات, قيمة غذائية و معلومات حول المنتجات الغذائية في العالم الكل في قاعدة بيانات حرة و مفتوحة",
	pt => 'Uma base de dados aberta e colaborativa sobre ingredientes, informações nutricionais e alimentos de todo o mundo',
	he => "מסד נתונים שיתופי, חופשי ופתוח של רכיבים, הרכבים תזונתיים ומידע על מוצרי מזון מכל רחבי העולם.",
},

og_image_url => {
	fr => 'http://fr.openfoodfacts.org/images/misc/openfoodfacts-logo-fr-356.png',
	en => 'http://world.openfoodfacts.org/images/misc/openfoodfacts-logo-en-356.png',
	es => 'http://es.openfoodfacts.org/images/misc/openfoodfacts-logo-es-356.png',
	it => 'http://it.openfoodfacts.org/images/misc/openfoodfacts-logo-it-356.png',
	de => 'http://de.openfoodfacts.org/images/misc/openfoodfacts-logo-de-356.png',
	ar => 'http://world.openfoodfacts.org/images/misc/openfoodfacts-logo-ar-356.png',
	pt => 'http://world.openfoodfacts.org/images/misc/openfoodfacts-logo-pt-356.png',
	he => 'http://world.openfoodfacts.org/images/misc/openfoodfacts-logo-he-356.png',
},

twitter_account => {
	fr => 'OpenFoodFactsFr',
	en => 'OpenFoodFacts',
	de => 'OpenFoodFactsDe',
	es => 'OpenFoodFactsEs',
	it => 'OpenFoodFactsIt',
	ar => 'OpenFoodFactsAr',
	pt => 'OpenFoodFactsPt',
},

add_user_email_subject => { 
	fr => 'Merci de votre inscription sur Open Food Facts',
	en => 'Thanks for joining Open Food Facts',
	de => 'Vielen Dank für ihre Anmeldung auf Open Food Facts',
	es => 'Gracias por registrarse en Open Food Facts',
	it => 'Grazie per la vostra iscrizione a Open Food Facts',
	ar => 'شكرا على انضمامك لموقعنا Open Food Facts',
	pt => 'Obrigado por se juntar ao Open Food Facts',
	he => 'תודה לך על הצטרפותך ל־Open Food Facts',
},

add_user_email_body => {
	fr => 
'Bonjour <NAME>,

Merci beaucoup de votre inscription sur http://openfoodfacts.org
Voici un rappel de votre identifiant :

Nom d\'utilisateur : <USERID>

Vous pouvez maintenant vous identifier sur le site pour ajouter et modifier des produits.

Vous pouvez également rejoindre le groupe des contributeurs sur Facebook :
https://www.facebook.com/groups/356858984359591/

et/ou la liste de discussion en envoyant un e-mail vide à off-fr-subscribe\@openfoodfacts.org

Open Food Facts est un projet collaboratif auquel vous pouvez apporter bien plus que des produits : votre enthousiasme et vos idées !
Vous pouvez en particulier partager vos suggestions sur le forum des idées :
https://openfoodfactsfr.uservoice.com/

Et ma boîte mail est bien sûr grande ouverte pour toutes vos remarques, questions ou suggestions.

Merci beaucoup et à bientôt !

Stéphane
http://openfoodfacts.org
http://twitter.com/OpenFoodFactsFr
',

	it =>
'Buongiorno <NAME>,

Grazie per essersi  iscritto su http://openfoodfacts.org

Ecco un riassunto dei vostri dati identificativi:

Nome d\'utilizzatore: <USERID>

Adesso potete identificarvi sul sito per aggiungere e modificare dei prodotti.

Potete ugualmente raggiungere il gruppo dei contribuenti su Facebook:
https://www.facebook.com/groups/447693908583938/

Open Food Facts è un progetto di collaborazione al quale potete aggiungere ben più che dei prodotti: il vostro entusiasmo e le vostre idee.
https://openfoodfacts.uservoice.com/

La mia casella mail è abbastanza grande e aperta per tutti i vostri suggerimenti, commenti e domande. (in English / en français se possibile...)

Grazie!

Stéphane
http://openfoodfacts.org
http://twitter.com/OpenFoodFactsIt
',

	en => 
'Hello <NAME>,

Thanks a lot for joining http://openfoodfacts.org
Here is your user name:

User name: <USERID>

You can now sign in on the site to add and edit products.

You can also join the Facebook group for contributors:
https://www.facebook.com/groups/374350705955208/

Open Food Facts is a collaborative project to which you can bring much more than new products: your energy, enthusiasm and ideas!
You can also share your suggestions on the idea forum:
http://openfoodfacts.uservoice.com/

And my mailbox is of course wide open for your comments, questions and ideas.

Thank you very much!

Stéphane
http://openfoodfacts.org
http://twitter.com/OpenFoodFacts
',

	es => 
'Buenos días <NAME>,

Muchas gracias por registrarse en http://openfoodfacts.org
Su nombre de usuario es:

Nombre de usuario: <USERID>

A partir de ahora podrá identificarse en el sitio para añadir y editar productos.

Si lo desea, también podrá unirse al grupo de Facebook para usuarios en español:
https://www.facebook.com/groups/470069256354172/

Open Food Facts es un proyecto colaborativo al que puede aportar mucho más que información sobre los productos:  ¡Su energía, su entusiasmo y sus ideas!
También podrá  compartir sus sugerencias en el foro de nuevas ideas:
http://openfoodfacts.uservoice.com/

Y por supuesto, mi correo electrónico está disponible para todos los comentarios, ideas o preguntas que le puedan surgir.

¡Muchas gracias!

Stéphane
http://openfoodfacts.org
http://twitter.com/OpenFoodFactsEs
',

	de => 
'Hallo <NAME>,

Vielen Dank, dass Sie http://openfoodfacts.org beigetreten sind.
Hier finden Sie Ihren Benutzernamen:

Benutzername: <USERID>

Sie können sich jetzt auf der Seite anmelden und Produkte hinzufügen oder abändern.

Sie können auch der Facebookgruppe für Unterstützer beitreten:
https://www.facebook.com/groups/488163711199190/

Open Food Facts ist ein gemeinschaftliches Projekt zu dem Sie noch viel mehr als neue Produkte beitragen können: Ihre Energie, Ihren Enthusiasmus und neue Ideen! 
Auf dem Ideenforum können Sie ihre Vorschläge mit uns teilen:
http://openfoodfacts.uservoice.com/

Und meine Mailbox ist selbstverständlich immer offen für Kommentare, Fragen und Ideen.

Vielen herzlichen Dank!

Stéphane
http://openfoodfacts.org
http://twitter.com/OpenFoodFactsDe
',

	pt => 
'Olá <NAME>,

Muito obrigado por se juntar ao http://world.openfoodfacts.org
Esse é o seu nome de usuário:

Nome de usuário: <USERID>

Você pode aceder ao site para adicionar ou editar produtos.

Você também pode entrar no grupo de colaboradores no Facebook:
https://www.facebook.com/groups/374350705955208/

O Open Food Facts é um projeto colaborativo para o qual você pode trazer muito mais que novos produtos: sua energia, entusiasmo e ideias!
Você também pode compartilhar suas sugestões no fórum de ideias:
http://openfoodfacts.uservoice.com/

E minha caixa de email está totalmente aberta para seus comentários, questões e ideias.

Muito obrigado!

Stéphane
http://openfoodfacts.org
http://twitter.com/OpenFoodFactsPt
',

	pt_pt => 
'Olá <NAME>,

Muito obrigado por se juntar ao http://world.openfoodfacts.org
Esse é o seu nome de utilizador:

Nome de utilizador: <USERID>

Você pode aceder ao site para adicionar ou editar produtos.

Você também pode entrar no grupo de colaboradores no Facebook:
https://www.facebook.com/groups/374350705955208/

O Open Food Facts é um projeto colaborativo para o qual você pode trazer muito mais que novos produtos: a sua energia, entusiasmo e ideias!
Pode partilhar as suas sugestões no fórum de ideias:
http://openfoodfacts.uservoice.com/

E a minha caixa de email está totalmente aberta para os seus comentários, questões e ideias.

Muito obrigado!

Stéphane
http://openfoodfacts.org
http://twitter.com/OpenFoodFactsPt
',

	he => 
'שלום <NAME>,

תודה רבה לך על הצטרפותך ל־http://openfoodfacts.org
להלן שם המשתמש שלך:

שם משתמש: <USERID>

מעתה ניתן להיכנס לאתר כדי להוסיף או לערוך מוצרים.

ניתן להצטרף גם לקבוצת הפייסבוק למתנדבים:
https://www.facebook.com/groups/374350705955208/

מיזם Open Food Facts הנו שיתופי ומאפשר לך להוסיף הרבה יותר מאשר רק מוצרים חדשים: האנרגיה, ההתלהבות והרעיונות שלך!
ניתן גם לשתף את הצעותיך בפורום הרעיונות:
http://openfoodfacts.uservoice.com/

וכתובת הדוא״ל שלי כמובן פתוחה לרווחה להצעות, שאלות ורעיונות.

תודה רבה לך!

סטפן
http://openfoodfacts.org
http://twitter.com/OpenFoodFacts
',
},

reset_password_email_subject => {
	fr => 'Réinitialisation de votre mot de passe sur Open Food Facts',
        de => 'Setze dein Passwort auf Open Food Facts zurück',
	en => 'Reset of your password on Open Food Facts',
	es => 'Cambio de la contraseña de su cuenta en Open Food Facts',
	pt => 'Modifique a sua senha do Open Food Facts',
	pt_pt => 'Reposição da sua palavra-passe no Open Food Facts',
	he => 'איפוס הססמה שלך ב־Open Food Facts',
},

reset_password_email_body => {
	fr => 
'Bonjour <NAME>,

Vous avez demandé une réinitialisation de votre mot de passe sur http://openfoodfacts.org

pour l\'utilisateur : <USERID>

Si vous voulez poursuivre cette réinitialisation, cliquez sur le lien ci-dessous.
Si vous n\'êtes pas à l\'origine de cette demande, vous pouvez ignorer ce message.

<RESET_URL>

A bientôt,

Stéphane
http://openfoodfacts.org
',

	de => 
'Hallo <NAME>,

du hast eine Passwort-Zurücksetzung auf http://openfoodfacts.org

für folgenden Benutzer angefordert: <USERID>

Um die Passwort-Zurücksetzung abzuschließen, klicke auf den Link unten.
Falls du keine Zurücksetzung angefordert hast, ignoriere diese E-Mail einfach.

<RESET_URL>

Mit freundlichen Grüßen

Stephane
http://openfoodfacts.org
',

	en => 
'Hello <NAME>,

You asked for your password to be reset on http://openfoodfacts.org

for the username: <USERID>

To continue the password reset, click on the link below.
If you did not ask for the password reset, you can ignore this message.

<RESET_URL>

See you soon,

Stephane
http://openfoodfacts.org
',

	es => 
'Buenos días <NAME>,

Ha solicitado el cambio de contraseña en http://openfoodfacts.org

para la cuenta de usuario: <USERID>

Para continuar con el cambio de la contraseña, haga clic en el enlace de abajo.
Si por el contrario no desea cambiar la contraseña, ignore este mensaje.

<RESET_URL>

Esperamos verle pronto de nuevo,

Stephane
http://openfoodfacts.org
',

	ar =>
'مرحبا <NAME>، 
لقد طلبت إعادة تعين كلمة المرور الخاصة بك للموقع  http://openfoodfacts.org 
لإسم المستخدم  <USERID> : 

لمواصلة إعادة تعيين كلمة المرور، انقر على الرابط أدناه.
إذا كنت لم تطلب إعادة تعيين كلمة المرور، يمكنك تجاهل هذه الرسالة.

<RESET_URL>

الي اللقاء،

ستيفان
http://openfoodfacts.org
',

	pt => 
'Olá <NAME>,

Você pediu para modificar sua senha do  http://openfoodfacts.org

para o nome de usuário: <USERID>

Para continuar com a modificação de senha, clique no link abaixo.
Se você não pediu para modificar sua senha, você pode ignorar essa mensagem.

<RESET_URL>

Até logo

Stephane
http://openfoodfacts.org
',

	pt_pt =>
'Olá <NAME>,

Você pediu para repor a sua palavra-passe no http://openfoodfacts.org

para o nome de utilizador: <USERID>

Para continuar com a reposição da palavra-passe, clique no link abaixo.
Se não pediu para repor a sua palavra-passe, ignore esta mensagem.

<RESET_URL>

Até logo,

Stephane
http://openfoodfacts.org
',

	he => 
'שלום <NAME>,

ביקשת לאפס את ססמת המשתמש שלך ב־http://openfoodfacts.org

עבור המשתמש: <USERID>

כדי להמשיך בתהליך איפוס הססמה עליך ללחוץ על הקישור שלהלן.
אם לא ביקשת לאפס את הססמה, ניתן להתעלם מהודעה זו.

<RESET_URL>

נתראה בקרוב,

סטפן
http://openfoodfacts.org
',
},



login_to_add_products => {
	fr => <<HTML
<p>Vous devez vous connecter pour pouvoir ajouter ou modifier un produit.</p>

<p>Si vous n'avez pas encore de compte sur Open Food Facts, vous pouvez <a href="http://fr.openfoodfacts.org/cgi/user.pl">vous inscrire en 30 secondes</a>.</p> 
HTML
,
        de => <<HTML
<p>Bitte melde dich an, um ein Produkt hinzuzufügen oder zu bearbeiten.</p>

<p>Wenn du noch kein Benutzerkonto auf Open Food Facts hast, dann kannst du dich <a href="/cgi/user.pl">innerhalb von 30 Sekunden anmelden</a>.</p>
HTML
,
	en => <<HTML
<p>Please sign-in to add or edit a product.</p>

<p>If you do not yet have an account on Open Food Facts, you can <a href="/cgi/user.pl">register in 30 seconds</a>.</p>
HTML
,
ar => <<HTML
<p>الرجاء تسجيل الدخول لإضافة أو تعديل المنتج.</p>
<p>إذا لم يكن لديك حساب حتى الآن على Open Food Facts، يمكنك <a href="/cgi/user.pl">التسجيل في 30 ثانية</a>.</p>
HTML
,
	pt => <<HTML
<p>Por favor autentique-se para adicionar ou editar um produto.</p>

<p>Se você ainda não possui uma conta no Open Food Facts, você pode <a href="/cgi/user.pl">registrar-se em 30 segundos</a>.</p>
HTML
,
	pt_pt => <<HTML
<p>Por favor autentique-se para adicionar ou editar um produto.</p>

<p>Se ainda não possui uma conta no Open Food Facts, pode <a href="/cgi/user.pl">registar-se em 30 segundos</a>.</p>
HTML
,
	he => <<HTML
<p>נא להיכנס כדי להוסיף או לערוך מוצר.</p>

<p>אם עדיין אין לך חשבון ב־Open Food Facts, יש לך אפשרות <a href="/cgi/user.pl">להירשם תוך 30 שניות</a>.</p>
HTML
,

},


on_the_blog_title => {
	fr => "Actualité",
       de => "Neuigkeiten",
	en => "News",
	es => "Noticias",
	it => "Attualità",
	ar => "الاخبار",
	pt => 'Notícias',
	he => "חדשות",
},  
on_the_blog_content => {
	en => <<HTML
<p>To learn more about Open Food Facts, visit <a href="http://en.blog.openfoodfacts.org">our blog</a>!</p>
<p>Recent news:</p>
HTML
,
        de => <<HTML
<p>Um mehr über Open Food Facts zu erfahren, besuche <a href="http://en.blog.openfoodfacts.org">unseren Blog</a>!</p>
<p>Aktuelle Neuigkeiten:</p>
HTML
,
	fr => <<HTML
<p>Pour découvrir les nouveautés et les coulisses d'Open Food Facts, venez sur <a href="http://fr.blog.openfoodfacts.org">le blog</a> !</p>
<p>C'est nouveau :</p>
HTML
,
	es => <<HTML
<p>Descubre las novedades y muchas cosas más, visitando<a href="http://fr.blog.openfoodfacts.org">el blog (en francés)</a> !</p>
<p>Estas son las novedades:</p>
HTML
,
	it => <<HTML
<p>Per scoprire le novità e il dietro le quinte di Open Food Facts, venite su su<a href="http://fr.blog.openfoodfacts.org">le blog</a> !</p>
<p>Qui sono le novità:</p>
HTML
,
	pt =><<HTML
<p>Para saber mais sobre o Open Food Facts, visite <a href="http://en.blog.openfoodfacts.org">nosso blog</a>!</p>
<p>Notícias recentes:</p>
HTML
,
	he => <<HTML
<p>למידע נוסף על Open Food Facts, ניתן לבקר ב<a href="http://en.blog.openfoodfacts.org">בלוג שלנו</a>(באנגלית)!</p>
<p>חדשות עדכניות:</p>
HTML
,
},

bottom_title => {
	fr => "Partez en mission",
	xes => "Participa en la misión",
	xit => "Partite in missione",   
	xpt => "Participe na missão",
	he => "הרתמו למשימה",
},

bottom_content => {
	fr => <<HTML
<a href="http://fr.openfoodfacts.org/mission/releveur-d-empreintes">
<img src="/images/misc/mission-releveur-d-empreintes.png" width="265" height="222" />
</a>
<p>Contribuez à Open Food Facts en ajoutant des produits et gagnez
des étoiles en remplissant <a href="/missions">les missions</a> !</p>
HTML
,
	xes => <<HTML
<a href="http://es.openfoodfacts.org/mision/determinar-la-huella-de-carbono">
<img src="/images/misc/mision-determinar-la-huella-de-carbono.png" width="265" height="222" />
</a>
<p>Contribuye a Open Food Facts añadiendo productos y gana estrellas participando en <a href="/missions">las misiones</a> !</p>
HTML
,
	xpt => <<HTML
<a href="http://es.openfoodfacts.org/mision/determinar-la-huella-de-carbono">
<img src="/images/misc/mision-determinar-la-huella-de-carbono.png" width="265" height="222" /> 
</a>
<p>Contribua para o Open Food Facts adicionando produtos e ganhe estrelas participando em <a href="/missions">missões</a> !</p>
HTML
,
},


warning_3rd_party_content => {
	fr => "Les informations doivent provenir de l'emballage du produit (et non d'autres sites ou du site du fabricant), et vous devez avoir pris vous-même les photos.<br/>
→ <a href=\"https://openfoodfactsfr.uservoice.com/knowledgebase/articles/59183\" target=\"_blank\">Pourquoi est-ce important ?</a>",    
	en => "Information and data must come from the product package and label (and not from other sites or the manufacturer's site), and you must have taken the pictures yourself.<br/>
→ <a href=\"\">Why it matters</a>",
	es => "La información debe provenir del propio envase del producto (y no de otros sitios o del sitio web del fabricante), y las fotografías deben haber sido tomadas por usted mismo/a.<br/>
→ <a href=\"\">¿Por qué es importante?</a>",
	pt_pt => "A informação deve ser proveniente da embalabem e do rótulo do produto (e não de outros locais ou da página web do fabricante), e as fotografias devem ser tirados por si mesmo.<br/>
→ <a href=\"\">Porque é que é importante?</a>",
	he => "יש להשתמש במידע ובנתונים המופיעים על אריזת המוצר לרבות התווית (ולא מאתרים אחרים או מאתר היצרן), נוסף על כך יש להשתמש בתמונות שצולמו על ידיך בלבד.<br/>",
},



css => {
	fr => <<CSS
CSS
,
	es => <<CSS
CSS
,
},

header => {
	fr => <<HEADER
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
,
	en => <<HEADER
<meta property="fb:admins" content="706410516" />
<meta property="og:site_name" content="Open Food Facts - the free and open food products information database"/>

<script type="text/javascript">
  var uvOptions = {};
  (function() {
	var uv = document.createElement('script'); uv.type = 'text/javascript'; uv.async = true;
	uv.src = ('https:' == document.location.protocol ? 'https://' : 'http://') + 'widget.uservoice.com/jQrwafQ94nbEbRWsznm6Q.js';
	var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(uv, s);
  })();
</script>


HEADER
,
	es => <<HEADER
<meta property="fb:admins" content="706410516" />
<meta property="og:site_name" content="Open Food Facts - la información alimentaria libre"/>

<script type="text/javascript">
  var uvOptions = {};
  (function() {
	var uv = document.createElement('script'); uv.type = 'text/javascript'; uv.async = true;
	uv.src = ('https:' == document.location.protocol ? 'https://' : 'http://') + 'widget.uservoice.com/jQrwafQ94nbEbRWsznm6Q.js';
	var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(uv, s);
  })();
</script>


HEADER
,
	pt => <<HEADER
<meta property="fb:admins" content="706410516" />
<meta property="og:site_name" content="Open Food Facts - informações abertas de alimentos"/>

<script type="text/javascript">
  var uvOptions = {};
  (function() {
	var uv = document.createElement('script'); uv.type = 'text/javascript'; uv.async = true;
	uv.src = ('https:' == document.location.protocol ? 'https://' : 'http://') + 'widget.uservoice.com/jQrwafQ94nbEbRWsznm6Q.js';
	var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(uv, s);
  })();
</script>


HEADER
,
},


menu => {
	fr => <<HTML
<ul>
<li><a href="/a-propos" title="En savoir plus sur Open Food Facts">A propos</a></li>
<li><a href="/mode-d-emploi" title="Pour bien démarrer en deux minutes">Mode d'emploi</a></li>
<li><a href="/contact" title="Des questions, remarques ou suggestions ?">Contact</a></li>
</ul>
HTML
,
	en => <<HTML
<ul>
<li><a href="/about" title="More info about Open Food Facts">About</a></li>
<li><a href="/quickstart-guide" title="How to add products in 2 minutes">Quickstart guide</a></li>
<li><a href="/contact" title="Questions, comments or suggestions?">Contact</a></li>
</ul>
HTML
,
	es => <<HTML
<ul>
<li><a href="/acerca-de" title="Más información acerca de Open Food Facts">Acerca de</a></li>
<li><a href="/guia-de-inicio-rapido" title="Cómo añadir productos en 2 minutos">Guía de inicio rápido</a></li>
<li><a href="/contacto" title="Preguntas, comentarios o sugerencias?">Contacto</a></li>
</ul>
HTML
,
	he => <<HTML
<ul>
<li><a href="/about" title="מידע נוסף על Open Food Facts">על אודות</a></li>
<li><a href="/quickstart-guide" title="איך להוסיף מוצרים ב־2 דקות">מדריך זריז למתחילים</a></li>
<li><a href="/contact" title="שאלותת הערות או הצעות??">יצירת קשר</a></li>
</ul>
HTML
,
	pt => <<HTML
<ul>
<li><a href="/about" title="Mais informação sobre Open Food Facts">Acerca de</a></li>
<li><a href="/quickstart-guide" title="Como adicionar produtos em 2 minutos">Guia de início rápido</a></li>
<li><a href="/contact" title="Perguntas, comentários ou sugestões?">Contacto</a></li>
</ul>
HTML
,
},

column => {

	fr => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-fr.png" width="178" height="141" alt="Open Food Facts" /></a>

<p>Open Food Facts répertorie les produits alimentaires du monde entier.</p>

<select_country>

<p>
→ <a href="/marques">Marques</a><br />
→ <a href="/categories">Catégories</a><br/>
→ <a href="/additifs">Additifs</a><br/>
</p>

<p>
Les informations sur les aliments
sont collectées de façon collaborative et mises à disposition de tous
dans une base de données ouverte et gratuite.</p>

<p>Application mobile disponible pour iPhone et iPad sur l'App Store :</p>

<a href="https://itunes.apple.com/fr/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_FR_135x40.png" alt="Disponible sur l'App Store" width="135" height="40" /></a><br/>

<p>pour Android sur Google Play :</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Disponible sur Google Play" width="135" height="47" /></a><br/>

<p>pour Windows Phone :</p>

<a href="http://www.windowsphone.com/fr-fr/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" /></a><br/>

<br/>

<p>Retrouvez-nous aussi sur :</p>

<p>
→ <a href="http://fr.wiki.openfoodfacts.org">le wiki</a><br />
→ <a href="http://twitter.com/openfoodfactsfr">Twitter</a><br/>
→ <a href="https://plus.google.com/u/0/b/102622509148794386660/102622509148794386660/">Google+</a><br />
→ <a href="https://www.facebook.com/OpenFoodFacts.fr">Facebook</a><br />
+ <a href="https://www.facebook.com/groups/356858984359591/">groupe des contributeurs</a><br />
→ <a href="mailto:off-fr-subscribe\@openfoodfacts.org">envoyez un e-mail vide</a> pour
vous abonner à la liste de discussion<br/>
</p>

<br />
HTML
,

	en => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-en.png" width="178" height="144" alt="Open Food Facts" /></a>

<p>Open Food Facts gathers information and data on food products from around the world.</p>

<select_country>

<p>
→ <a href="/brands">Brands</a><br />
→ <a href="/categories">Categories</a><br/>
</p>

<p>Food product information (photos, ingredients, nutrition facts etc.) is collected in a collaborative way
and is made available to everyone and for all uses in a free and open database.</p>


<p>Find us also on:</p>

<p>
→ <a href="http://en.wiki.openfoodfacts.org">our wiki</a><br />
→ <a href="http://twitter.com/openfoodfacts">Twitter</a><br/>
→ <a href="https://plus.google.com/u/0/110748322211084668559/">Google+</a><br />
→ <a href="https://www.facebook.com/OpenFoodFacts">Facebook</a><br />
+ <a href="https://www.facebook.com/groups/374350705955208/">contributors group</a><br />
</p>

<p>iPhone and iPad app on the App Store:</p>

<a href="https://itunes.apple.com/en/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_EN_135x40.png" alt="Available on the App Store" width="135" height="40" /></a><br/>

<p>Android app on Google Play:</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Available on Google Play" width="135" height="47" /></a><br/>

<p>Windows Phone app:</p>

<a href="http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" /></a><br/>


HTML
,


# Arabic

ar => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-ar.png" width="178" height="148" alt="Open Food Facts" /></a>

<p>Open Food Facts gathers information and data on food products from around the world.</p>

<select_country>

<p>
→ <a href="/brands">Brands</a><br />
→ <a href="/categories">Categories</a><br/>
</p>

<p>Food product information (photos, ingredients, nutrition facts etc.) is collected in a collaborative way
and is made available to everyone and for all uses in a free and open database.</p>

<p>Find us also on:</p>

<p>
→ <a href="http://en.wiki.openfoodfacts.org">our wiki</a><br />
→ <a href="http://twitter.com/openfoodfacts">Twitter</a><br/>
→ <a href="https://plus.google.com/u/0/110748322211084668559/">Google+</a><br />
→ <a href="https://www.facebook.com/OpenFoodFacts">Facebook</a><br />
+ <a href="https://www.facebook.com/groups/374350705955208/">contributors group</a><br />
</p>

<p>iPhone and iPad app on the App Store:</p>

<a href="https://itunes.apple.com/en/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_EN_135x40.png" alt="Available on the App Store" width="135" height="40" /></a><br/>

<p>Android app on Google Play:</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Available on Google Play" width="135" height="47" /></a><br/>

<p>Windows Phone app:</p>

<a href="http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" /></a><br/>


HTML
,

	de => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-de.png" width="178" height="142" alt="Open Food Facts" /></a>   
	
<p>Open Food Facts erfasst Nahrungsmittel aus der ganzen Welt.</p>

<select_country>

<p>
→ <a href="/marken">Marken</a><br />
→ <a href="/kategorien">Kategorien</a><br/>
</p>

<p>
Die Informationen über die Produkte (Fotos, Inhaltsstoffe, Zusammensetzung, etc.) werden gemeinsam gesammelt, für alle frei zugänglich gemacht und können danach für jegliche Nutzung verwendet werden. Die Datenbank ist offen, frei und gratis.</p>


<p>Wir sind auch zu finden auf:</p>

<p>
→ <a href="http://en.wiki.openfoodfacts.org">our wiki</a><br />
→ <a href="http://twitter.com/openfoodfactsde">Twitter</a><br/>
→ <a href="https://plus.google.com/u/0/110748322211084668559/">Google+</a><br />
→ <a href="https://www.facebook.com/OpenFoodFacts">Facebook</a><br />
+ <a href="https://www.facebook.com/groups/488163711199190/">Gruppe der Unterstützer</a><br />  
</p>


<p>iPhone and iPad app on the App Store:</p>

<a href="https://itunes.apple.com/en/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_EN_135x40.png" alt="Available on the App Store" width="135" height="40" /></a><br/>

<p>Android app on Google Play:</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Available on Google Play" width="135" height="47" /></a><br/>

<p>Windows Phone app:</p>

<a href="http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" /></a><br/>

HTML
,

	es => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-es.png" width="178" height="141" alt="Open Food Facts" /></a> 

<p>Open Food Facts recopila información sobre los productos alimenticios de todo el mundo.</p> 

<select_country>

<p> 
→ <a href="/marcas">Marcas</a><br /> 
→ <a href="/categorias">Categorías</a><br/> 
</p> 

<p> 
La información sobre los alimentos (imágenes, ingredientes, composición nutricional etc.)
se reúne de forma colaborativa y es puesta a disposición de todo el mundo
para cualquier uso en una base de datos abierta, libre y gratuita.
</p> 


<p>Puedes encontrarnos también en :</p> 

<p> 
→ <a href="http://en.wiki.openfoodfacts.org">Nuestra wiki (inglés)</a><br />
→ <a href="http://twitter.com/openfoodfactses">Twitter</a><br/> 
→ <a href="https://plus.google.com/u/0/b/102622509148794386660/">Google+</a><br /> 
→ <a href="https://www.facebook.com/OpenFoodFacts.fr">Facebook (en francés)</a><br /> 
+ <a href="https://www.facebook.com/groups/470069256354172/">Grupo de los contribuidores en Facebook (en español)</a><br /> 
</p>


<p>Aplicación para móviles disponible para iPhone e iPad en la App Store:</p>

<a href="https://itunes.apple.com/en/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_EN_135x40.png" alt="Disponible en la App Store" width="135" height="40" /></a><br/>

<p>para Android en Google Play:</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Disponible en Google Play" width="135" height="47" /></a><br/>

<p>para Windows Phone:</p>

<a href="http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" /></a><br/>


HTML
,

#PT-BR

pt => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-pt.png" width="178" height="143" alt="Open Food Facts" /></a>

<p>O Open Food Facts coleciona informação de produtos alimentares de todo o mundo.</p>

<select_country>

<p>
→ <a href="/marcas">Marcas</a><br />
→ <a href="/categorias">Categorias</a><br/>
</p>

<p>Informações de produtos alimentares (fotos, ingredientes, informações nutricionais etc.) são coletadas de forma colaborativa e são disponibilizadas para todas as pessoas e para todos os usos em uma base de dados livre e aberta.</p>

<p>Encontre-nos também em:</p>

<p>
→ <a href="http://en.wiki.openfoodfacts.org">nossa wiki</a><br />
→ <a href="http://twitter.com/openfoodfacts">Twitter</a><br/>
→ <a href="https://plus.google.com/u/0/110748322211084668559/">Google+</a><br />
→ <a href="https://www.facebook.com/OpenFoodFacts">Facebook</a><br />
+ <a href="https://www.facebook.com/groups/420574551372737/">grupo de colaboradores</a><br />
</p>

<p>Aplicativo para iPhone e iPad na App Store:</p>

<a href="https://itunes.apple.com/en/app/open-food-facts/id588797948"><img src="/images/misc/Available_on_the_App_Store_Badge_EN_135x40.png" alt="Available on the App Store" width="135" height="40" /></a><br/>

<p>Aplicativo Android no Google Play:</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Available on Google Play" width="135" height="47" /></a><br/>

<p>Aplicativo Windows Phone:</p>

<a href="http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="Windows Phone Store" width="154" height="40" /></a><br/>

HTML
,
	he => <<HTML
<a href="/"><img id="logo" src="/images/misc/openfoodfacts-logo-he.png" width="178" height="143" alt="Open Food Facts" /></a>

<p>המיזם Open Food Facts אוסף מידע ונתונים על מוצרי מזון מכל רחבי העולם.</p>

<select_country>

<p>
← <a href="/brands">מותגים</a><br />
← <a href="/categories">קטגוריות</a><br/>
</p>

<p>המידע על מוצרי המזון (תמונות, רכיבים, מפרט תזונתי וכו׳) נאסף באופן שיתופי
ונגיש לציבור הרחב לכל שימוש שהוא במסד נתונים חופשי ופתוח.</p>


<p>ניתן למצוא אותנו בערוצים הבאים:</p>

<p>
← <a href="http://en.wiki.openfoodfacts.org">הוויקי שלנו</a><br />
← <a href="http://twitter.com/openfoodfacts">טוויטר</a><br/>
← <a href="https://plus.google.com/u/0/110748322211084668559/">Google+</a><br />
← <a href="https://www.facebook.com/OpenFoodFacts">פייסבוק</a><br />
+ <a href="https://www.facebook.com/groups/374350705955208/">קבוצת התורמים</a><br />
</p>

<p>יישום ל־iPhone ול־iPad ב־App Store:</p>

<a href="https://itunes.apple.com/en/app/open-food-facts/id588797948"><img src="/images/misc/Download_on_the_App_Store_Badge_HB_135x40_1113.png" alt="זמין להורדה מה־App Store" width="135" height="40" /></a><br/>

<p>יישום לאנדרויד ב־Google Play:</p>

<a href="https://play.google.com/store/apps/details?id=org.openfoodfacts.scanner"><img src="/images/misc/android-app-on-google-play-en_app_rgb_wo_135x47.png" alt="Available on Google Play" width="135" height="47" /></a><br/>

<p>יישום ל־Windows Phone:</p>

<a href="http://www.windowsphone.com/en-us/store/app/openfoodfacts/5d7cf939-cfd9-4ac0-86d7-91b946f4df34"><img src="/images/misc/154x40_WP_Store_blk.png" alt="החנות של Windows Phone" width="154" height="40" /></a><br/>


HTML
,
},


footer => {
	fr => <<HTML

<a href="http://fr.openfoodfacts.org/mentions-legales">Mentions légales</a> - 
<a href="http://fr.openfoodfacts.org/conditions-d-utilisation">Conditions d'utilisation</a> -
<a href="http://fr.openfoodfacts.org/qui-sommes-nous">Qui sommes nous ?</a> -
<a href="http://fr.openfoodfacts.org/questions-frequentes">Questions fréquentes</a> -
<a href="https://openfoodfactsfr.uservoice.com/">Forum des idées</a> -
<a href="http://fr.blog.openfoodfacts.org">Blog</a> -
<a href="http://fr.openfoodfacts.org/presse-et-blogs">Presse, Blogs et Présentations</a>
HTML
,

	en => <<HTML
<a href="http://world.openfoodfacts.org/legal">Legal</a> - 
<a href="http://world.openfoodfacts.org/terms-of-use">Terms of Use</a> -
<a href="http://world.openfoodfacts.org/who-we-are">Who we are</a> -
<a href="http://world.openfoodfacts.org/faq">Frequently Asked Questions</a> -
<a href="https://openfoodfacts.uservoice.com/">Ideas Forum</a> -
<a href="http://en.blog.openfoodfacts.org">Blog</a> -
<a href="http://world.openfoodfacts.org/press-and-blogs">Press and Blogs</a>
HTML
,

	es => <<HTML
<a href="http://world.openfoodfacts.org/legal">Aviso legal (inglés)</a> - 
<a href="http://world.openfoodfacts.org/terms-of-use">Condiciones de uso (inglés)</a> -
<a href="http://world.openfoodfacts.org/who-we-are">¿Quiénes somos? (inglés)</a> -
<a href="http://world.openfoodfacts.org/faq">Preguntas frecuentes (inglés)</a> -
<a href="https://openfoodfacts.uservoice.com/">Foro de ideas (inglés)</a> -
<a href="http://fr.blog.openfoodfacts.org">Blog (francés)</a> -
<a href="http://world.openfoodfacts.org/press-and-blogs">Prensa, blogs y presentaciones (inglés)</a>
HTML
,

	pt => <<HTML
<a href="http://world.openfoodfacts.org/legal">Legal</a> - 
<a href="http://world.openfoodfacts.org/terms-of-use">Termos de utilização</a> -
<a href="http://world.openfoodfacts.org/who-we-are">Quem somos</a> -
<a href="http://world.openfoodfacts.org/faq">FAQ</a> -
<a href="https://openfoodfacts.uservoice.com/">Fórum de ideias</a> -
<a href="http://en.blog.openfoodfacts.org">Blog</a> -
<a href="http://pt.openfoodfacts.org/imprensa-e-blogs">Imprensa e blogs</a>
HTML
,
	he => <<HTML
<a href="http://world.openfoodfacts.org/legal">מידע משפטי</a> - 
<a href="http://world.openfoodfacts.org/terms-of-use">תנאי השימוש</a> -
<a href="http://world.openfoodfacts.org/who-we-are">מי אנחנו</a> -
<a href="http://world.openfoodfacts.org/faq">שאלות נפוצות</a> -
<a href="https://openfoodfacts.uservoice.com/">פורום הרעיונות</a> -
<a href="http://en.blog.openfoodfacts.org">בלוג</a> -
<a href="http://world.openfoodfacts.org/press-and-blogs">עתונות ובלוגים</a>
HTML
,

},



app_please_take_pictures => {
	fr => <<HTML
<p>Ce produit n'est pas encore dans la base d'Open Food Facts. Pourriez-vous s'il vous plait prendre des photos
du produit, du code barre, de la liste des ingrédients et du tableau nutritionnel pour qu'il soit ajouté sur <a href="http://fr.openfoodfacts.org" target="_blank">Open Food Facts</a> ?</p>
<p>Merci d'avance !</p> 
HTML
,
	en => <<HTML
<p>This product is not yet in the Open Food Facts database. Could you please take some pictures of the product, barcode, ingredients list and nutrition facts to add it on <a href="http://world.openfoodfacts.org" target="_blank">Open Food Facts</a>?</p>
<p>Thanks in advance!</p>   
HTML
,
	es => <<HTML
<p>Este producto aún no está en la base de datos de Open Food Facts. ¿Podrías tomar algunas fotos del producto, su código de barras, ingredientes e información nutricional para agregarlo a <a href="http://es.openfoodfacts.org" target="_blank">Open Food Facts</a>?</p>
<p>¡Gracias desde ya!</p>   
HTML
,
	pt => <<HTML
<p>Este produto não se encontra ainda na base de dados do Open Food Facts. Será possível tirares fotografias do produtos, código de barras, ingredientes e informação nutricional para juntar ao <a href="http://pt.openfoodfacts.org" target="_blank">Open Food Facts</a>?</p>
<p>Desde já muito obrigado!</p>   
HTML
,
	de => <<HTML
<p>Dieses Produkt existiert noch nicht in der Open Food Facts Datenbank. Können Sie bitte Fotos des Produktes, des Strichcodes, der Zutatenliste und der Nährwertsangaben machen, damit es zu <a href="http://fr.openfoodfacts.org" target="_blank">Open Food Facts</a> hinzugefügt werden kann?</p>
<p>Danke vielmals im Voraus!</p>    
HTML
,
	it => <<HTML
<p>Questo prodotto non é ancora nel database di OFF. Puoi per favore fare una foto del prodotto, del codice a barre, della lista degli ingredienti e della tabella nutrizionale perché possa essere aggiunta su <a href="http://it.openfoodfacts.org" target="_blank">Open Food Facts</a>.</p>
<p>Grazie anticipatamente.</p>
HTML
,
	he => <<HTML
<p>מוצר זה לא נמצא עדיין במסד הנתונים של Open Food Facts. האם יתאפשר לך לצלם מספר תמונות של המוצר, הברקוד, רשימת הרכיבים והמפרט התזונתי כדי להוסיף אותם ל־<a href="http://il.openfoodfacts.org" target="_blank">Open Food Facts</a>?</p>
<p>תודה מראש!</p>   
HTML
,
},


);


1;