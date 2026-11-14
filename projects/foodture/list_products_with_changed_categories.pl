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

use ProductOpener::PerlStandards;

use ProductOpener::Tags qw/:all/;
use ProductOpener::Store qw/get_string_id_for_lang/;
use JSON::MaybeXS;
use Text::CSV;
use Getopt::Long;

# This script lists the products whose categories change with a new version of the categories taxonomy,
# so that only those products are reprocessed in production (update_all_products.pl --query-codes-from-file).
#
# It needs two builds of the categories taxonomy in the build cache:
# - the new one, as usual: taxonomies-result/categories.result.json
# - the old one (the one in production), copied to taxonomies-result/categories_old.result.json
# The old one is loaded as a separate tag type (categories_old), so both can be used in the same process.
#
# For each product of the JSONL dump, categories are recomputed from the stored input tags
# (tags_sources.categories.*.tags, or the categories field for older schemas, as in update_all_products.pl
# and select_representative_products.pl) with both taxonomies. A product is listed if:
# - the two results differ, or
# - one of its categories has properties that changed (properties matching --ignore-properties are not compared)
#
# Products whose stored categories_tags differ from the result with the old taxonomy are counted separately
# (codes_stale.txt): their categories are out of date for other reasons than this taxonomy change.
#
# The script also lists the synonyms that moved from an existing entry to another entry:
# products stored with the old entry are not moved by reprocessing, as the original text is lost.
# It lists the products of the old entry whose name contains the synonym (moved_synonyms_products.csv).
#
# Lists of products whose stored categories_tags differ from the result with the new taxonomy,
# whatever the cause (this taxonomy change, or older changes that were not reprocessed):
# - codes_categories_changed_all.txt: all of them
# - codes_categories_changed_candidates.txt: only products that can be selected as representative products:
# complete (same states as select_representative_products.pl), sold in one of the countries of the dataset,
# and with one of the OFF categories of the mapping (--mapping-file) in their stored or new categories
# - codes_categories_changed_candidates_scanned.txt: candidates with unique_scans_n > 0
# - codes_categories_changed_mapped.txt: candidates for which one of the OFF categories of the mapping
# is added or removed (the change matters for the representative products), and _mapped_scanned.txt
# mapped_categories_changes.csv: number of these products by mapped category added or removed
# Reprocessing sends a Redis event for each changed product, so the shorter lists limit the load on
# the systems that process them (e.g. off-query).
#
# Cross-check: the set T of the old tags affected by the change (canonical id, ancestors or properties changed,
# or unknown tags that are now recognized) is computed from the two taxonomies, and the products
# whose stored categories_tags intersect T are compared with the list above.

my $usage = <<TXT
list_products_with_changed_categories.pl --jsonl <products.jsonl[.gz]> --output-dir <dir>
	[--old-tagtype categories_old] [--ignore-properties <regexp>] [--mapping-file <file.csv>]
TXT
	;

my $jsonl_file;
my $output_dir;
my $old_tagtype = "categories_old";
my $ignore_properties
	= '^(foodex2_|description|comment|wikidata|wikipedia|ciqual_food_name|agribalyse_food_name|agribalyse_proxy_food_name)';

my $mapping_file = "projects/foodture/foodture_foodex2_to_off_categories.csv";

GetOptions(
	"mapping-file=s" => \$mapping_file,
	"jsonl=s" => \$jsonl_file,
	"output-dir=s" => \$output_dir,
	"old-tagtype=s" => \$old_tagtype,
	"ignore-properties=s" => \$ignore_properties,
) or die $usage;

(defined $jsonl_file and defined $output_dir) or die $usage;
-d $output_dir or mkdir($output_dir) or die "Cannot create $output_dir: $!\n";

my $new_tagtype = "categories";
retrieve_tags_taxonomy($old_tagtype, 1);

# same countries as select_representative_products.pl and extract_data_for_representative_products.pl
my %dataset_countries = map {canonicalize_taxonomy_tag('en', 'countries', $_) => 1} qw/
	Austria Belgium Bulgaria Canada Croatia Cyprus Czechia Denmark Estonia Finland France Germany Greece Hungary
	Iceland Ireland Italy Latvia Lithuania Luxembourg Malta Montenegro Netherlands Norway Poland Portugal Romania
	Serbia Slovakia Slovenia Spain Sweden Switzerland UK
	/;
my @complete_states = qw/en:nutrition-facts-completed en:ingredients-completed en:photos-uploaded/;

# OFF categories of the mapping (with the new taxonomy)
my %mapped_categories = ();
{
	my $mapping_csv = Text::CSV->new({binary => 1, auto_diag => 1});
	open(my $MAPPING, '<:encoding(UTF-8)', $mapping_file) or die "Cannot read $mapping_file: $!\n";
	$mapping_csv->column_names($mapping_csv->getline($MAPPING));
	while (my $mapping_ref = $mapping_csv->getline_hr($MAPPING)) {
		$mapped_categories{canonicalize_taxonomy_tag('en', 'categories', $mapping_ref->{off_category})} = 1;
	}
	close $MAPPING;
	print STDERR scalar(keys %mapped_categories) . " OFF categories in $mapping_file\n";
}

my $csv = Text::CSV->new({binary => 1, eol => "\n"});

sub write_csv ($file, $header_ref, $rows_ref) {
	open(my $OUT, '>:encoding(UTF-8)', "$output_dir/$file") or die "Cannot write $output_dir/$file: $!\n";
	$csv->print($OUT, $header_ref);
	$csv->print($OUT, $_) for @$rows_ref;
	close $OUT;
	return;
}

# 1. Compare the two taxonomies

# canonical tag -> relevant properties, as a string
sub properties_string ($tagtype, $tagid) {
	my $properties_ref = $properties{$tagtype}{$tagid} // {};
	return join("\n", map {"$_=$properties_ref->{$_}"} grep {$_ !~ /$ignore_properties/} sort keys %$properties_ref);
}

sub ancestors_string ($tagtype, $tagid) {
	return join(",", sort grep {$_ ne $tagid} gen_tags_hierarchy_taxonomy("en", $tagtype, $tagid));
}

my %old_canonical = map {$_ => 1} keys %{$translations_to{$old_tagtype}};
my %new_canonical = map {$_ => 1} keys %{$translations_to{$new_tagtype}};

# Tags of the new taxonomy whose relevant properties changed
my %changed_properties = ();
my %changed_property_names = ();
foreach my $tagid (keys %new_canonical) {
	my $old = $old_canonical{$tagid} ? properties_string($old_tagtype, $tagid) : '';
	my $new = properties_string($new_tagtype, $tagid);
	if ($old ne $new) {
		$changed_properties{$tagid} = 1;
		my %old = map {$_ => 1} split(/\n/, $old);
		my %new = map {$_ => 1} split(/\n/, $new);
		$changed_property_names{(split(/=/, $_))[0]}++ for grep {not($old{$_} and $new{$_})} (keys %old, keys %new);
	}
}
print STDERR scalar(keys %changed_properties)
	. " categories with changed properties: "
	. join(", ", map {"$_ ($changed_property_names{$_})"} sort keys %changed_property_names) . "\n";

# T: tags stored with the old taxonomy that are affected by the change
my %affected_tags = ();    # tag -> reason
foreach my $tagid (keys %old_canonical) {
	my $new_tagid = canonicalize_taxonomy_tag("en", $new_tagtype, $tagid);
	if ($new_tagid ne $tagid) {
		$affected_tags{$tagid} = "canonical id changed: $new_tagid";
	}
	elsif (not $new_canonical{$tagid}) {
		$affected_tags{$tagid} = "removed";
	}
	elsif (ancestors_string($old_tagtype, $tagid) ne ancestors_string($new_tagtype, $tagid)) {
		$affected_tags{$tagid} = "ancestors changed";
	}
	elsif ($changed_properties{$tagid}) {
		$affected_tags{$tagid} = "properties changed";
	}
}

# Synonyms: unknown before and recognized now, or moved from an existing entry to another one
my @moved_synonyms = ();    # [lc, synonym id, old entry, new entry]
my %seen_synonym = ();
foreach my $tagtype ($old_tagtype, $new_tagtype) {
	foreach my $lc (sort keys %{$synonyms_for{$tagtype} // {}}) {
		foreach my $synonym_id (sort map {@$_} values %{$synonyms_for{$tagtype}{$lc}}) {
			next if $seen_synonym{"$lc:$synonym_id"}++;
			my ($old_exists, $new_exists);
			my $old_tagid = canonicalize_taxonomy_tag($lc, $old_tagtype, $synonym_id, \$old_exists);
			my $new_tagid = canonicalize_taxonomy_tag($lc, $new_tagtype, $synonym_id, \$new_exists);
			next if (not $new_exists);
			if (not $old_exists) {
				# stored as an unknown tag: "lc:synonym_id"
				$affected_tags{$old_tagid} //= "now recognized: $new_tagid";
			}
			else {
				# the old entry, as recognized by the new taxonomy
				my $old_tagid_in_new = canonicalize_taxonomy_tag("en", $new_tagtype, $old_tagid);
				if (    ($old_tagid ne $new_tagid)
					and ($old_tagid_in_new ne $new_tagid)
					and $new_canonical{$old_tagid_in_new})
				{
					push @moved_synonyms, [$lc, $synonym_id, $old_tagid, $new_tagid];
				}
			}
		}
	}
}

write_csv("affected_tags.csv", ["tag", "reason"], [map {[$_, $affected_tags{$_}]} sort keys %affected_tags]);
print STDERR scalar(keys %affected_tags) . " affected tags (T), " . scalar(@moved_synonyms) . " moved synonyms\n";

# moved synonyms by old entry (as recognized by the new taxonomy) and new entry
my %moved_synonyms_by_entry = ();    # old entry -> new entry -> [[lc, synonym id]]
foreach my $moved_ref (@moved_synonyms) {
	my ($lc, $synonym, $old_tagid, $new_tagid) = @$moved_ref;
	my $entry = canonicalize_taxonomy_tag("en", $new_tagtype, $old_tagid);
	push @{$moved_synonyms_by_entry{$entry}{$new_tagid}}, [$lc, get_string_id_for_lang($lc, $synonym)];
}

# 2. Go through the products

my %categories_cache = ();

# Same input tags as update_all_products.pl --fields categories (generate_field_tags_from_all_sources())
# and select_representative_products.pl
sub get_input_tags ($product_ref) {
	my $sources_ref = $product_ref->{tags_sources}{categories};
	if (ref $sources_ref eq 'HASH') {
		my %tags = map {$_ => 1} map {@{$_->{tags} // []}} grep {ref $_ eq 'HASH'} values %$sources_ref;
		return ('en', sort keys %tags);
	}
	elsif ((not ref $product_ref->{categories}) and (($product_ref->{categories} // '') ne '')) {
		return ($product_ref->{categories_lc} // $product_ref->{lc} // 'en',
			split(/\s*,\s*/, $product_ref->{categories}));
	}
	return ('en', @{$product_ref->{categories_tags} // []});
}

# [old categories, new categories, changed (0/1), properties changed (0/1)], cached by input tags
sub get_categories ($tag_lc, @input_tags) {
	my $key = join("\t", $tag_lc, @input_tags);
	return $categories_cache{$key} //= do {
		my @old = sort(gen_tags_list_with_parents($tag_lc, $old_tagtype, [@input_tags]));
		my @new = sort(gen_tags_list_with_parents($tag_lc, $new_tagtype, [@input_tags]));
		[\@old, \@new, (join(",", @old) ne join(",", @new)) ? 1 : 0, (grep {$changed_properties{$_}} @new) ? 1 : 0];
	};
}

my $IN;
if ($jsonl_file =~ /\.gz$/) {
	open($IN, '-|', 'gzip', '-dc', $jsonl_file) or die "Cannot read $jsonl_file: $!\n";
}
else {
	open($IN, '<', $jsonl_file) or die "Cannot read $jsonl_file: $!\n";
}

my $json = JSON::MaybeXS->new(utf8 => 1);

open(my $CODES, '>', "$output_dir/codes.txt") or die;
open(my $STALE, '>', "$output_dir/codes_stale.txt") or die;
open(my $NON_NUMERIC, '>', "$output_dir/codes_non_numeric.txt") or die;
open(my $ALL, '>', "$output_dir/codes_categories_changed_all.txt") or die;
open(my $CANDIDATES, '>', "$output_dir/codes_categories_changed_candidates.txt") or die;
open(my $SCANNED, '>', "$output_dir/codes_categories_changed_candidates_scanned.txt") or die;
open(my $MAPPED, '>', "$output_dir/codes_categories_changed_mapped.txt") or die;
open(my $MAPPED_SCANNED, '>', "$output_dir/codes_categories_changed_mapped_scanned.txt") or die;
my %mapped_added = ();
my %mapped_removed = ();

my %count = ();
my %tags_added = ();
my %tags_removed = ();
my %products_with_changed_properties = ();
my @moved_rows = ();
my %xcheck_examples = ();
my @xcheck_rows = ();
my %moved_counts = ();    # "lc:synonym" -> [products in the old entry, products with the synonym in their name]

while (my $line = <$IN>) {
	$count{products}++;
	print STDERR join(", ", map {"$_: $count{$_}"} sort keys %count) . "\n" if $count{products} % 100000 == 0;

	my $product_ref = eval {$json->decode($line)};
	if (not defined $product_ref) {
		warn "Cannot decode line $count{products}: $@\n";
		next;
	}
	my $code = $product_ref->{code};
	next if (not defined $code) or (ref $code) or ($code eq '');

	my ($tag_lc, @input_tags) = get_input_tags($product_ref);
	next if not @input_tags;
	$count{with_categories}++;

	my ($old_ref, $new_ref, $changed, $properties_changed) = @{get_categories($tag_lc, @input_tags)};
	my @stored = sort @{$product_ref->{categories_tags} // []};
	my $stale = (join(",", @stored) ne join(",", @$old_ref)) ? 1 : 0;

	# stored categories that differ from the result with the new taxonomy, whatever the cause
	if (join(",", @stored) ne join(",", @$new_ref)) {
		my $cause = $changed ? "new_taxonomy" : "stale";
		$count{"categories_changed_all"}++;
		$count{"categories_changed_all_$cause"}++;
		print $ALL "$code\n";
		my %states = map {$_ => 1} @{$product_ref->{states_tags} // []};
		if (    (not grep {not $states{$_}} @complete_states)
			and (grep {$dataset_countries{$_}} @{$product_ref->{countries_tags} // []})
			and (grep {$mapped_categories{$_}} (@stored, @$new_ref)))
		{
			$count{"categories_changed_candidates"}++;
			$count{"categories_changed_candidates_$cause"}++;
			print $CANDIDATES "$code\n";
			if (($product_ref->{unique_scans_n} // 0) > 0) {
				$count{"categories_changed_candidates_scanned"}++;
				$count{"categories_changed_candidates_scanned_$cause"}++;
				print $SCANNED "$code\n";
			}
			# mapped categories added or removed
			my %stored = map {$_ => 1} @stored;
			my %new = map {$_ => 1} @$new_ref;
			my @added = grep {$mapped_categories{$_} and not $stored{$_}} @$new_ref;
			my @removed = grep {$mapped_categories{$_} and not $new{$_}} @stored;
			if (@added or @removed) {
				$mapped_added{$_}++ for @added;
				$mapped_removed{$_}++ for @removed;
				$count{"categories_changed_mapped"}++;
				$count{"categories_changed_mapped_$cause"}++;
				print $MAPPED "$code\n";
				if (($product_ref->{unique_scans_n} // 0) > 0) {
					$count{"categories_changed_mapped_scanned"}++;
					$count{"categories_changed_mapped_scanned_$cause"}++;
					print $MAPPED_SCANNED "$code\n";
				}
			}
		}
	}

	if ($changed or $properties_changed) {
		$count{to_reprocess}++;
		$count{to_reprocess_categories_changed}++ if $changed;
		$count{to_reprocess_only_properties_changed}++ if not $changed;
		print $CODES "$code\n";
		print $NON_NUMERIC "$code\n" if $code !~ /^\d+$/;
		if ($changed) {
			my %old = map {$_ => 1} @$old_ref;
			my %new = map {$_ => 1} @$new_ref;
			$tags_added{$_}++ for grep {not $old{$_}} @$new_ref;
			$tags_removed{$_}++ for grep {not $new{$_}} @$old_ref;
		}
		$products_with_changed_properties{$_}++ for grep {$changed_properties{$_}} @$new_ref;
	}
	elsif ($stale) {
		$count{stale_not_changed_by_new_taxonomy}++;
		print $STALE "$code\n";
	}

	# cross-check with the affected tags T
	my $in_t = (grep {$affected_tags{$_}} @stored) ? 1 : 0;
	my $in_t_old = (grep {$affected_tags{$_}} @$old_ref) ? 1 : 0;
	my $listed = ($changed or $properties_changed) ? 1 : 0;
	$count{"xcheck_stored_in_T_${in_t}_listed_${listed}"}++;
	$count{"xcheck_recomputed_old_in_T_${in_t_old}_listed_${listed}"}++;
	if (($in_t_old != $listed) and ($xcheck_examples{$listed}++ < 200)) {
		my %old = map {$_ => 1} @$old_ref;
		my %new = map {$_ => 1} @$new_ref;
		push @xcheck_rows,
			[
			$code,
			$listed,
			$in_t_old,
			join(",", map {"$_ ($affected_tags{$_})"} grep {$affected_tags{$_}} @$old_ref),
			join(",", grep {not $old{$_}} @$new_ref),
			join(",", grep {not $new{$_}} @$old_ref),
			join(",", @input_tags)
			];
	}

	# moved synonyms: products in the old entry, with the synonym in their name
	foreach my $entry (grep {$moved_synonyms_by_entry{$_}} @$new_ref) {
		foreach my $new_tagid (sort keys %{$moved_synonyms_by_entry{$entry}}) {
			next if grep {$_ eq $new_tagid} @$new_ref;    # already in the new entry
			$moved_counts{"$entry\t$new_tagid"}[0]++;
			my ($matching_name, $matching_synonym);
		SYNONYM: foreach my $synonym_ref (@{$moved_synonyms_by_entry{$entry}{$new_tagid}}) {
				my ($lc, $synonym_id) = @$synonym_ref;
				foreach my $field ("product_name_$lc", "generic_name_$lc") {
					my $name = $product_ref->{$field} // '';
					next if ref $name or $name eq '';
					if (index("-" . get_string_id_for_lang($lc, $name) . "-", "-$synonym_id-") >= 0) {
						($matching_name, $matching_synonym) = ($name, "$lc:$synonym_id");
						last SYNONYM;
					}
				}
			}
			if (defined $matching_name) {
				$moved_counts{"$entry\t$new_tagid"}[1]++;
				push @moved_rows,
					[
					$code, $entry, $new_tagid, $matching_synonym, $matching_name,
					join(",", @{$product_ref->{countries_tags} // []})
					];
			}
		}
	}
}
close $IN;
close $CODES;
close $STALE;
close $NON_NUMERIC;
close $ALL;
close $CANDIDATES;
close $SCANNED;
close $MAPPED;
close $MAPPED_SCANNED;
write_csv(
	"mapped_categories_changes.csv",
	["category", "products_added", "products_removed"],
	[
		map {[$_, $mapped_added{$_} // 0, $mapped_removed{$_} // 0]}
		sort {
				  ($mapped_added{$b} // 0)
				+ ($mapped_removed{$b} // 0) <=> ($mapped_added{$a} // 0)
				+ ($mapped_removed{$a} // 0)
				or $a cmp $b
		} keys %{{%mapped_added, %mapped_removed}}
	]
);

write_csv(
	"changed_tags.csv",
	["tag", "products_added", "products_removed"],
	[
		map {[$_, $tags_added{$_} // 0, $tags_removed{$_} // 0]}
		sort {
			($tags_added{$b} // 0) + ($tags_removed{$b} // 0) <=> ($tags_added{$a} // 0) + ($tags_removed{$a} // 0)
				or $a cmp $b
			}
			keys %{{%tags_added, %tags_removed}}
	]
);
write_csv(
	"changed_properties_tags.csv",
	["tag", "products", "old_properties", "new_properties"],
	[
		map {
			[
				$_,
				$products_with_changed_properties{$_} // 0,
				($old_canonical{$_} ? properties_string($old_tagtype, $_) : ''),
				properties_string($new_tagtype, $_)
			]
		} sort keys %changed_properties
	]
);
write_csv(
	"moved_synonyms.csv",
	["old_entry", "new_entry", "synonyms", "products_in_old_entry", "products_with_synonym_in_name"],
	[
		map {
			my $entry = $_;
			map {
				[
					$entry, $_,
					join(", ", map {"$_->[0]:$_->[1]"} @{$moved_synonyms_by_entry{$entry}{$_}}),
					$moved_counts{"$entry\t$_"}[0] // 0,
					$moved_counts{"$entry\t$_"}[1] // 0
				]
			} sort keys %{$moved_synonyms_by_entry{$entry}}
		} sort keys %moved_synonyms_by_entry
	]
);
write_csv("moved_synonyms_products.csv",
	["code", "old_entry", "new_entry", "matching_synonym", "matching_name", "countries"],
	\@moved_rows);

write_csv("xcheck_examples.csv",
	["code", "listed", "in_T", "affected_tags", "tags_added", "tags_removed", "input_tags"],
	\@xcheck_rows);

open(my $COUNTS, '>', "$output_dir/counts.txt") or die;
print $COUNTS "$_\t$count{$_}\n" for sort keys %count;
close $COUNTS;
print STDERR "$_: $count{$_}\n" for sort keys %count;
