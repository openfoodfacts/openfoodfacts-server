#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Text::Fuzzy;

my @list1 = (
"Crème Dessert Baba au Rhum Auchan x4",
"Crème Dessert Speculoos Auchan x4",
"Crème Dessert Chocolat Caramel Auchan x4",
"Crème Dessert Café Auchan x4",
"Crème Dessert Chocolat Blanc Auchan x4",
"Crème Dessert Pistache Auchan x4",
);

my @list2 = (
"CREME DESSERT baba au rhum 4X125G",
"CREM DESS CAFE 4X125G",
"CREME DESSERT spÃ©culoos 4X125G",
"CREME DESSERT chocolat caramel 4X125G",
"CREME DESSERT chocolat blanc 4X125G",
"CREME DESSERT PISTACHE 4X125G",
);


foreach my $w1 (@list1) {
	my $tf = Text::Fuzzy->new ($w1);
	my $nearest = $tf->nearestv (\@list2);
	print "Nearest array entry for $w1 is $nearest\n";
}


