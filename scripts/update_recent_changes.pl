#!/usr/bin/perl

use Modern::Perl '2012';
use utf8;

my $usage = <<TXT
update_recent_changes.pl is a script that updates the changes collection in MongoDB using the changes.sto file.
TXT
;

use CGI::Carp qw(fatalsToBrowser);

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
use ProductOpener::SiteQuality qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use boolean; # imports 'true' and 'false'

# Get a list of all products not yet updated

my $query_ref = {};
my $sort_ref = { last_modified_t => 1 };
my $cursor = get_products_collection()->query($query_ref)->sort($sort_ref)->fields({ code => 1, countries_tags => 2 });
my $count = get_products_collection()->count($query_ref);

my $n = 0;
	
print STDERR "$count products to update\n";

$recent_changes_collection->drop;

my $cmd = [
	create => 'recent_changes',
	capped => true,
	size   => 104857600
];

$database->run_command($cmd);
$recent_changes_collection = $database->get_collection('recent_changes');

while (my $product_ref = $cursor->next) {
	
	my $code = $product_ref->{code};
	my $path = product_path($code);
	
	my $changes_path = "$data_root/products/$path/changes.sto";
	print STDERR "updating product $code from $changes_path\n";
	
	my $changes_ref = retrieve($changes_path);
	if (not defined $changes_ref) {
		$changes_ref = [];
	}

	foreach my $change_ref (@$changes_ref) {
		log_change($product_ref, $change_ref);
	}

	$n++;
}
			
print "$n products updated\n";
			
exit(0);

