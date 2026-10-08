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

# Remove the entries of a taxonomy source file that have no associated product.
#
# The product counts are computed by streaming the full Open Food Facts products export
# (https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz) and counting the
# "<tagtype>_tags" arrays: those arrays already contain all the ancestors of each tag
# (see compute_field_tags() in lib/ProductOpener/ProductsTags.pm), so an entry whose
# descendants have products has a product count of its own.
#
# The filtered taxonomy is written to a separate output file: the taxonomy source file is
# never modified in place.

use ProductOpener::PerlStandards;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS get_files_for_taxonomy/;
use ProductOpener::Tags qw/%translations_from canonicalize_taxonomy_tag sanitize_taxonomy_line/;

use File::Basename qw/basename/;
use Getopt::Long qw/GetOptions/;
use JSON::MaybeXS qw/decode_json/;

use constant DEFAULT_EXPORT_URL => 'https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz';

my $usage = <<'EOF';
Usage: remove_entries_without_products.pl [options]

  --tagtype=categories        taxonomy to process (default: categories)
  --product-type=food         product type used to locate the taxonomy source file
                              (default: the configured product type)
  --taxonomy-file=path        taxonomy source file to filter (default: the first file
                              returned by get_files_for_taxonomy(tagtype, product type))
  --jsonl-file=path           local export file, .jsonl or .jsonl.gz
                              (default: $BASE_DIRS{PRIVATE_DATA}/openfoodfacts-products.jsonl.gz)
  --url=url                   URL of the export to download (default: the Open Food Facts
                              openfoodfacts-products.jsonl.gz export)
  --download                  download the export to --jsonl-file if it does not exist yet
  --min-products=n            keep the entries that have at least n products (default: 1)
  --drop-unresolved           drop the blocks whose entry name cannot be canonicalized
                              (default: keep them)
  --keep=tag[,tag...]         always keep these entries (canonical tagid or entry name)
  --ignore-property=prop[:lc] keep the entries that define this taxonomy property
                              (eg. --ignore-property=protected_name_type:en, or
                              --ignore-property=protected_name_type to match any language)
  --keep-entries-with-children keep the entries that are parents of at least one other
                              entry (have at least one child), regardless of their product
                              count
  --output-file=path          write the filtered taxonomy there (default: stdout)
  --report-file=path          write the kept / removed list there (default: stderr)
  --dry-run                   do everything except writing the filtered taxonomy
  --quiet                     do not list the kept and removed entries
  --verbose                   display progress information
EOF

# Read a taxonomy source file and split it into blocks of consecutive non-empty lines.
# A blank line separates two entries, as expected by build_tags_taxonomy().
# Each block is a hashref with:
# - start_line: line number of the first line of the block, to display error messages
# - lines: arrayref with the raw lines of the block (without the trailing empty line)
# - lc: language code of the entry line, undef if the block has no entry line
# - name: entry name (first field of the entry line, before the first comma), undef if the
#   block has no entry line
# - canon_tagid: canonical tagid of the entry, or the un-canonicalized tagid if the entry
#   name could not be matched to the taxonomy
# - canon_tagid_exists: 0 if the entry name could not be matched to the taxonomy
sub read_taxonomy_blocks($taxonomy_file, $tagtype) {

	my @blocks = ();

	open(my $IN, "<:encoding(UTF-8)", $taxonomy_file)
		or die("Cannot open $taxonomy_file: $!\n");

	my @current_lines = ();
	my $current_start_line = 1;
	my $line_number = 0;

	while (my $line = <$IN>) {
		$line_number++;
		if ($line =~ /\S/) {
			if (!@current_lines) {
				$current_start_line = $line_number;
			}
			push @current_lines, $line;
		}
		elsif (@current_lines) {
			# pass a copy of the lines, as @current_lines is reset for the next block
			push @blocks, compute_block([@current_lines], $current_start_line, $tagtype);
			@current_lines = ();
		}
	}
	if (@current_lines) {
		push @blocks, compute_block([@current_lines], $current_start_line, $tagtype);
	}

	close($IN);

	return \@blocks;
}

# Compute the entry name and canonical tagid of a block of taxonomy lines.
# Follows the same rules as build_tags_taxonomy() in lib/ProductOpener/Tags.pm:
# - empty lines, comments (#) and parents (<) are ignored
# - the first remaining line that starts with a language code (or synonyms:<lc>) defines
#   the entry
# - the line is sanitized (this turns escaped commas \, into lower commas ‚) before being
#   split on commas, and the first field is the entry name
sub compute_block($lines_ref, $start_line, $tagtype) {

	my $block_ref = {
		start_line => $start_line,
		lines             => $lines_ref,
		lc                => undef,
		name              => undef,
		canon_tagid       => undef,
		canon_tagid_exists => 0,
		properties        => {},
		parents           => [],
	};

	foreach my $line (@$lines_ref) {

		my $sanitized_line = sanitize_taxonomy_line($line);

		next if ($sanitized_line =~ /^\s*$/);
		next if ($sanitized_line =~ /^#/);

		if ($sanitized_line =~ /^<\s+(\w\w):\s*(.+)$/) {

			# a parent declaration line such as < en: teas ; the parent is canonicalized
			# the same way as in build_tags_taxonomy() in lib/ProductOpener/Tags.pm
			my ($lc, $parent_line) = ($1, $2);
			my ($parent_name) = split(/\s*,\s*/, $parent_line);
			$parent_name = "" if not defined $parent_name;
			$parent_name =~ s/^\s+//;
			$parent_name =~ s/\s+$//;
			if ($parent_name ne "") {
				push @{$block_ref->{parents}}, canonicalize_taxonomy_tag($lc, $tagtype, $parent_name);
			}
		}
		elsif ($sanitized_line =~ /^(?:synonyms:)?(\w\w):\s*(.*)$/) {

			my ($lc, $entry_line) = ($1, $2);

			# Only the first <language> tag of the block is the entry name, the following
			# lines are translations of the same entry
			if (!defined $block_ref->{name}) {
				my ($name) = split(/\s*,\s*/, $entry_line);
				$name = "" if not defined $name;
				$name =~ s/^\s+//;
				$name =~ s/\s+$//;

				$block_ref->{lc} = $lc;
				$block_ref->{name} = $name;

				if ($name ne "") {
					my $exists_in_taxonomy = 0;
					$block_ref->{canon_tagid} = canonicalize_taxonomy_tag($lc, $tagtype, $name, \$exists_in_taxonomy);
					$block_ref->{canon_tagid_exists} = $exists_in_taxonomy;
				}
			}
		}
		elsif ($sanitized_line =~ /^([\w-]+):(\w\w):\s*(.+)$/) {

			# a property line such as protected_name_type:en: pgi or wikidata:en: Q123
			$block_ref->{properties}{$1}{$2} = $3;
		}
	}

	return $block_ref;
}

# Count the products per taxonomy tagid by streaming the Open Food Facts products export.
# Returns a hashref with:
# - products_per_tagid: raw tagid (as stored on the products) => number of products
# - products_count: number of products that have at least one tag
# - line_count: number of lines read from the export
# The export is gzipped or plain JSON Lines, and is read with a pipe to gzip -dc if needed,
# in the same way as iter_products_from_jsonl() in scripts/generate_madenearme_page.pl.
sub count_products_per_tagid($jsonl_file, $tagtype, $verbose) {

	my $field = $tagtype . "_tags";

	my $fh;
	if ($jsonl_file =~ /\.gz$/) {
		open($fh, "-|", "gzip", "-dc", "--", $jsonl_file)
			or die("Cannot open pipe to gzip -dc $jsonl_file: $!\n");
	}
	else {
		open($fh, "<:encoding(UTF-8)", $jsonl_file) or die("Cannot open $jsonl_file: $!\n");
	}

	my %products_per_tagid = ();
	my $products_count = 0;
	my $line_count = 0;

	while (my $line = <$fh>) {

		$line_count++;

		if ($verbose and not($line_count % 500000)) {
			print STDERR "$line_count lines, $products_count products with $field\n";
		}

		# Skip the lines that do not have the field at all, without parsing the whole json
		next if ($line !~ /"\Q$field\E"\s*:/);
		next if ($line !~ /"\Q$field\E"\s*:\s*(\[[^\]]*\])/);

		my $tags = eval {decode_json($1)};
		if (ref($tags) ne 'ARRAY') {
			next;
		}

		$products_count++;

		# A product can have the same tag several times: count the product only once
		my %tags_counted = ();
		foreach my $tagid (@$tags) {
			next if $tags_counted{$tagid};
			$tags_counted{$tagid} = 1;
			$products_per_tagid{$tagid}++;
		}
	}

	if (!close($fh)) {
		die("Error reading $jsonl_file (gzip exit status: " . ($? >> 8) . ")\n");
	}

	if ($verbose) {
		print STDERR "$line_count lines, $products_count products with $field\n";
	}

	return {
		products_per_tagid => \%products_per_tagid,
		products_count => $products_count,
		line_count => $line_count,
	};
}

# Products may still have tags that are not canonical anymore (eg. en:Groceries or
# de:Eistee), as products keep their categories_tags when a taxonomy entry is renamed.
# Map those tags to their canonical tagid, using the translations_from map of the taxonomy.
# Returns a hashref with:
# - products_per_canon_tagid: canonical tagid => number of products
# - remapped_tagids: arrayref with the "raw tagid => canonical tagid" that were remapped
# - unknown_tagids: arrayref with the raw tagids that are not in the taxonomy at all
sub canonicalize_products_per_tagid($products_per_tagid, $tagtype) {

	my %products_per_canon_tagid = ();
	my @remapped_tagids = ();
	my @unknown_tagids = ();

	foreach my $tagid (sort keys %$products_per_tagid) {

		my $canon_tagid = $tagid;

		if (not defined $translations_from{$tagtype}{$tagid}) {
			# The tag is not a canonical tagid of the taxonomy: try to match the string
			# that is after the language prefix to a taxonomy entry
			if ($tagid =~ /^(\w\w):(.+)$/) {
				my ($lc, $name) = ($1, $2);
				my $exists_in_taxonomy = 0;
				$canon_tagid = canonicalize_taxonomy_tag($lc, $tagtype, $name, \$exists_in_taxonomy);
				if ($exists_in_taxonomy) {
					push @remapped_tagids, "$tagid => $canon_tagid";
				}
				else {
					push @unknown_tagids, $tagid;
				}
			}
			else {
				push @unknown_tagids, $tagid;
			}
		}
		else {
			$canon_tagid = $translations_from{$tagtype}{$tagid};
		}

		$products_per_canon_tagid{$canon_tagid} += $products_per_tagid->{$tagid};
	}

	return {
		products_per_canon_tagid => \%products_per_canon_tagid,
		remapped_tagids => \@remapped_tagids,
		unknown_tagids => \@unknown_tagids,
	};
}

# Compute the list of blocks to keep and to remove.
# A block is kept if:
# - it has no entry line (comments, section headers)
# - or its entry name could not be canonicalized (unless $drop_unresolved is true)
# - or its entry is in the list of tags to always keep
# - or it has one of the ignored properties (e.g. protected_name_type:en: pgi)
# - or the number of products of its canonical tagid is >= $min_products
# Blocks are dropped otherwise.
sub select_blocks($blocks_ref, $products_per_canon_tagid, $parameters_ref) {

	my $min_products = $parameters_ref->{min_products};
	my $drop_unresolved = $parameters_ref->{drop_unresolved};
	my $keep_tags = $parameters_ref->{keep_tags};
	my $ignore_properties = $parameters_ref->{ignore_properties};
	my $parent_tagids = $parameters_ref->{parent_tagids};

	my @kept_blocks = ();
	my @removed_blocks = ();
	my %stats = (with_products => 0, kept_unresolved => 0, kept_forced => 0,
		kept_for_property => 0, kept_for_children => 0, no_entry => 0);

	foreach my $block_ref (@$blocks_ref) {

		my $canon_tagid = $block_ref->{canon_tagid};
		my $products = 0;
		if (defined $canon_tagid) {
			$products = $products_per_canon_tagid->{$canon_tagid} // 0;
		}
		$block_ref->{products} = $products;

		if (!defined $block_ref->{name}) {
			# Comments and section headers have no entry: always keep them
			$stats{no_entry}++;
			push @kept_blocks, $block_ref;
		}
		elsif (!$block_ref->{canon_tagid_exists}) {
			if ($drop_unresolved) {
				push @removed_blocks, $block_ref;
			}
			else {
				$stats{kept_unresolved}++;
				push @kept_blocks, $block_ref;
			}
		}
		elsif ($keep_tags->{$canon_tagid}) {
			$stats{kept_forced}++;
			push @kept_blocks, $block_ref;
		}
		elsif (block_has_ignored_property($block_ref, $ignore_properties)) {
			$stats{kept_for_property}++;
			push @kept_blocks, $block_ref;
		}
		elsif (defined $parent_tagids && defined $canon_tagid && $parent_tagids->{$canon_tagid}) {
			$stats{kept_for_children}++;
			push @kept_blocks, $block_ref;
		}
		elsif ($products >= $min_products) {
			$stats{with_products}++;
			push @kept_blocks, $block_ref;
		}
		else {
			push @removed_blocks, $block_ref;
		}
	}

	return (\@kept_blocks, \@removed_blocks, \%stats);
}

# A block matches an ignore spec such as "protected_name_type:en" or "protected_name_type"
# (any language) or "protected_name_type:" (any language, explicitly empty).
sub block_has_ignored_property($block_ref, $ignore_properties) {

	return 0 if !@$ignore_properties;

	foreach my $spec (@$ignore_properties) {

		my ($property, $language) = split(/:/, $spec, 2);

		if (not defined $language) {
			# any language
			return 1 if (defined $block_ref->{properties}{$property});
		}
		else {
			# "property:" (empty language) matches any language of that property
			return 1 if (defined $block_ref->{properties}{$property}{$language});
		}
	}

	return 0;
}

# Write the kept blocks, separated by a single empty line.
sub write_blocks($blocks_ref, $out_file) {

	my $OUT;
	if (!defined $out_file) {
		$OUT = \*STDOUT;
	}
	else {
		open($OUT, ">:encoding(UTF-8)", $out_file) or die("Cannot write $out_file: $!\n");
	}

	my $first = 1;
	foreach my $block_ref (@$blocks_ref) {
		if (!$first) {
			print $OUT "\n";
		}
		$first = 0;
		print $OUT @{$block_ref->{lines}};
	}

	if (!defined $out_file) {
		print $OUT "\n";
	}
	else {
		close($OUT) or die("Cannot close $out_file: $!\n");
	}

	return;
}

# Download the export file, unless it has already been downloaded.
sub download_export($url, $jsonl_file) {

	# Download to a temporary file first, so that an interrupted download does not leave
	# a truncated file that the next run would consider as valid
	my $tmp_file = $jsonl_file . ".download";

	print STDERR "Downloading $url to $tmp_file\n";

	my $return_value = system("curl", "-fL", "--retry", "3", "-o", $tmp_file, "--", $url);
	if ($return_value != 0) {
		unlink($tmp_file);
		die("Download of $url failed\n");
	}

	rename($tmp_file, $jsonl_file) or die("Cannot rename $tmp_file to $jsonl_file: $!\n");

	return;
}

sub format_file_size($size) {
	my @units = ('B', 'kB', 'MB', 'GB', 'TB');
	my $index = 0;
	while (($size >= 1024) and ($index < $#units)) {
		$size /= 1024;
		$index++;
	}
	return sprintf("%.1f %s", $size, $units[$index]);
}

my $tagtype = "categories";
my $product_type = $options{product_type} // "food";
my $taxonomy_file;
my $jsonl_file = "$BASE_DIRS{PRIVATE_DATA}/openfoodfacts-products.jsonl.gz";
my $url = DEFAULT_EXPORT_URL;
my $download = 0;
my $min_products = 1;
my $drop_unresolved = 0;
my @keep_tags = ();
my @ignore_properties = ();
my $keep_with_children = 0;
my $output_file;
my $report_file;
my $dry_run = 0;
my $quiet = 0;
my $verbose = 0;

GetOptions(
	"tagtype=s" => \$tagtype,
	"product-type=s" => \$product_type,
	"taxonomy-file=s" => \$taxonomy_file,
	"jsonl-file=s" => \$jsonl_file,
	"url=s" => \$url,
	"download" => \$download,
	"min-products=i" => \$min_products,
	"drop-unresolved" => \$drop_unresolved,
	"keep=s" => \@keep_tags,
	"ignore-property=s" => \@ignore_properties,
	"keep-entries-with-children" => \$keep_with_children,
	"output-file=s" => \$output_file,
	"report-file=s" => \$report_file,
	"dry-run" => \$dry_run,
	"quiet" => \$quiet,
	"verbose" => \$verbose,
) or die("Error in command line arguments.\n\n" . $usage);

if ($min_products < 0) {
	die("Invalid --min-products value: $min_products\n");
}

if (!defined $taxonomy_file) {
	my @files = get_files_for_taxonomy($tagtype, $product_type);
	if (scalar @files == 0) {
		die("No taxonomy file found for $tagtype (product type: $product_type)\n\n" . $usage);
	}
	$taxonomy_file = "$BASE_DIRS{TAXONOMIES_SRC}/" . $files[0];
}

if (!defined $taxonomy_file) {
	die("No taxonomy file to process.\n");
}
if (!-e $taxonomy_file) {
	die("Taxonomy file $taxonomy_file does not exist.\n");
}

# Turn the --keep values into a hash of canonical tagids
my %keep_tags = ();
foreach my $keep_tag (@keep_tags) {
	foreach my $tag (split(/\s*,\s*/, $keep_tag)) {
		if ($tag =~ /^(\w\w):/) {
			$keep_tags{$tag} = 1;
		}
		else {
			# Assume English if there is no language prefix
			$keep_tags{canonicalize_taxonomy_tag("en", $tagtype, $tag)} = 1;
		}
	}
}

if (!-e $jsonl_file) {
	if (!$download) {
		die("Products export $jsonl_file does not exist, use --download to get it.\n");
	}
	download_export($url, $jsonl_file);
}

if ($verbose) {
	print STDERR "Counting products per $tagtype tag\n";
}

my $counts_ref = count_products_per_tagid($jsonl_file, $tagtype, $verbose);

if ($verbose) {
	print STDERR "Mapping " . scalar(keys %{$counts_ref->{products_per_tagid}}) . " tagids to canonical tagids\n";
}

my $canon_counts_ref = canonicalize_products_per_tagid($counts_ref->{products_per_tagid}, $tagtype);

if ($verbose) {
	print STDERR "Reading $taxonomy_file\n";
}

	my $blocks_ref = read_taxonomy_blocks($taxonomy_file, $tagtype);

	# When --keep-entries-with-children is set, collect the canonical tagids that are
	# referenced as a parent (< en: name) by at least one other block. These entries have
	# at least one child and are kept regardless of their product count.
	my %parent_tagids = ();
	if ($keep_with_children) {
		foreach my $block_ref (@$blocks_ref) {
			foreach my $parent_id (@{$block_ref->{parents}}) {
				$parent_tagids{$parent_id} = 1;
			}
		}
	}

	my ($kept_blocks_ref, $removed_blocks_ref, $stats_ref) = select_blocks(
		$blocks_ref,
		$canon_counts_ref->{products_per_canon_tagid},
		{min_products => $min_products, drop_unresolved => $drop_unresolved, keep_tags => \%keep_tags,
		ignore_properties => \@ignore_properties, parent_tagids => \%parent_tagids}
	);

if (!$dry_run) {
	write_blocks($kept_blocks_ref, $output_file);
}

my $removed_lines = 0;
foreach my $block_ref (@{$removed_blocks_ref}) {
	$removed_lines += scalar @{$block_ref->{lines}};
}

# Display the summary and the list of kept / removed entries

my $report;
if (defined $report_file) {
	open($report, ">:encoding(UTF-8)", $report_file) or die("Cannot write $report_file: $!\n");
}
else {
	$report = \*STDERR;
}

printf $report "tagtype: %s\n", $tagtype;
printf $report "taxonomy file: %s\n", $taxonomy_file;
printf $report "products export: %s (%s)\n", $jsonl_file, format_file_size(-s $jsonl_file);
printf $report "lines read: %d\n", $counts_ref->{line_count};
printf $report "products with %s: %d\n", $tagtype . "_tags", $counts_ref->{products_count};
printf $report "distinct tagids: %d (remapped from non canonical ids: %d, unknown: %d)\n",
	scalar(keys %{$counts_ref->{products_per_tagid}}), scalar(@{$canon_counts_ref->{remapped_tagids}}),
	scalar(@{$canon_counts_ref->{unknown_tagids}});
printf $report "blocks: %d\n", scalar @{$blocks_ref};
printf $report "kept: %d (with products: %d, always kept: %d, kept for ignored property: %d, kept for children: %d, unresolved: %d, without entry: %d)\n",
	scalar @{$kept_blocks_ref}, $stats_ref->{with_products}, $stats_ref->{kept_forced},
	$stats_ref->{kept_for_property}, $stats_ref->{kept_for_children}, $stats_ref->{kept_unresolved},
	$stats_ref->{no_entry};
printf $report "removed: %d (%d lines)\n", scalar @{$removed_blocks_ref}, $removed_lines;
printf $report "min-products: %d\n", $min_products;
if (@ignore_properties) {
	printf $report "ignore-properties: %s\n", join(",", @ignore_properties);
}
printf $report "keep-entries-with-children: %s\n", $keep_with_children ? "yes" : "no";

unless ($quiet) {
	foreach my $block_ref (@{$removed_blocks_ref}) {
		printf $report "removed\t%s:%d\t%s\t%d products\n", $taxonomy_file, $block_ref->{start_line},
			$block_ref->{canon_tagid} // "", $block_ref->{products} // 0;
	}
	foreach my $block_ref (@{$kept_blocks_ref}) {
		next if (!defined $block_ref->{canon_tagid});
		next if ($block_ref->{products} > $min_products);
		printf $report "kept\t%s:%d\t%s\t%d products\n", $taxonomy_file, $block_ref->{start_line},
			$block_ref->{canon_tagid}, $block_ref->{products};
	}
	foreach my $tagid (@{$canon_counts_ref->{unknown_tagids}}) {
		printf $report "unknown tagid\t%s\t%s products\n", $tagid, $counts_ref->{products_per_tagid}{$tagid};
	}
}

if (defined $report_file) {
	close($report) or die("Cannot close $report_file: $!\n");
}

exit(0);
