#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use File::Copy "copy";
use File::Basename "fileparse";
use File::Temp;

use ProductOpener::Config qw/:all/;

# copy jsonl file
my ($test_id, $test_dir) = fileparse(__FILE__, qr/\.[^.]+$/);
copy("$test_dir/inputs/$test_id/openfoodfacts-products.jsonl.gz", "$www_root/data/openfoodfacts-products.jsonl.gz")
	or die "Copy of jsonl failed: $!";
my $tmp_dir = File::Temp->newdir();
my $tmp_dirname = $tmp_dir->dirname();

my @tests = (
	{
		"testid" => "world",
		"args" => ["world", "en"],
		"matched_products" =>
			qr/3 products match the search criteria, of which 2 products have a known production place/,
		"geopoints" => ['"geo":[43.983333,2.983333]', '"geo":[50.383333,3.05]'],
	},
	{
		"testid" => "world",
		"args" => ["fr", "fr"],
		"matched_products" => qr/2 produits correspondent .+, dont 2 produits pour lesquels/,
		"geopoints" => ['"geo":[43.983333,2.983333]', '"geo":[50.383333,3.05]'],
	},
);

foreach my $test_ref (@tests) {
	# use a confined environment to tweak STDOUT and @ARGV
	my $testid = $test_ref->{testid};
	do {
		# redirect STDOUT to grab result
		local *STDOUT;
		# and tweak ARGV
		local @ARGV = @{$test_ref->{args}};
		open(STDOUT, '>', "$tmp_dirname/result.html");
		# launch script
		do "$www_root/../scripts/generate_madenearme_page.pl";
		close(STDOUT);
	};
	open(my $HTML, "<", "$tmp_dirname/result.html");
	read $HTML, my $html_content, -s $HTML;
	# we have a sentence about matched products
	like($html_content, $test_ref->{matched_products}, "$testid: found number of products");
	# get geopoints
	my @geopoints = ($html_content =~ m/"geo":\[\d+\.\d+,\d+\.\d+\]/g);
	# compare geopoints
	is_deeply(\@geopoints, $test_ref->{geopoints}, "$testid: geopoints");
}
done_testing();
1;
