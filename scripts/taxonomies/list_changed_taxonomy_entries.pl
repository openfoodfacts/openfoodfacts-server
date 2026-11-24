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

list_changed_taxonomy_entries.pl --types categories[,labels,origins,brands] --from v2.113.0 [--to HEAD] [--list]

--types	comma separated list of taxonomies (default: categories), --type is an alias
--from	git revision, file path or directory of the old version of the taxonomies (required)
--to	git revision, file path or directory of the new version of the taxonomies (default: the current working tree)
--list	output one id per line instead of a value for update_all_products.pl --query

A file path can only be used with one type. A directory must contain files named [type].txt (e.g. categories.txt)

If git is not installed in the backend container: export the old version of the taxonomies on the host first, e.g.
mkdir taxonomies.v2.113.0
git show v2.113.0:taxonomies/food/categories.txt > taxonomies.v2.113.0/categories.txt
git show v2.113.0:taxonomies/labels.txt > taxonomies.v2.113.0/labels.txt
and then use --from taxonomies.v2.113.0 (and --to with files exported the same way if the taxonomies directory is not available)

With one type, the output is the value for update_all_products.pl --query [type]_tags=...
With several types, the output is one line [type]_tags=[value] for each type that has changes.

Details about the changes are printed on STDERR.

Some taxonomies are built from several files (e.g. origins also includes countries.txt), but only the [type].txt file is read:
an entry that was moved to another file is reported as removed. It is still listed, so that products are reprocessed.

Examples:

ids=\$(./scripts/taxonomies/list_changed_taxonomy_entries.pl --type categories --from v2.113.0)
./scripts/update_all_products.pl --fields categories --key reprocess_categories_v2.117.0 --query "categories_tags=\$ids"

./scripts/taxonomies/list_changed_taxonomy_entries.pl --types categories,labels,origins,brands --from v2.113.0 \\
| while read query; do
	type=\${query%%_tags=*}
	./scripts/update_all_products.pl --fields \$type --key reprocess_\${type}_v2.117.0 --query "\$query"
done
TXT
	;

use ProductOpener::Store qw/get_string_id_for_lang/;

use Encode qw/decode/;
use Getopt::Long;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

my $types = 'categories';
my $from;
my $to;
my $list = 0;

GetOptions(
	"types|type=s" => \$types,
	"from=s" => \$from,
	"to=s" => \$to,
	"list" => \$list,
) or die("Error in command line arguments.\n\n$usage");

defined $from or die("--from is required.\n\n$usage");

my @types = split(/\s*,\s*/, $types);

foreach my $revision ($from, $to) {
	if ((defined $revision) and (-f $revision) and (scalar @types > 1)) {
		die("A file path can only be used with one type, use a directory with [type].txt files instead.\n\n$usage");
	}
}

# Taxonomy files are in taxonomies/ or taxonomies/food/ etc.
# Only needed when --from or --to is not a file path or a directory
my $taxonomies_dir = $0;
$taxonomies_dir =~ s/scripts\/taxonomies\/[^\/]+$/taxonomies/;

sub get_taxonomy_path ($type) {
	my ($path) = grep {-e "$taxonomies_dir/$_"} ("$type.txt", map {"$_/$type.txt"} qw(food beauty petfood product));
	defined $path or die("Could not find the taxonomy file for type $type in $taxonomies_dir\n");
	return "taxonomies/$path";
}

sub read_file ($file) {
	open(my $fh, "<", $file) or die("Could not read $file: $!\n");
	local $/;
	my $content = <$fh>;
	close($fh);
	return $content;
}

sub read_taxonomy_file ($type, $revision) {
	my $content;
	if ((defined $revision) and (-f $revision)) {
		$content = read_file($revision);
	}
	elsif ((defined $revision) and (-d $revision)) {
		$content = read_file("$revision/$type.txt");
	}
	elsif (defined $revision) {
		my $path = get_taxonomy_path($type);
		$content = `git show '$revision:$path'`;
		$? == 0 or die("Could not read $path at revision $revision\n");
	}
	else {
		$content = read_file("$taxonomies_dir/../" . get_taxonomy_path($type));
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

foreach my $type (@types) {

	my ($old_entries_ref, $old_synonyms_ref) = parse_taxonomy(read_taxonomy_file($type, $from));
	my ($new_entries_ref, $new_synonyms_ref) = parse_taxonomy(read_taxonomy_file($type, $to));

	my @ids = ();

	foreach my $id (sort keys %$old_entries_ref) {

		if (not defined $new_entries_ref->{$id}) {
			my $new_id = $new_synonyms_ref->{$id} // "(removed)";
			print STDERR "$type renamed: $id -> $new_id\n";
			push @ids, "$id!";
			next;
		}

		# Map the old parents to the new canonical ids, so that renamed parents are not counted as reparentings
		my $old_parents = join(",", sort map {$new_synonyms_ref->{$_} // $_} @{$old_entries_ref->{$id}});
		my $new_parents = join(",", @{$new_entries_ref->{$id}});
		if ($old_parents ne $new_parents) {
			print STDERR "$type reparented: $id: [$old_parents] -> [$new_parents]\n";
			push @ids, $id;
		}
	}

	print STDERR scalar(@ids) . " $type entries changed between $from and " . ($to // "the working tree") . "\n";

	if (scalar @types == 1) {
		print join($list ? "\n" : "|", @ids) . "\n";
	}
	elsif (scalar @ids > 0) {
		if ($list) {
			print "$type\t$_\n" foreach @ids;
		}
		else {
			print "${type}_tags=" . join("|", @ids) . "\n";
		}
	}
}
