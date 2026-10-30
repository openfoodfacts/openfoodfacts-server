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
use utf8;

my $usage = <<TXT
list_changed_taxonomy_entries.pl - list taxonomy entries that were renamed or reparented between two git revisions

Products that have those entries in their _tags field need to be reprocessed so that
their tags (and the parents of their tags) are recomputed.

- renamed entries: the old canonical id is no longer the canonical id of an entry.
  Products still have the old id, so it is output with a trailing ! so that
  update_all_products.pl uses it as-is instead of canonicalizing it to the new id.
- reparented entries: the canonical id did not change, but its parents changed.

Children of renamed or reparented entries do not need to be listed: products
in child categories also have the parent in their _tags field.

Usage:

list_changed_taxonomy_entries.pl --type categories --from v2.113.0 [--to HEAD] [--list]

--from	git revision or file path of the old version of the taxonomy (required)
--to	git revision or file path of the new version of the taxonomy (default: the current working tree)

git is not installed in the backend container: export the old version of the taxonomy on the host first, e.g.
git show v2.113.0:taxonomies/food/categories.txt > categories.v2.113.0.txt
and then use --from categories.v2.113.0.txt (and --to with a file exported the same way if the taxonomies directory is not available)
--list	output one id per line instead of a value for update_all_products.pl --query

Details about the changes are printed on STDERR.

Example:

ids=\$(./scripts/taxonomies/list_changed_taxonomy_entries.pl --type categories --from v2.113.0)
./scripts/update_all_products.pl --fields categories --key reprocess_categories_v2.117.0 --query "categories_tags=\$ids"
TXT
	;

use ProductOpener::Store qw/get_string_id_for_lang/;

use Encode qw/decode/;
use Getopt::Long;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

my $type = 'categories';
my $from;
my $to;
my $list = 0;

GetOptions(
	"type=s" => \$type,
	"from=s" => \$from,
	"to=s" => \$to,
	"list" => \$list,
) or die("Error in command line arguments.\n\n$usage");

defined $from or die("--from is required.\n\n$usage");

# Taxonomy files are in taxonomies/ or taxonomies/food/ etc.
# Only needed when --from or --to is not a file path
my $taxonomies_dir = $0;
$taxonomies_dir =~ s/scripts\/taxonomies\/[^\/]+$/taxonomies/;
my $path;

sub get_taxonomy_path() {
	if (not defined $path) {
		($path) = grep {-e "$taxonomies_dir/$_"} ("$type.txt", map {"$_/$type.txt"} qw(food beauty petfood product));
		defined $path or die("Could not find the taxonomy file for type $type in $taxonomies_dir\n");
		$path = "taxonomies/$path";
	}
	return $path;
}

sub read_taxonomy_file ($revision) {
	my $content;
	if ((defined $revision) and (-f $revision)) {
		open(my $fh, "<", $revision) or die("Could not read $revision: $!\n");
		local $/;
		$content = <$fh>;
		close($fh);
	}
	elsif (defined $revision) {
		my $path = get_taxonomy_path();
		$content = `git show '$revision:$path'`;
		$? == 0 or die("Could not read $path at revision $revision\n");
	}
	else {
		my $path = get_taxonomy_path();
		open(my $fh, "<", "$taxonomies_dir/../$path") or die("Could not read $path: $!\n");
		local $/;
		$content = <$fh>;
		close($fh);
	}
	return decode("UTF-8", $content);
}

# Parse a taxonomy file:
# - canonical id of each entry (from the first language line of the entry)
# - parents of each entry (as written in the file)
# - synonyms: lc:synonym id -> canonical id, to resolve parents
sub parse_taxonomy ($content) {

	my %entries = ();
	my %synonyms = ();

	foreach my $block (split(/\n\s*\n/, $content)) {
		my $canonical;
		my @parents = ();
		foreach my $line (split(/\n/, $block)) {
			$line =~ s/^\s+|\s+$//g;
			next if $line =~ /^#/;
			if ($line =~ /^<\s*(.*)$/) {
				push @parents, $1;
			}
			# skip stopwords:, synonyms: and properties (e.g. wikidata:en:)
			elsif ($line =~ /^([a-z]{2}):\s*(.*)$/) {
				my ($lc, $names) = ($1, $2);
				$names =~ s/\s*#.*$//;
				my @ids = map {"$lc:" . get_string_id_for_lang($lc, $_)} grep {/\S/} split(/\s*,\s*/, $names);
				next if not @ids;
				$canonical //= $ids[0];
				$synonyms{$_} //= $canonical foreach @ids;
			}
		}
		$entries{$canonical} = \@parents if defined $canonical;
	}

	# Resolve parents to canonical ids
	foreach my $canonical (keys %entries) {
		$entries{$canonical} = [
			sort map {
				my ($lc, $name) = /^([a-z]{2}):\s*(.*)$/ ? ($1, $2) : ('en', $_);
				my $id = "$lc:" . get_string_id_for_lang($lc, $name);
				$synonyms{$id} // $id
			} @{$entries{$canonical}}
		];
	}

	return (\%entries, \%synonyms);
}

my ($old_entries_ref, $old_synonyms_ref) = parse_taxonomy(read_taxonomy_file($from));
my ($new_entries_ref, $new_synonyms_ref) = parse_taxonomy(read_taxonomy_file($to));

my @ids = ();

foreach my $id (sort keys %$old_entries_ref) {

	if (not defined $new_entries_ref->{$id}) {
		my $new_id = $new_synonyms_ref->{$id} // "(removed)";
		print STDERR "renamed: $id -> $new_id\n";
		push @ids, "$id!";
		next;
	}

	# Map the old parents to the new canonical ids, so that renamed parents are not counted as reparentings
	my $old_parents = join(",", sort map {$new_synonyms_ref->{$_} // $_} @{$old_entries_ref->{$id}});
	my $new_parents = join(",", @{$new_entries_ref->{$id}});
	if ($old_parents ne $new_parents) {
		print STDERR "reparented: $id: [$old_parents] -> [$new_parents]\n";
		push @ids, $id;
	}
}

print STDERR scalar(@ids) . " entries changed between $from and " . ($to // "the working tree") . "\n";

print join($list ? "\n" : "|", @ids) . "\n";
