#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
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
use ProductOpener::Lang qw/:all/;
use ProductOpener::Data qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use File::Path qw(mkpath);
use JSON::PP;

# Output will be in the $BASE_DIRS{PRIVATE_DATA} directory
# data/index: data related to the Open Food Hunt operation (old): points for countries, users and ambassadors
# data/categories_stats: statistics for the nutrients of categories, used to compare products to their categories

ensure_dir_created_or_die("$BASE_DIRS{PRIVATE_DATA}/index");
ensure_dir_created_or_die("$BASE_DIRS{PRIVATE_DATA}/categories_stats");

# Generate a list of the top brands, categories, users, additives etc.

my @fields = qw (
	brands
	categories
	packaging
	origins
	manufacturing_places
	ingredients
	labels
	nutriments
	allergens
	traces
	users
	photographers
	informers
	correctors
	checkers
	additives
	allergens
	emb_codes
	cities
	purchase_places
	stores
	countries
	ingredients_from_palm_oil
	ingredients_that_may_be_from_palm_oil
	states
	unknown_nutrients
	pnns_groups_2
	pnns_groups_1
	entry_dates
);

# also generate stats for categories

my %countries = ();
my $total = 0;

my @dates = ('created_t', 'completed_t');
# country => $date_name.start => first date for this country
# country => $date_name.end => last date for this country
# country => $date_name => day (as timestamp) => number of cumulated products at this date
my %countries_dates = ();
my %products = ();

#foreach my $l (values %lang_lc) {

my $l = 'en';
$lc = $l;
# country => date_type (see @dates) => day (as timestamp) => number of products at this date
# will help us compute countries_dates
my %dates = ();

my $fields_ref = {code => 1};
my %tags = ();
# $country => $tag_type / "$tagtype"
# also $country => $tag_type_nutriments / "$tagtype"
my %countries_tags = ();
# hashmap of all seen codes
my %codes = ();
# for each country associate the minimun and maximum found dates (either completed_t or created_t)
# we start with 0 and 100000000000000000
my %true_end = ();    # 0;
my %true_start = ();    # 100000000000000000;
my $complete = 0;

# Add in $fields_ref all the fields we need to retrieve from MongoDB
# simple tags
foreach my $tagtype (@fields) {
	$fields_ref->{$tagtype . "_tags"} = 1;
}
# initialize country structures
foreach my $country (keys %{$properties{countries}}, 'en:world') {
	$countries_tags{$country} = {};
	foreach my $tagtype (@fields) {
		$countries_tags{$country}{$tagtype} = {};
		$countries_tags{$country}{$tagtype . "_nutriments"} = {};
	}
	$dates{$country} = {};
	$countries_dates{$country} = {};
	foreach my $date (@dates) {
		$dates{$country}{$date} = {};
		$countries_dates{$country}{$date} = {};
	}

	$true_end{$country} = 0;
	$true_start{$country} = 100000000000000000;
}
# we don't need users tags
delete $fields_ref->{users_tags};
# more fields to get
$fields_ref->{creator} = 1;
$fields_ref->{nutriments} = 1;
$fields_ref->{created_t} = 1;
$fields_ref->{complete} = 1;
$fields_ref->{completed_t} = 1;

$fields_ref->{nutriments} = 1;
$fields_ref->{nutrition_grade_fr} = 1;
$fields_ref->{ecoscore_extended_data} = 1;

# Sort by created_t so that we can see which product was the nth in each country -> necessary to compute points for Open Food Hunt
# do not include empty products and products that have been marked as obsolete

# 300 000 ms timeout so that we can export the whole database
# 5mins is not enough, 50k docs were exported
my $cursor = get_products_collection({timeout => 3 * 60 * 60 * 1000})
	->query({'empty' => {"\$ne" => 1}, 'obsolete' => {"\$ne" => 1}})->sort({created_t => 1})->fields($fields_ref);

$cursor->immortal(1);

my %products_nutriments = ();
my %countries_categories = ();

my %countries_counts = ();
my %countries_points = ();
my %users_points = ();

# filter on created_t
my $start_t = 1424476800 - 12 * 3600;
my $end_t = 1424476800 - 12 * 3600 + 10 * 86400;

# points by country?
# points by user?

my %nutrition_grades_to_n = (
	a => 1,
	b => 2,
	c => 3,
	d => 4,
	e => 5,
);

# Go through all products
while (my $product_ref = $cursor->next) {
	$total++;

	my $code = $product_ref->{code};
	if (not defined $codes{$code}) {
		$codes{$code} = 1;
	}
	else {
		$codes{$code} += 1;
		#print STDERR "code $code seen $codes{$code} times!\n";
	}

	# Populate $products_nutriments{$code} with values for fields that we are going to compute stats on

	# Products with nutriments
	if (
			(defined $code)
		and (defined $product_ref->{nutriments})
		and (  ((defined $product_ref->{nutriments}{alcohol}) and ($product_ref->{nutriments}{alcohol} ne ''))
			or ((defined $product_ref->{nutriments}{energy}) and ($product_ref->{nutriments}{energy} ne '')))
		)
	{

		$products_nutriments{$code} = {};
		foreach my $nid (keys %{$product_ref->{nutriments}}) {
			next if $nid =~ /_/;
			next if ($product_ref->{nutriments}{$nid} eq '');

			$products_nutriments{$code}{$nid} = $product_ref->{nutriments}{$nid . "_100g"};
		}
		if (defined $product_ref->{"nutrition_grade_fr"}) {
			$products_nutriments{$code}{"nutrition-grade"}
				= $nutrition_grades_to_n{$product_ref->{"nutrition_grade_fr"}};
			#print "NUT - nid: nutrition_grade_fr : $product_ref->{nutrition_grade_fr} \n";
		}
	}

	# Add environmental impact from impact estimator if we have them
	if (
			(defined $product_ref->{ecoscore_extended_data})
		and (defined $product_ref->{ecoscore_extended_data}{impact})
		and (defined $product_ref->{ecoscore_extended_data}{impact}{likeliest_impacts})
		# TODO: Need to add a filter to keep only impacts computed with high confidence
		)
	{
		defined $products_nutriments{$code} or $products_nutriments{$code} = {};
		$products_nutriments{$code}{climate_change}
			= $product_ref->{ecoscore_extended_data}{impact}{likeliest_impacts}{Climate_change};
		$products_nutriments{$code}{ef_score}
			= $product_ref->{ecoscore_extended_data}{impact}{likeliest_impacts}{EF_single_score};
	}

	# Compute points

	my $creator = $product_ref->{creator};

	if ((defined $creator) and ($creator ne '')) {

		if (defined $product_ref->{countries_tags}) {

			foreach my $country (@{$product_ref->{countries_tags}}) {

				next if not exists_taxonomy_tag("countries", $country);

				defined $countries_counts{$country} or $countries_counts{$country} = 0;
				$countries_counts{$country}++;

				next
					if ((not exists $product_ref->{created_t})
					or ($product_ref->{created_t} < $start_t)
					or ($product_ref->{created_t} > $end_t));
				next if ($creator eq 'date-limite-app');
				next if ($creator eq 'tacite');

				my $points = 1;
				if ($product_ref->{complete}) {
					$points = 2;
				}

				# first products added to one country give more points

				my $n = $countries_counts{$country};
				if ($n == 1) {
					$points *= 100;
				}
				elsif ($n <= 10) {
					$points *= 20;
				}
				elsif ($n <= 100) {
					$points *= 10;
				}
				elsif ($n <= 1000) {
					$points *= 5;
				}
				elsif ($n <= 10000) {
					$points *= 2;
				}

				# count points by country

				defined $countries_points{$country} or $countries_points{$country} = {};
				defined $countries_points{$country}{$creator} or $countries_points{$country}{$creator} = 0;

				defined $countries_points{_all_} or $countries_points{_all_} = {};
				defined $countries_points{_all_}{$creator} or $countries_points{_all_}{$creator} = 0;

				#defined $countries_points{$country}{_all_} or $countries_points{$country}{_all_} = 0;

				#$countries_points{$country}{_all_} += $points;
				$countries_points{$country}{$creator} += $points;
				$countries_points{_all_}{$creator} += $points;

				# count points by user

				defined $users_points{$creator} or $users_points{$creator} = {};
				defined $users_points{$creator}{$country} or $users_points{$creator}{$country} = 0;

				defined $users_points{_all_} or $users_points{$creator} = {};
				defined $users_points{_all_}{$country} or $users_points{$creator}{$country} = 0;

				#defined $users_points{$creator}{_all_} or $users_points{$creator}{_all_} = 0;

				#$users_points{$creator}{_all_} += $points;
				$users_points{$creator}{$country} += $points;
				$users_points{_all_}{$country} += $points;

			}
		}

	}

	foreach my $tagtype (@fields) {

		$tags{$tagtype} = {};
		$tags{$tagtype . "_nutriments"} = {};

		if ($tagtype eq 'users') {
			$tags{$tagtype}{$product_ref->{creator}}++;
		}
		elsif (defined $product_ref->{$tagtype . "_tags"}) {
			foreach my $tagid (@{$product_ref->{$tagtype . "_tags"}}) {
				$tags{$tagtype}{$tagid}++;

				if ($tagtype eq 'ingredients') {
					#print STDERR "code: $code - ingredient: $tagid \n";
				}

				# nutriment info?
				next if (not defined $product_ref->{nutriments});
				next if (not defined $product_ref->{nutriments}{energy});
				next if (not defined $product_ref->{nutriments}{proteins});
				next if (not defined $product_ref->{nutriments}{carbohydrates});
				next if (not defined $product_ref->{nutriments}{fat});
				$tags{$tagtype . "_nutriments"}{$tagid}++;

			}
		}

		foreach my $country (@{$product_ref->{countries_tags}}, 'en:world') {

			foreach my $tagid (keys %{$tags{$tagtype}}) {
				$countries_tags{$country}{$tagtype}{$tagid} += $tags{$tagtype}{$tagid};

				if ($tagtype eq 'categories') {
					defined $countries_categories{$country} or $countries_categories{$country} = {};
					defined $countries_categories{$country}{$tagid} or $countries_categories{$country}{$tagid} = {};
					$countries_categories{$country}{$tagid}{$code} = 1;
				}
			}
			foreach my $tagid (keys %{$tags{$tagtype . "_nutriments"}}) {
				$countries_tags{$country}{$tagtype . "_nutriments"}{$tagid} += $tags{$tagtype . "_nutriments"}{$tagid};
			}
		}
	}

	# for each country listed in the product
	foreach my $country (@{$product_ref->{countries_tags}}, 'en:world') {

		# don't process invalid countries - 'en:frankreich-deutschland', 'fr:francja', 'de:autriche', etc.
		next if (!defined($properties{countries}{$country}));

		$countries{$country}++;

		foreach my $date (@dates) {
			# print "dates products $lc $date : " . $product_ref->{$date} . "\n";
			if ((defined $product_ref->{$date}) and ($product_ref->{$date} > 0)) {
				$dates{$country}{$date}{int($product_ref->{$date} / 86400)}++;
				if ($product_ref->{$date} / 86400 > $true_end{$country}) {
					$true_end{$country} = int($product_ref->{$date} / 86400);
				}
				if ($product_ref->{$date} / 86400 < $true_start{$country}) {
					$true_start{$country} = int($product_ref->{$date} / 86400);
				}
			}
		}
		$products{$country}++;
	}

	if (    ($product_ref->{complete} > 0)
		and ((not defined $product_ref->{completed_t}) or ($product_ref->{completed_t} <= 0)))
	{
		#print "product $code - complete: $product_ref->{complete} , completed_t: $product_ref->{completed_t}\n";
	}
	elsif ((defined $product_ref->{completed_t}) and ($product_ref->{completed_t} > 0)) {
		$complete++;
		if ($complete % 10 == 0) {
			print "completed products: $complete\n";
		}
	}

}

# compute points
# Read ambassadors.txt
my %ambassadors = ();
if (open(my $IN, q{<}, "$BASE_DIRS{PRIVATE_DATA}/ambassadors.txt")) {
	while (<$IN>) {
		chomp();
		if (/\s+/) {
			my $user = get_string_id_for_lang("no_language", $`);
			my $ambassador = get_string_id_for_lang("no_language", $');
			$ambassadors{$user} = $ambassador;
		}
	}
}
else {
	print STDERR "$BASE_DIRS{PRIVATE_DATA}/ambassadors.txt does not exist\n";
}

my %ambassadors_countries_points = (_all_ => {});
my %ambassadors_users_points = (_all_ => {});

foreach my $country (keys %countries_points) {
	defined $ambassadors_countries_points{$country} or $ambassadors_countries_points{$country} = {};
	foreach my $user (keys %{$countries_points{$country}}) {
		next if $user eq 'all_users';
		if (exists $ambassadors{$user}) {
			my $ambassador = $ambassadors{$user};
			defined $ambassadors_countries_points{$country}{$ambassador}
				or $ambassadors_countries_points{$country}{$ambassador} = 0;
			defined $ambassadors_countries_points{_all_}{$ambassador}
				or $ambassadors_countries_points{_all_}{$ambassador} = 0;
			$ambassadors_countries_points{$country}{$ambassador} += $countries_points{$country}{$user};
			$ambassadors_countries_points{_all_}{$ambassador} += $countries_points{$country}{$user};

			defined $ambassadors_users_points{$ambassador} or $ambassadors_users_points{$ambassador} = {};
			defined $ambassadors_users_points{$ambassador}{$country}
				or $ambassadors_users_points{$ambassador}{$country} = 0;
			defined $ambassadors_users_points{_all_}{$country} or $ambassadors_users_points{_all_}{$country} = 0;
			#$ambassadors_users_points{$ambassador}{_all_} += $countries_points{$country}{$user};
			$ambassadors_users_points{$ambassador}{$country} += $users_points{$user}{$country};
			$ambassadors_users_points{_all_}{$country} += $users_points{$user}{$country};
		}
	}
}

store("$BASE_DIRS{PRIVATE_DATA}/index/countries_points.sto", \%countries_points);
store("$BASE_DIRS{PRIVATE_DATA}/index/users_points.sto", \%users_points);

store("$BASE_DIRS{PRIVATE_DATA}/index/ambassadors_countries_points.sto", \%ambassadors_countries_points);
store("$BASE_DIRS{PRIVATE_DATA}/index/ambassadors_users_points.sto", \%ambassadors_users_points);

foreach my $country (keys %{$properties{countries}}) {

	# Do not generate stats for countries without 2 letter country codes
	next if not defined $properties{countries}{$country}{"country_code_2:en"};

	my $cc = lc($properties{countries}{$country}{"country_code_2:en"});

	# Category stats for nutriments

	my $min_products = 10;
	my %categories = ();

	foreach my $tagid (keys %{$countries_categories{$country}}) {

		# Compute mean, standard deviation etc.

		my $count = 0;
		my $n = 0;
		my %nutriments = ();

		foreach my $code (keys %{$countries_categories{$country}{$tagid}}) {

			$count++;

			next if (not defined $products_nutriments{$code});

			$n++;

			foreach my $nid (keys %{$products_nutriments{$code}}) {

				if ($nid eq 'nutrition-grade') {
					#print "NUT - code: $code - nid: nutrition-grade\n";
				}
				add_product_nutriment_to_stats(\%nutriments, $nid, $products_nutriments{$code}{$nid});
			}
		}

		if ($n >= $min_products) {

			$categories{$tagid} = {};
			compute_stats_for_products($categories{$tagid}, \%nutriments, $count, $n, $min_products, $tagid);

		}
	}

	store("$BASE_DIRS{PRIVATE_DATA}/categories_stats/categories_nutriments_per_country.$cc.sto", \%categories);

	# Dates

	foreach my $date (@dates) {
		my @sorted_dates
			= sort ({$dates{$country}{$date}{$a} <=> $dates{$country}{$date}{$b}} keys %{$dates{$country}{$date}});
		my $start = $sorted_dates[0];
		my $end = $sorted_dates[-1];

		# somehow we don't get the biggest day...
		if (!defined($end) || $true_end{$country} > $end) {
			$end = $true_end{$country};
		}
		if (!defined($start) || $true_start{$country} < $start) {
			$start = $true_start{$country};
		}

		$countries_dates{$country}{$date . ".start"} = $start;
		$countries_dates{$country}{$date . ".end"} = $end;

		#print "dates_stats_$country countryid: $country - date: $date - start: $start - end: $end\n";

		my $current = 0;    # count products
		for (my $i = $start; $i <= $end; $i++) {
			$current += ($dates{$country}{$date}{$i} // 0);
			$countries_dates{$country}{$date}{$i} = $current;
			#print "dates_current_$cc lc: $cc - date: $date - start: $start - end: $end - i: $i - $current\n";
		}
	}
}

# # Open Food Facts - What's in my yogurt? - disabled
# if ($server_domain eq 'openfoodfacts.org') {
# 	print "Starting yogurts_countries.html...\n";

# 	open(my $DEBUG, ">:encoding(UTF-8)", "/home/yogurt/html/yogurts_debug");

# 	my $html = "";
# 	my $c = 0;
# 	foreach my $country (
# 		sort {
# 			($countries_tags{$b}{categories}{"en:yogurts"} // 0)
# 				<=> ($countries_tags{$a}{categories}{"en:yogurts"} // 0)
# 		} keys %countries
# 		)
# 	{

# 		print $DEBUG "yogurts - $country - "
# 			. ($countries_tags{$country}{categories}{"en:yogurts"} // 'undefined') . "\n";
# 		print STDERR "yogurts - $country - "
# 			. ($countries_tags{$country}{categories}{"en:yogurts"} // 'undefined') . "\n";
# 		if (($countries_tags{$country}{categories}{"en:yogurts"} // 0) > 0) {
# 			my $cc = lc($properties{countries}{$country}{"country_code_2:en"});
# 			if ($country eq 'en:world') {
# 				$cc = 'world';
# 			}
# 			$lc = $country_languages{$cc}[0];    # first official language

# 			if (not exists $Langs{$lc}) {
# 				$lc = 'en';
# 			}

# 			print $DEBUG "yogurts - cc: $cc - lc: $lc \n";

# 			$cc ne '' or next;
# 			$c++;

# 			my $n = $countries_tags{$country}{categories}{"en:yogurts"};
# 			$n =~ s/(\d)(?=(\d{3})+$)/$1/g;
# 			my $link
# 				= "<a href=\"https://$cc.$server_domain"
# 				. canonicalize_taxonomy_tag_link($lc, "categories", "en:yogurts") . "\">"
# 				. display_taxonomy_tag('en', 'countries', $country) . "</a>";

# 			$html .= "<li>$link - " . $countries_tags{$country}{categories}{"en:yogurts"} . " yogurts</li>\n";
# 		}

# 	}
# 	$html =~ s/ 1 yogurts/ 1 yogurt/g;

# 	my $yogurts = $countries_tags{"en:world"}{categories}{"en:yogurts"};

# 	$html
# 		= "<h2 style=\"color:white\">$yogurts yogurts opened so far!</h2>\n<p>$yogurts yogurts sold in $c countries and territories:</p>\n<ul>\n$html</ul>\n";

# 	open(my $OUT, ">:encoding(UTF-8)", "/home/yogurt/html/yogurts_countries.html");
# 	print $OUT $html;
# 	close $OUT;

# 	close $DEBUG;

# }

# Open Beauty Facts - What's in my shampoo?

# if ($server_domain eq 'openbeautyfacts.org') {
# 	print "Starting shampoos_countries.html...\n";

# 	open(my $DEBUG, ">:encoding(UTF-8)", "/home/shampoo/html/shampoos_debug");

# 	my $html = "";
# 	my $c = 0;
# 	foreach my $country (
# 		sort {
# 			($countries_tags{$b}{categories}{"en:shampoos"} // 0)
# 				<=> ($countries_tags{$a}{categories}{"en:shampoos"} // 0)
# 		} keys %countries
# 		)
# 	{

# 		print $DEBUG "shampoos - $country - "
# 			. ($countries_tags{$country}{categories}{"en:shampoos"} // 'undefined') . "\n";
# 		print STDERR "shampoos - $country - "
# 			. ($countries_tags{$country}{categories}{"en:shampoos"} // 'undefined') . "\n";
# 		if (($countries_tags{$country}{categories}{"en:shampoos"} // 0) > 0) {
# 			my $cc = lc($properties{countries}{$country}{"country_code_2:en"});
# 			if ($country eq 'en:world') {
# 				$cc = 'world';
# 			}
# 			$lc = $country_languages{$cc}[0];    # first official language

# 			if (not exists $Langs{$lc}) {
# 				$lc = 'en';
# 			}

# 			print $DEBUG "shampoos - cc: $cc - lc: $lc \n";

# 			$cc ne '' or next;
# 			$c++;

# 			my $n = $countries_tags{$country}{categories}{"en:shampoos"};
# 			$n =~ s/(\d)(?=(\d{3})+$)/$1/g;
# 			my $link
# 				= "<a href=\"https://$cc.$server_domain"
# 				. canonicalize_taxonomy_tag_link($lc, "categories", "en:shampoos") . "\">"
# 				. display_taxonomy_tag('en', 'countries', $country) . "</a>";

# 			$html .= "<li>$link - " . $countries_tags{$country}{categories}{"en:shampoos"} . " shampoos</li>\n";
# 		}

# 	}
# 	$html =~ s/ 1 shampoos/ 1 shampoo/g;

# 	my $shampoos = $countries_tags{"en:world"}{categories}{"en:shampoos"};

# 	$html
# 		= "<h2 style=\"color:white\">$shampoos shampoos opened so far!</h2>\n<p>$shampoos shampoos sold in $c countries and territories:</p>\n<ul>\n$html</ul>\n";

# 	open(my $OUT, ">:encoding(UTF-8)", "/home/shampoo/html/shampoos_countries.html");
# 	print $OUT $html;
# 	close $OUT;

# 	close $DEBUG;

# }

# Number of products and complete products

print "Starting products_stats_??.html...\n";
foreach my $country (sort {$countries{$b} <=> $countries{$a}} keys %countries) {

	if (!defined($properties{countries}{$country}{"country_code_2:en"})) {
		print "No country_code_2 found for $country\n";
		next;
	}

	my $cc = lc($properties{countries}{$country}{"country_code_2:en"});
	if ($country eq 'en:world') {
		$cc = 'world';
	}

	my $meta = '';
	if (-e "$www_root/images/misc/products_graph_country_$cc.png") {
		$meta = <<HTML
<meta property="og:image" content="https://$lc.$server_domain/images/misc/products_graph_country_$cc.png"/>
HTML
			;
		print "found meta products_graph_country_$cc.png image\n";
	}

	my @languages = (@{$country_languages{$cc}});
	if ($cc eq "world") {
		# all languages
		@languages = keys %Langs;
	}
	# also always add english
	push @languages, "en" unless grep {$_ eq 'en'} @languages;
	foreach my $lc (@languages) {

		$lang = $lc;

		my $series = '';

		my $end = 0;
		my $start = 100000000000;

		foreach my $date (@dates) {
			if ($countries_dates{$country}{$date . ".start"} < $start) {
				$start = $countries_dates{$country}{$date . ".start"};
			}
			if ($countries_dates{$country}{$date . ".end"} > $end) {
				$end = $countries_dates{$country}{$date . ".end"};
			}
		}

		foreach my $date (@dates) {

			my $series_start = $countries_dates{$country}{$date . ".start"};
			my $series_end = $countries_dates{$country}{$date . ".end"};

			my $name = $Lang{"products_stats_$date"}{$lang};
			my $series_point_start = $series_start * 86400 * 1000;
			$series .= <<HTML
{
	name: '$name',
	pointInterval: 24 * 3600 * 1000,
	pointStart: $series_point_start,
	data: [
HTML
				;

			my $current = 0;
			my $i = 0;
			for (my $t = $series_start; $t < $end; $t++) {
				if (defined $countries_dates{$country}{$date}{$t}) {
					$current = $countries_dates{$country}{$date}{$t};
				}
				#$series .= $current . ', ';
				$i++;
				if ($i % 10 == 0) {
					#$series =~ s/ $/\n/;
					$series .= $current . ",\n";
				}
				else {
					$series .= $current . ', ';
				}
			}
			$series =~ s/,\n?$//;
			$series .= "\n]\n},\n";
		}

		$series =~ s/,\n$//;

		my $country_name = display_taxonomy_tag($lang, 'countries', $country);

		#$Lang{products_p}{$lang} is undefined, products_p doesn't appear to be in the .po files.
		my $html = <<HTML
<initjs>

Highcharts.setOptions({
	lang: {
		months: $Lang{months}{$lang},
		weekdays: $Lang{weekdays}{$lang}
	}
});

        \$('#container').highcharts({
            chart: {
                type: 'area'
            },
            title: {
                text: '$Lang{products_stats}{$lang} - $country_name'
            },
            subtitle: {
                text: 'Source: <a href="https://$cc.$server_domain">'+
                    '$cc.$server_domain</a>'
            },
            xAxis: {
                type: 'datetime',
            },
            yAxis: {
                title: {
                    text: '$Lang{products}{$lang}'
                },
                labels: {
                    formatter: function() {
                        return this.value;
                    }
                }
            },
            tooltip: {
                shared: true
            },
            plotOptions: {
                area: {
                    //pointStart: 1940,
                    marker: {
                        enabled: false,
                        symbol: 'circle',
                        radius: 2,
                        states: {
                            hover: {
                                enabled: true
                            }
                        }
                    }
                }
            },
            series: [
$series
            ]
        });

</initjs>

<scripts>
<script src="$static_subdomain/js/dist/highcharts.js"></script></scripts>
<header>
$meta
</header>

<div id="container" style="height: 400px"></div>

HTML
			;

		my $stats_dir = "$BASE_DIRS{PUBLIC_DATA}/products_stats/$lang";
		print "products_stats - saving $stats_dir/products_stats_$cc.html\n";
		ensure_dir_created_or_die($stats_dir);
		if (open(my $OUT, ">:encoding(UTF-8)", "$stats_dir/products_stats_$cc.html")) {
			print $OUT $html;
			close $OUT;
		}
		else {
			print STDERR "Failed to write to '$stats_dir/products_stats_$cc.html'\n";
		}
	}
}

# All languages

# Number of products and complete products

print "Starting products_countries.js...\n";

my $date = "created_t";

my $series = '';

my $end = 0;
my $start = 100000000000;

foreach my $country (sort {$countries{$b} <=> $countries{$a}} keys %countries) {

	if ($countries_dates{$country}{$date . ".start"} < $start) {
		$start = $countries_dates{$country}{$date . ".start"};
	}
	if ($countries_dates{$country}{$date . ".end"} > $end) {
		$end = $countries_dates{$country}{$date . ".end"};
	}
}

foreach my $country (
	sort {$countries_dates{$a}{$date . ".start"} <=> $countries_dates{$b}{$date . ".start"}}
	keys %countries
	)
{

	$lang = $lc;

	my $series_start = $countries_dates{$country}{$date . ".start"};
	my $series_end = $countries_dates{$country}{$date . ".end"};

	next if $series_start < 100;

	my $name = $Langs{$lc};
	my $series_point_start = $series_start * 86400 * 1000;
	$series .= <<HTML
{
	name: '$name',
	pointInterval: 24 * 3600 * 1000,
	pointStart: $series_point_start,
	data: [
HTML
		;

	my $current = 0;
	my $i = 0;
	for (my $t = $series_start; $t < $end; $t++) {
		if (defined $countries_dates{$country}{$date}{$t}) {
			$current = $countries_dates{$country}{$date}{$t};
		}
		#$series .= $current . ', ';
		$i++;
		if ($i % 10 == 0) {
			#$series =~ s/ $/\n/;
			$series .= $current . ",\n";
		}
		else {
			$series .= $current . ', ';
		}
	}
	$series =~ s/,\n?$//;
	$series .= "\n]\n},\n";
}

$series =~ s/,\n$//;

$lang = 'en';
$lc = 'en';

my $html = <<HTML


        \$('#container').highcharts({
            chart: {
                type: 'area'
            },
            title: {
                text: '$Lang{products_stats}{$lang}'
            },
            subtitle: {
                text: 'Source: <a href="https://$server_domain">'+
                    '$server_domain</a>'
            },
            tooltip: {
                shared: true
            },
            xAxis: {
                type: 'datetime',
            },
            yAxis: {
                title: {
                    text: '$Lang{products}{$lang}'
                },
                labels: {
                    formatter: function() {
                        return this.value;
                    }
                }
            },
            plotOptions: {
                area: {
                    stacking: 'normal',
                    marker: {
                        enabled: false,
                        symbol: 'circle',
                        radius: 2,
                        states: {
                            hover: {
                                enabled: true
                            }
                        }
                    }
                }
            },
            series: [
$series
            ]
        });


HTML
	;
my $stats_dir = "$BASE_DIRS{PUBLIC_DATA}/products_stats/";
ensure_dir_created_or_die($stats_dir);
open(my $OUT, ">:encoding(UTF-8)", "$stats_dir/products_countries.js");
print $OUT $html;
close $OUT;

exit(0);

