#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use File::Basename "dirname";

use ProductOpener::Producers qw(load_csv_or_excel_file);

my $inputs_dir = dirname(__FILE__) . "/inputs/load_csv_or_excel_file/";

# Ademe excel test
my $results_ref = load_csv_or_excel_file($inputs_dir . "eco-score-template.xlsx");
my @expected_headers = (
	"EAN",
	"Nom",
	"Marque",
	"Catégorie",
	"Boisson",
	"Label 1",
	"Label 2",
	"Ingrédient",
	"Origine",
	"Pourcentage",
	"Ingrédient - 2",
	"Origine - 2",
	"Pourcentage - 2",
	"Ingrédient - 3",
	"Origine - 3",
	"Pourcentage - 3",
	"Ingrédient - 4",
	"Origine - 4",
	"Pourcentage - 4",
	"Ingrédient - 5",
	"Origine - 5",
	"Pourcentage - 5",
	"Ingrédient - 6",
	"Origine - 6",
	"Pourcentage - 6",
	"Format",
	"Matériau",
	"Format - 2",
	"Matériau - 2",
	"Format - 3",
	"Matériau - 3",
	"Huile de palme",
	"Poissons menacés"
);

# we have headers
is_deeply($results_ref->{headers}, \@expected_headers,);
# we have 3 rows
my @rows = @{$results_ref->{rows}};
is(scalar @rows, 3);
foreach my $row (@rows) {
	# each row has as many columns as headers
	is(scalar @{$row}, scalar @{$results_ref->{headers}});
}
# EANs are ok
is($rows[0]->[0], "7622210449283");
is($rows[1]->[0], "3168930010906");
is($rows[2]->[0], "3263670011456");
# clean csv
unlink $inputs_dir . "eco-score-template.xlsx.csv";
done_testing();
