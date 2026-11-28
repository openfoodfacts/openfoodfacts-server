#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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

# Validation of the Ecobalyse environmental cost (ECS) on a sample of products:
# reprocess products with the current code, call the Ecobalyse food2 API (with a disk cache),
# and compare the ECS per kg with the Agribalyse EF per kg of the category of each product.
# See README.md in this directory.

use ProductOpener::PerlStandards;
use utf8;
use Getopt::Long;
use JSON::PP;
use Digest::SHA qw/sha1_hex/;
use Encode qw/decode_utf8/;
use List::Util qw/sum/;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

my $usage = <<TXT;
Usage:

  Reprocess products and compute their environmental cost (run in the backend container):
    $0 --codes codes.txt --products products.jsonl --output results.jsonl
       [--cache-dir dir] [--compare previous_results.jsonl]

  Summary of existing results (no reprocessing, no Product Opener modules needed):
    $0 --summary results.jsonl [--compare previous_results.jsonl]

  --codes      product codes to validate, one per line
  --products   JSONL file with the products (e.g. a MongoDB export), lines that are not in --codes are skipped
  --output     JSONL file with one line of results per product (also used as input of --compare)
  --cache-dir  directory where the Ecobalyse API responses are cached, keyed by a hash of the request
               (default: ecobalyse_api_cache next to the --output file)
  --compare    previous results file: shows the before / after
  --top        number of outliers and changes to list (default 20)

The Ecobalyse API is called only if ECOBALYSE_API_TOKEN is set in the environment.
Without it, the results contain the coverage and skip reasons, but no ECS.
TXT

my ($codes_file, $products_file, $output_file, $cache_dir, $compare_file, $summary_file);
my $top = 20;
GetOptions(
	'codes=s' => \$codes_file,
	'products=s' => \$products_file,
	'output=s' => \$output_file,
	'cache-dir=s' => \$cache_dir,
	'compare=s' => \$compare_file,
	'summary=s' => \$summary_file,
	'top=i' => \$top,
) or die $usage;

my $json = JSON::PP->new->utf8->canonical;

if (defined $summary_file) {
	print_report(read_results($summary_file), $compare_file);
	exit 0;
}

die $usage unless defined $codes_file and defined $products_file and defined $output_file;

# Product Opener modules are only needed for reprocessing
require ProductOpener::Config;
require ProductOpener::Products;
require ProductOpener::API;
require ProductOpener::LoadData;
require ProductOpener::EnvironmentalImpact;
require Log::Any::Adapter;
Log::Any::Adapter->set('Stderr', log_level => 'warn');

# Do not call the Ecobalyse API while the product is analyzed (it is called below, with a cache)
{
	no warnings 'once';
	$ProductOpener::Config::options{ecobalyse_call_api_on_product_update} = 0;
}

ProductOpener::LoadData::load_data();

my $api_token = $ENV{ECOBALYSE_API_TOKEN};
my $call_api = (defined $api_token and $api_token ne '') ? 1 : 0;
print STDERR "ECOBALYSE_API_TOKEN not set: the Ecobalyse API will not be called\n" if not $call_api;

if (not defined $cache_dir) {
	$cache_dir = ($output_file =~ s/[^\/]*$//r) . "ecobalyse_api_cache";
	$cache_dir = "./ecobalyse_api_cache" if $cache_dir eq "ecobalyse_api_cache";
}
if ($call_api and not -d $cache_dir) {
	mkdir($cache_dir) or die "Could not create cache directory $cache_dir: $!\n";
}

# Codes to validate, in the order of the codes file
my @codes = ();
my %wanted = ();
open(my $codes_fh, "<", $codes_file) or die "Could not open $codes_file: $!\n";
while (my $line = <$codes_fh>) {
	$line =~ s/\s+//g;
	next if $line eq '' or $wanted{$line};
	push @codes, $line;
	$wanted{$line} = 1;
}
close($codes_fh);

# Load the wanted products: only lines that contain one of the wanted codes are decoded
my %products = ();
open(my $products_fh, "<", $products_file) or die "Could not open $products_file: $!\n";
while (my $line = <$products_fh>) {
	next unless grep {$wanted{$_}} ($line =~ /"code"\s*:\s*"([^"]+)"/g);
	my $product_ref = eval {$json->decode($line)};
	next unless defined $product_ref and defined $product_ref->{code} and $wanted{$product_ref->{code}};
	$products{$product_ref->{code}} //= $product_ref;
}
close($products_fh);

my %cache_stats = (hits => 0, calls => 0);
my @results = ();
foreach my $code (@codes) {
	my $product_ref = $products{$code};
	if (not defined $product_ref) {
		push @results, {code => $code, skip_reason => "not_in_products_file"};
		next;
	}
	push @results, process_product($product_ref);
}

open(my $output_fh, ">", $output_file) or die "Could not write $output_file: $!\n";
print $output_fh $json->encode($_) . "\n" foreach @results;
close($output_fh);
print STDERR "Ecobalyse API: $cache_stats{calls} calls, $cache_stats{hits} cached responses\n" if $call_api;

print_report(\@results, $compare_file);

exit 0;

sub process_product ($product_ref) {

	my %result = (
		code => $product_ref->{code},
		name => $product_ref->{product_name},
		brands => $product_ref->{brands},
	);

	# Remove the results of previous runs, so that they are not reused
	delete $product_ref->{environmental_impact};

	my $response_ref = ProductOpener::API::get_initialized_response();
	eval {ProductOpener::Products::analyze_and_enrich_product_data($product_ref, $response_ref);};
	if ($@) {
		$result{skip_reason} = "analysis_error";
		$result{error} = "$@";
		return \%result;
	}
	# Only prepare the request, the API is called below with a cache
	ProductOpener::EnvironmentalImpact::estimate_environmental_impact_service($product_ref, {}, [], 1, 1);

	my $environmental_impact_ref = $product_ref->{environmental_impact} // {};
	my $input_ref = $environmental_impact_ref->{ecobalyse_input} // {};
	my $agribalyse_ref = $product_ref->{environmental_score_data}{agribalyse} // {};

	%result = (
		%result,
		categories => $product_ref->{categories_tags},
		agribalyse_code => $agribalyse_ref->{code},
		agribalyse_name => $agribalyse_ref->{name_fr},
		agribalyse_ef_per_kg => $agribalyse_ref->{ef_total},
		coverage_percent => $input_ref->{ingredients_coverage_percent},
		reference_quantity => $input_ref->{reference_quantity},
		reference_quantity_unit => $input_ref->{reference_quantity_unit},
		reference_quantity_source => $input_ref->{reference_quantity_source},
		ingredients_total_mass => $input_ref->{ingredients_total_mass},
		ingredients_scaling_factor => $input_ref->{ingredients_scaling_factor},
		ingredients_n => scalar @{$input_ref->{ingredients} // []},
		packaging => (defined $input_ref->{packaging} ? $input_ref->{packaging}[0]{name_fr} : undef),
		distribution => $input_ref->{distribution},
		transformations => [map {$_->{name}} @{$input_ref->{transformations} // []}],
		skip_reason => $environmental_impact_ref->{ecobalyse_skip_reason},
	);

	my $request_ref = $environmental_impact_ref->{ecobalyse_request};
	if (not defined $request_ref) {
		$result{skip_reason} //= "no_ingredients";
		return \%result;
	}
	return \%result if defined $result{skip_reason};
	if (not $call_api) {
		$result{skip_reason} = "no_api_token";
		return \%result;
	}

	my ($content, $is_success, $code) = call_ecobalyse_with_cache($request_ref);
	# the content is a character string
	my $data_ref = eval {JSON::PP->new->decode($content)};
	my $ecs = (ref($data_ref) eq 'HASH' and ref($data_ref->{score}) eq 'HASH') ? $data_ref->{score}{ecs} : undef;
	if ($is_success and defined $ecs) {
		# The impacts are for the reference quantity of product (in g or ml)
		$result{ecs} = $ecs;
		$result{ecs_per_kg} = $ecs * 1000 / $result{reference_quantity};
		if (ref($data_ref->{stages}) eq 'HASH') {
			$result{stages_per_kg} = {
				map {$_ => $data_ref->{stages}{$_} * 1000 / $result{reference_quantity}}
				grep {JSON::PP::is_bool($data_ref->{stages}{$_}) ? 0 : 1} keys %{$data_ref->{stages}}
			};
		}
	}
	else {
		$result{api_error} = {
			code => $code,
			message => substr(
				  (ref($data_ref) eq 'HASH' and defined $data_ref->{error})
				? (ref($data_ref->{error}) ? JSON::PP->new->canonical->encode($data_ref->{error}) : $data_ref->{error})
				: ($content // ''),
				0,
				500
			),
		};
	}
	return \%result;
}

# Call the Ecobalyse API, with responses cached on disk (keyed by a hash of the request).
# Only successful responses and rejections of the request (4xx other than authentication and rate limiting errors)
# are cached: temporary errors are retried in the next run.
sub call_ecobalyse_with_cache ($request_ref) {
	my $key = sha1_hex($json->encode($request_ref));
	my $cache_file = "$cache_dir/$key.json";
	if (-e $cache_file) {
		open(my $fh, "<", $cache_file) or die "Could not read $cache_file: $!\n";
		my $cached_ref = $json->decode(do {local $/; <$fh>});
		close($fh);
		$cache_stats{hits}++;
		return ($cached_ref->{content}, $cached_ref->{is_success}, $cached_ref->{code});
	}
	my ($content, $is_success, $code)
		= ProductOpener::EnvironmentalImpact::call_ecobalyse($request_ref->{url}, $request_ref->{data}, undef);
	$cache_stats{calls}++;
	$code //= 0;
	# The content is returned in UTF-8 bytes, we return a character string
	$content = eval {decode_utf8($content // '')} // $content;
	if ($is_success or ($code >= 400 and $code < 500 and $code != 401 and $code != 403 and $code != 429)) {
		open(my $fh, ">", $cache_file) or die "Could not write $cache_file: $!\n";
		print $fh $json->encode(
			{request => $request_ref, content => $content, is_success => $is_success ? 1 : 0, code => $code});
		close($fh);
	}
	return ($content, $is_success, $code);
}

=head2 Reports

The functions below only use the results files, they can also read the products files of the earlier
analysis scripts (fields ecs_100, agb_ef, input, skip_reason, error).

=cut

sub read_results ($file) {
	my @results = ();
	open(my $fh, "<", $file) or die "Could not open $file: $!\n";
	while (my $line = <$fh>) {
		next if $line =~ /^\s*$/;
		my $result_ref = $json->decode($line);
		# Products files of the earlier analysis scripts
		if (not exists $result_ref->{agribalyse_ef_per_kg} and exists $result_ref->{agb_ef}) {
			$result_ref->{agribalyse_ef_per_kg} = $result_ref->{agb_ef};
			$result_ref->{agribalyse_name} = $result_ref->{agb_name};
			$result_ref->{ecs_per_kg} = $result_ref->{ecs_100} * 10 if defined $result_ref->{ecs_100};
			$result_ref->{coverage_percent} = ($result_ref->{input} // {})->{ingredients_coverage_percent};
			$result_ref->{api_error} = {message => $result_ref->{error}} if $result_ref->{error};
		}
		push @results, $result_ref;
	}
	close($fh);
	return \@results;
}

sub median (@values) {
	return unless @values;
	my @sorted = sort {$a <=> $b} @values;
	my $n = scalar @sorted;
	return $n % 2 ? $sorted[($n - 1) / 2] : ($sorted[$n / 2 - 1] + $sorted[$n / 2]) / 2;
}

# Ranks starting at 1, ties get the average rank
sub ranks (@values) {
	my @order = sort {$values[$a] <=> $values[$b]} 0 .. $#values;
	my @ranks = ();
	my $i = 0;
	while ($i < @order) {
		my $j = $i;
		$j++ while ($j + 1 < @order) and ($values[$order[$j + 1]] == $values[$order[$i]]);
		$ranks[$order[$_]] = ($i + $j) / 2 + 1 for $i .. $j;
		$i = $j + 1;
	}
	return @ranks;
}

sub pearson ($x_ref, $y_ref) {
	my $n = scalar @$x_ref;
	return unless $n > 2;
	my $mean_x = sum(@$x_ref) / $n;
	my $mean_y = sum(@$y_ref) / $n;
	my ($sxy, $sxx, $syy) = (0, 0, 0);
	for my $i (0 .. $n - 1) {
		my ($dx, $dy) = ($x_ref->[$i] - $mean_x, $y_ref->[$i] - $mean_y);
		$sxy += $dx * $dy;
		$sxx += $dx * $dx;
		$syy += $dy * $dy;
	}
	return unless $sxx > 0 and $syy > 0;
	return $sxy / sqrt($sxx * $syy);
}

sub spearman ($x_ref, $y_ref) {
	return pearson([ranks(@$x_ref)], [ranks(@$y_ref)]);
}

# Metrics of a results set
sub compute_metrics ($results_ref) {
	my %metrics = (products => scalar @$results_ref);
	my @with_ingredients
		= grep {($_->{skip_reason} // '') !~ /^(not_in_products_file|analysis_error|no_ingredients)$/} @$results_ref;
	$metrics{with_ingredients} = scalar @with_ingredients;
	my @eligible = grep {(not defined $_->{skip_reason}) or ($_->{skip_reason} eq 'no_api_token')} @with_ingredients;
	$metrics{eligible} = scalar @eligible;
	$metrics{eligible_coverage_mean}
		= @eligible ? sum(map {$_->{coverage_percent} // 0} @eligible) / @eligible : undef;
	my %skip_reasons = ();
	$skip_reasons{$_->{skip_reason}}++ foreach grep {defined $_->{skip_reason}} @$results_ref;
	$metrics{skip_reasons} = \%skip_reasons;
	$metrics{api_errors} = [grep {defined $_->{api_error}} @$results_ref];

	my @compared = grep {defined $_->{ecs_per_kg} and ($_->{agribalyse_ef_per_kg} // 0) > 0 and $_->{ecs_per_kg} > 0}
		@$results_ref;
	$metrics{with_ecs} = scalar grep {defined $_->{ecs_per_kg}} @$results_ref;
	$metrics{compared} = scalar @compared;
	return \%metrics unless @compared > 2;

	$metrics{spearman} = spearman([map {$_->{ecs_per_kg}} @compared], [map {$_->{agribalyse_ef_per_kg}} @compared]);
	my $median_ratio = median(map {$_->{ecs_per_kg} / $_->{agribalyse_ef_per_kg}} @compared);
	$metrics{median_ratio} = $median_ratio;
	foreach my $result_ref (@compared) {
		$result_ref->{ratio_to_median}
			= $result_ref->{ecs_per_kg} / $result_ref->{agribalyse_ef_per_kg} / $median_ratio;
	}
	my @outliers = sort {abs(log($b->{ratio_to_median})) <=> abs(log($a->{ratio_to_median}))}
		grep {$_->{ratio_to_median} > 3 or $_->{ratio_to_median} < 1 / 3} @compared;
	$metrics{outliers_3x} = scalar @outliers;
	$metrics{worst} = [(sort {abs(log($b->{ratio_to_median})) <=> abs(log($a->{ratio_to_median}))} @compared)];
	return \%metrics;
}

sub percent ($n, $total) {
	return $total ? sprintf("%.1f%%", 100 * $n / $total) : "-";
}

sub format_number ($value, $format = "%.2f") {
	return defined $value ? sprintf($format, $value) : "-";
}

sub product_label ($result_ref) {
	my $name = join(" - ", grep {defined $_ and $_ ne ''} $result_ref->{name}, $result_ref->{brands});
	$name = substr($name, 0, 45);
	return "$result_ref->{code} $name";
}

sub print_report ($results_ref, $compare_file) {
	my $metrics_ref = compute_metrics($results_ref);
	my $previous_metrics_ref;
	my %previous = ();
	if (defined $compare_file) {
		my $previous_results_ref = read_results($compare_file);
		$previous_metrics_ref = compute_metrics($previous_results_ref);
		%previous = map {$_->{code} => $_} @$previous_results_ref;
	}

	my @rows = (
		["Products", "products", "%d"],
		["With ingredients", "with_ingredients", "%d"],
		["Eligible (API called)", "eligible", "%d"],
		["Mean coverage of eligible products (%)", "eligible_coverage_mean", "%.1f"],
		["With ECS", "with_ecs", "%d"],
		["API errors", sub ($m) {scalar @{$m->{api_errors}}}, "%d"],
		["Compared with Agribalyse", "compared", "%d"],
		["Spearman ECS/kg vs Agribalyse EF/kg", "spearman", "%.3f"],
		["Median ECS / Agribalyse EF ratio", "median_ratio", "%.0f"],
		["More than 3x away from the median ratio", "outliers_3x", "%d"],
	);
	print "\n== Summary ==\n\n";
	printf("%-42s %12s %12s\n", "", "before", "after") if $previous_metrics_ref;
	foreach my $row_ref (@rows) {
		my ($label, $key, $format) = @$row_ref;
		my $get = sub ($m) {return ref($key) ? $key->($m) : $m->{$key}};
		if ($previous_metrics_ref) {
			printf(
				"%-42s %12s %12s\n",
				$label,
				format_number($get->($previous_metrics_ref), $format),
				format_number($get->($metrics_ref), $format)
			);
		}
		else {
			printf("%-42s %12s\n", $label, format_number($get->($metrics_ref), $format));
		}
	}
	printf("%-42s %12s\n", "Eligible %", percent($metrics_ref->{eligible}, $metrics_ref->{with_ingredients}));
	print "\nSkip reasons: "
		. join(", ", map {"$_: $metrics_ref->{skip_reasons}{$_}"} sort keys %{$metrics_ref->{skip_reasons}}) . "\n"
		if %{$metrics_ref->{skip_reasons}};

	if (@{$metrics_ref->{api_errors}}) {
		print "\n== API errors (" . scalar(@{$metrics_ref->{api_errors}}) . ") ==\n\n";
		my %by_message = ();
		push @{$by_message{$_->{api_error}{message}}}, $_->{code} foreach @{$metrics_ref->{api_errors}};
		foreach my $message (sort {@{$by_message{$b}} <=> @{$by_message{$a}}} keys %by_message) {
			my @codes = @{$by_message{$message}};
			print scalar(@codes) . " products: $message\n  " . join(" ", @codes) . "\n";
		}
	}

	if ($metrics_ref->{worst}) {
		print "\n== Worst $top outliers (ECS/kg vs Agribalyse EF/kg, relative to the median ratio) ==\n\n";
		printf("%-60s %6s %9s %9s %8s %s\n", "product", "cov%", "ECS/kg", "AGB EF", "x median", "Agribalyse category");
		foreach my $result_ref (grep {defined} @{$metrics_ref->{worst}}[0 .. $top - 1]) {
			my $previous_ref = $previous{$result_ref->{code}};
			printf(
				"%-60s %6s %9.0f %9.3f %8.2f %s%s\n",
				product_label($result_ref),
				$result_ref->{coverage_percent} // '-',
				$result_ref->{ecs_per_kg},
				$result_ref->{agribalyse_ef_per_kg},
				$result_ref->{ratio_to_median},
				substr($result_ref->{agribalyse_name} // '', 0, 50),
				(
					(defined $previous_ref and defined $previous_ref->{ecs_per_kg})
					? sprintf(" (before: %.0f)", $previous_ref->{ecs_per_kg})
					: ""
				)
			);
		}
	}

	return if not $previous_metrics_ref;

	# Products with the largest changes of ECS/kg
	my @changes = ();
	my ($lost, $gained) = (0, 0);
	foreach my $result_ref (@$results_ref) {
		my $previous_ref = $previous{$result_ref->{code}} or next;
		my ($before, $after) = ($previous_ref->{ecs_per_kg}, $result_ref->{ecs_per_kg});
		$lost++ if defined $before and not defined $after;
		$gained++ if defined $after and not defined $before;
		next unless defined $before and defined $after and $before > 0 and $after > 0;
		push @changes, [$result_ref, $previous_ref, $after / $before];
	}
	print "\n== Before / after ==\n\n";
	print "Products with an ECS before and after: " . scalar(@changes) . "\n";
	print "ECS lost: $lost, ECS gained: $gained\n";
	if (@changes) {
		my @ratios = map {$_->[2]} @changes;
		printf(
			"ECS/kg after / before: median %.3f, min %.3f, max %.3f, changed by more than 1%%: %d\n",
			median(@ratios),
			(sort {$a <=> $b} @ratios)[0],
			(sort {$b <=> $a} @ratios)[0],
			scalar grep {abs($_ - 1) > 0.01} @ratios
		);
		print "\nLargest changes:\n";
		printf("%-60s %9s %9s %7s %13s\n", "product", "before", "after", "after/", "coverage");
		foreach my $change_ref ((sort {abs(log($b->[2])) <=> abs(log($a->[2]))} @changes)[0 .. $top - 1]) {
			next unless defined $change_ref;
			my ($result_ref, $previous_ref, $ratio) = @$change_ref;
			printf(
				"%-60s %9.0f %9.0f %7.3f %6s->%-6s\n",
				product_label($result_ref),
				$previous_ref->{ecs_per_kg},
				$result_ref->{ecs_per_kg},
				$ratio,
				$previous_ref->{coverage_percent} // '-',
				$result_ref->{coverage_percent} // '-'
			);
		}
	}
	return;
}
