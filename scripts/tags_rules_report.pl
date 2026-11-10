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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use ProductOpener::PerlStandards;
use utf8;

my $usage = <<TXT
tags_rules_report.pl: dry run of the tags rules (rules/) on a JSONL dump of products. No MongoDB, no writes.

Usage:

tags_rules_report.pl --jsonl openfoodfacts-products.jsonl.gz --output report.csv
	[--rules-ids colas-caffeinated,crispbreads-wholemeal-rye] [--rules-dir rules/food] [--samples 50] [--seed 42]
	[--products-output products.csv]

tags_rules_report.pl --print-reprocessing-commands [--rules-ids a,b] [--key tags_rules_YYYYMMDD]

Output:
- report.csv: one line per rule: matches, already in the target, would add, conflicts,
  complete products that would be added, number of countries, top countries.
- report_samples.csv (next to report.csv): random examples of products the rule would change, for manual review.
- --products-output: one line per product changed by a rule (code, rule, added tags).

--print-reprocessing-commands: print the update_all_products.pl commands that reprocess the products
in the required categories of the (selected) rules, and exit. See docs/dev/how-to-reprocess-products-for-tags-rules.md
TXT
	;

use ProductOpener::Config qw/%options/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::TagsRules qw/:all/;

use Getopt::Long;
use Cpanel::JSON::XS;
use List::Util qw/shuffle/;
use POSIX qw/strftime/;

my $jsonl;
my $output;
my $rules_ids;
my $rules_dir;
my $samples_n = 50;
my $seed = 42;
my $products_output;
my $print_reprocessing_commands;
my $key;

GetOptions(
	"jsonl=s" => \$jsonl,
	"output=s" => \$output,
	"rules-ids=s" => \$rules_ids,
	"rules-dir=s" => \$rules_dir,
	"samples=i" => \$samples_n,
	"seed=i" => \$seed,
	"products-output=s" => \$products_output,
	"print-reprocessing-commands" => \$print_reprocessing_commands,
	"key=s" => \$key,
) or die($usage);

$rules_dir //= $BASE_DIRS{RULES} . "/" . ($options{product_type} // "food");

my $ruleset_ref = load_tags_rules($rules_dir);
if (@{$ruleset_ref->{errors}}) {
	die("Invalid rules in $rules_dir:\n" . join("\n", @{$ruleset_ref->{errors}}) . "\n");
}

my @rules = @{$ruleset_ref->{rules}};
if (defined $rules_ids) {
	my %ids = map {$_ => 1} split(/,/, $rules_ids);
	foreach my $id (keys %ids) {
		die("Unknown rule id $id\n") if not defined $ruleset_ref->{by_id}{$id};
	}
	@rules = grep {$ids{$_->{id}}} @rules;
}
my @rule_ids = map {$_->{id}} @rules;

# Required categories of the selected rules
my %required_categories = ();
foreach my $rule_ref (@rules) {
	$required_categories{$_} = 1 foreach @{$rule_ref->{required_categories}};
}

if ($print_reprocessing_commands) {
	$key //= "tags_rules_" . strftime("%Y%m%d", gmtime());
	foreach my $category (sort keys %required_categories) {
		print "./scripts/update_all_products.pl --query categories_tags=$category "
			. "--analyze-and-enrich-product-data --key $key\n";
	}
	exit(0);
}

(defined $jsonl and defined $output) or die($usage);

srand($seed);

my $json = Cpanel::JSON::XS->new->utf8->allow_nonref;

my $in;
if ($jsonl =~ /\.gz$/) {
	open($in, "-|", "gzip", "-dc", $jsonl) or die("Cannot read $jsonl: $!\n");
}
else {
	open($in, "<", $jsonl) or die("Cannot read $jsonl: $!\n");
}

my $products_out;
if (defined $products_output) {
	open($products_out, ">:encoding(UTF-8)", $products_output) or die("Cannot write $products_output: $!\n");
	print $products_out join("\t", qw(code rule result tags)) . "\n";
}

# Quick pre-filter on the raw line: the products must contain one of the required categories
# (categories_tags in the dump contains the parents)
my $prefilter = join("|", map {quotemeta("\"$_\"")} sort keys %required_categories);
$prefilter = qr/$prefilter/;

my %stats = map {
	$_ => {
		matches => 0,
		already => 0,
		would_add => 0,
		conflicts => 0,
		would_add_complete => 0,
		countries => {},
		seen => 0,
		samples => []
	}
} @rule_ids;

my ($lines, $candidates) = (0, 0);

while (my $line = <$in>) {
	$lines++;
	print STDERR "$lines lines, $candidates candidates\n" if $lines % 500000 == 0;
	next if $line !~ $prefilter;

	my $product_ref = eval {$json->decode($line)};
	next if not defined $product_ref;
	$candidates++;

	my $result_ref = evaluate_tags_rules($product_ref, {rules => $ruleset_ref, rule_ids => \@rule_ids});
	next if not @{$result_ref->{matched}};

	# Tags added by each rule
	my %added_by_rule = ();
	foreach my $field (keys %{$result_ref->{added}}) {
		foreach my $tag (keys %{$result_ref->{added}{$field}}) {
			foreach my $rule_id (@{$result_ref->{added}{$field}{$tag}}) {
				push @{$added_by_rule{$rule_id}}, "$field:$tag";
			}
		}
	}
	my %conflicts_by_rule = ();
	foreach my $conflict_ref (@{$result_ref->{conflicts}}) {
		push @{$conflicts_by_rule{$conflict_ref->{rule}}},
			$conflict_ref->{tag} . " conflicts with " . join("+", @{$conflict_ref->{with}});
	}

	foreach my $rule_id (@{$result_ref->{matched}}) {
		my $stats_ref = $stats{$rule_id};
		$stats_ref->{matches}++;
		$stats_ref->{already}++ if defined $result_ref->{already}{$rule_id};

		my $result;
		if (defined $conflicts_by_rule{$rule_id}) {
			$stats_ref->{conflicts}++;
			$result = "conflict: " . join(", ", @{$conflicts_by_rule{$rule_id}});
		}
		elsif (defined $added_by_rule{$rule_id}) {
			$stats_ref->{would_add}++;
			$result = "add";
			if (($product_ref->{complete} // 0) == 1) {
				$stats_ref->{would_add_complete}++;
				$stats_ref->{countries}{$_}++ foreach @{$product_ref->{countries_tags} // []};
			}
		}
		else {
			next;
		}

		print $products_out
			join("\t", $product_ref->{code}, $rule_id, $result, join(",", @{$added_by_rule{$rule_id} // []})) . "\n"
			if defined $products_out;

		# Reservoir sampling of the products changed by the rule (additions and conflicts)
		$stats_ref->{seen}++;
		my $sample_ref = [$product_ref->{code}, $result, sample_fields($product_ref)];
		if (scalar @{$stats_ref->{samples}} < $samples_n) {
			push @{$stats_ref->{samples}}, $sample_ref;
		}
		else {
			my $j = int(rand($stats_ref->{seen}));
			$stats_ref->{samples}[$j] = $sample_ref if $j < $samples_n;
		}
	}
}
close($in);

print STDERR "$lines lines, $candidates candidates\n";

sub sample_fields ($product_ref) {
	my $name = $product_ref->{product_name} // "";
	if ($name eq "") {
		foreach my $key (sort keys %$product_ref) {
			if (($key =~ /^product_name_/) and (($product_ref->{$key} // "") ne "")) {
				$name = $product_ref->{$key};
				last;
			}
		}
	}
	my @input_categories = ();
	foreach my $source (sort keys %{$product_ref->{tags_sources}{categories} // {}}) {
		next if $source eq "rules";
		push @input_categories, @{$product_ref->{tags_sources}{categories}{$source}{tags} // []};
	}
	@input_categories = @{$product_ref->{categories_tags} // []} if not @input_categories;
	my @first_ingredients = map {$_->{id} . (defined $_->{percent} ? " " . $_->{percent} . "%" : "")}
		grep {ref($_) eq 'HASH'} @{$product_ref->{ingredients} // []};
	splice(@first_ingredients, 5) if @first_ingredients > 5;
	my $cocoa = $product_ref->{nutrition}{aggregated_set}{nutrients}{cocoa}{value};
	return (
		$name,
		$product_ref->{brands} // "",
		join(",", @input_categories),
		join(", ", @first_ingredients),
		join(",", map {s/^en://r} @{$product_ref->{countries_tags} // []}),
		$cocoa // "",
		$product_ref->{complete} // 0,
	);
}

sub csv_line (@fields) {
	return join(
		",",
		map {
			my $value = $_ // "";
			$value =~ s/[\r\n\t]+/ /g;
			($value =~ /[",]/) ? '"' . ($value =~ s/"/""/gr) . '"' : $value
		} @fields
	) . "\n";
}

open(my $out, ">:encoding(UTF-8)", $output) or die("Cannot write $output: $!\n");
print $out csv_line(
	qw(rule description add matches already_in_target would_add conflicts would_add_complete countries top_countries));
foreach my $rule_ref (@rules) {
	my $stats_ref = $stats{$rule_ref->{id}};
	my $countries_ref = $stats_ref->{countries};
	my @top = sort {$countries_ref->{$b} <=> $countries_ref->{$a} || $a cmp $b} keys %$countries_ref;
	splice(@top, 10) if @top > 10;
	print $out csv_line(
		$rule_ref->{id},
		$rule_ref->{description},
		join(
			" ",
			map {
				my $f = $_;
				map {"$f:$_"} @{$rule_ref->{add}{$f}}
			} sort keys %{$rule_ref->{add}}
		),
		@$stats_ref{qw(matches already would_add conflicts would_add_complete)},
		scalar keys %$countries_ref,
		join(" ", map {s/^en://r . ":" . $countries_ref->{$_}} @top),
	);
}
close($out);

(my $samples_output = $output) =~ s/(\.csv)?$/_samples.csv/;
open(my $samples_out, ">:encoding(UTF-8)", $samples_output) or die("Cannot write $samples_output: $!\n");
print $samples_out csv_line(
	qw(rule code result url product_name brands input_categories first_ingredients countries cocoa complete));
foreach my $rule_id (@rule_ids) {
	foreach my $sample_ref (sort {$a->[0] cmp $b->[0]} @{$stats{$rule_id}{samples}}) {
		my ($code, $result, @fields) = @$sample_ref;
		print $samples_out csv_line($rule_id, $code, $result, "https://world.openfoodfacts.org/product/$code", @fields);
	}
}
close($samples_out);
close($products_out) if defined $products_out;

print STDERR "Wrote $output and $samples_output\n";
