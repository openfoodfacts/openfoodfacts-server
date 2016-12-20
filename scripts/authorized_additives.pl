#!/usr/bin/perl -w

use utf8;
use Modern::Perl '2012';

binmode STDIN, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';

my %europe = ();

my @levels = (

{
'e150'=>'',
'e470'=>'',
'e960' => 'Autorisé en Europe depuis le 2 décembre 2011',
'e441' => 'La gélatine est considérée en Europe comme un ingrédient et non un additif.',
'e428' => 'La gélatine est considérée en Europe comme un ingrédient et non un additif.',
},

{
'e120' => "Risque d'allergie.",
'e131'=>"Responsable d'allergies (urticaire) et soupçonné d'être cancérigène.<br/>
Interdit en Australie, au Canada, aux Etats-Unis et en Norvège.",
'e132'=>"Risque d'allergie. Interdit en Norvège.",
},

{

'e104'=>"Peut avoir un effet nuisible sur l’activité et l’attention des enfants.",
'e110'=>"Peut avoir un effet nuisible sur l’activité et l’attention des enfants.",
'e122'=>"Peut avoir un effet nuisible sur l’activité et l’attention des enfants.",
'e129'=>"Peut avoir un effet nuisible sur l’activité et l’attention des enfants.",
'e102'=>"Peut avoir un effet nuisible sur l’activité et l’attention des enfants.",
'e124'=>"Peut avoir un effet nuisible sur l’activité et l’attention des enfants.",

},

);

open(my $IN, "<:encoding(UTF-8)", "europe_2011.txt");
while (<$IN>) {
	chomp;
	if ($_ =~ /E (\w+)/) {
		my $id = 'E' . $1;
		$europe{lc($id)} = 1;
	}
}
close ($IN);

open($IN, "<:encoding(UTF-8)", "additives_source.txt");
while (<$IN>) {
	chomp;
	my ($canon_name, $other_names, $misc, $desc, $level, $warning) = split("\t");
	$level = -1;
	(defined $desc) or ($desc = '');
	(defined $warning) or ($warning = '');

	for (my $i = 0; $i <= $#levels; $i++) {
		if (defined $levels[$i]{lc($canon_name)}) {
			$level = $i;
			if ($level > 0) {
				$warning = $levels[$i]{lc($canon_name)};
			}
			else {
				$desc = $levels[$i]{lc($canon_name)};
			}
		}
	}
	
	if  (($level < 0) and (not defined $europe{lc($canon_name)})) {
		$level = 3;
		$warning = "Additif non autorisé en Europe (liste N° 1129/2011 du 11 Novembre 2011)";
	}
	
	print $canon_name . "\t" . $other_names . "\t" . $misc . "\t" . $desc . "\t" . $level . "\t" . $warning . "\n";
		
}
close ($IN);
	
