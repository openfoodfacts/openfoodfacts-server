#!/usr/bin/perl

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

=head1 NAME

convert_product_schema_dump - convert product records in a JSONL dump between schema versions

=head1 SYNOPSIS

  convert_product_schema_dump.pl [--to-version N] [--output FILE] [--verbose] <input.jsonl | ->

Reads a MongoDB product dump in JSONL format (one product per line),
converts each product record to the target schema version using
ProductOpener::ProductSchemaChanges::convert_product_schema, and writes
the converted record as one JSON line to STDOUT (or to --output FILE).

The input file path is mandatory. Pass "-" to read from STDIN.

Errors are reported to STDERR and do not abort the run; offending records
are skipped. At the end, a summary and the list of skipped product codes
are printed to STDERR.

=cut

use ProductOpener::PerlStandards;
use Getopt::Long;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/$json_for_objects/;
use ProductOpener::ProductSchemaChanges qw/$current_schema_version convert_product_schema/;

# _strip_nul_characters_from_json is not in Store.pm's @EXPORT_OK (leading-underscore
# convention); call it via its fully-qualified package name instead.
my $strip_nul = \&ProductOpener::Store::_strip_nul_characters_from_json;

# Run state shared across the processing functions.
my $verbose = 0;
my $line_number = 0;
my $converted_count = 0;
my $error_count = 0;
my @skipped;    # array of [code, line, error_message]
my $out;    # output filehandle (file via --output, or STDOUT)

# Validate the --to-version argument: must be a positive integer, warn if outside
# the known conversion band [998..$current_schema_version].
sub validate_target_version ($target_version) {
	if ($target_version < 1) {
		die "Invalid --to-version: must be a positive integer (got $target_version)\n";
	}
	if ($target_version < 998 || $target_version > $current_schema_version) {
		warn
			"Warning: --to-version $target_version is outside the known schema conversion band [998..$current_schema_version].\n";
	}
	return;
}

# Open the input source: a file given as a positional argument ("-" means STDIN).
# Dies if no argument is provided (avoids silently blocking on STDIN).
# Returns the filehandle (with :raw binmode applied).
sub open_input () {
	my $input_path = shift @ARGV;
	if (not defined $input_path) {
		die "Usage: $0 [--to-version N] [--output FILE] [--verbose] <input.jsonl | ->\n"
			. "Pass '-' as the input filename to read from STDIN.\n";
	}
	my $in;
	if ($input_path eq '-') {
		$in = \*STDIN;
	}
	else {
		open($in, '<', $input_path) or die "Cannot open input file '$input_path': $!\n";
	}
	binmode($in, ':raw');
	return $in;
}

# Decode a JSON line into a product ref.
# Returns ($product_ref, $error_message). On success $error_message is undef.
sub decode_line ($line) {
	my ($product_ref, $error);
	{
		local $@;
		$product_ref = eval {$json_for_objects->decode($line)};
		$error = $@;
	}
	if ($error || !defined $product_ref) {
		$error //= 'decode returned undef';
		chomp $error;
		return (undef, $error);
	}
	return ($product_ref, undef);
}

# Run the schema conversion on a product ref.
# Returns $error_message (undef on success).
sub convert_record ($product_ref, $target_version) {
	my $error;
	{
		local $@;
		eval {convert_product_schema($product_ref, $target_version)};
		$error = $@;
	}
	if ($error) {
		chomp $error;
		return $error;
	}
	return;
}

# Record a skipped record in the error list and, under --verbose, print it live.
sub record_error ($code, $line, $message) {
	push @skipped, [$code, $line, $message];
	$error_count++;
	print STDERR "ERROR line $line code $code: $message\n" if $verbose;
	return;
}

# Open the output sink: a file given via --output, or STDOUT.
# Returns the filehandle (with :raw binmode applied).
sub open_output ($output_path) {
	my $out;
	if (defined $output_path) {
		open($out, '>', $output_path) or die "Cannot open output file '$output_path': $!\n";
	}
	else {
		$out = \*STDOUT;
	}
	binmode($out, ':raw');    # encoder is utf8-flagged, so it produces bytes
	return $out;
}

# Encode a converted product ref to a JSON line and write it to the output sink.
sub emit_record ($product_ref) {
	my $json = $json_for_objects->encode($product_ref);
	$json = $strip_nul->($json);
	print {$out} $json, "\n";
	$converted_count++;
	return;
}

# Process a single raw input line: skip blanks, decode, convert, emit or record error.
sub process_line ($line, $target_version) {
	$line_number++;

	# Strip trailing newline (handle CRLF too).
	$line =~ s/\r?\n$//;

	# Silently skip blank/whitespace-only lines (not counted as reads).
	if ($line =~ /^\s*$/) {
		$line_number--;
		return;
	}

	# Decode the JSON line.
	my ($product_ref, $decode_error) = decode_line($line);
	if ($decode_error) {
		# No decoded ref, so the product code is unknown.
		record_error('UNKNOWN', $line_number, $decode_error);
		return;
	}

	# Best-effort code extraction for error reporting.
	my $code = $product_ref->{code} // 'UNKNOWN';

	# Convert the schema version.
	my $convert_error = convert_record($product_ref, $target_version);
	if ($convert_error) {
		record_error($code, $line_number, $convert_error);
		return;
	}

	# Encode and emit the converted record.
	emit_record($product_ref);
	return;
}

# Print the final summary and the list of skipped product codes to STDERR.
sub print_report () {
	my $read_count = $converted_count + $error_count;
	print STDERR "Summary: $read_count read, $converted_count converted, $error_count errors\n";
	if ($error_count) {
		print STDERR "Skipped product codes ($error_count):\n";
		for my $entry (@skipped) {
			my ($code, $line, $msg) = @$entry;
			if ($verbose) {
				print STDERR "$code\t(line $line: $msg)\n";
			}
			else {
				print STDERR "$code\n";
			}
		}
	}
	return;
}

# --- main ---

my $target_version;
my $output_path;
my $help = 0;

GetOptions(
	'to-version|target-version=i' => \$target_version,
	'output|o=s' => \$output_path,
	'verbose|v' => \$verbose,
	'help|h' => \$help,
) or die "Usage: $0 [--to-version N] [--output FILE] [--verbose] <input.jsonl | ->\n";

if ($help) {
	print STDERR "Usage: $0 [--to-version N] [--output FILE] [--verbose] <input.jsonl | ->\n";
	print STDERR "  --to-version N   Target schema version (default: $current_schema_version)\n";
	print STDERR "  --output FILE     Write converted records to FILE (default: STDOUT)\n";
	print STDERR "  --verbose        Print each error live as it occurs (with message)\n";
	print STDERR "  input.jsonl       Input JSONL dump; pass '-' to read from STDIN\n";
	exit 0;
}

$target_version //= $current_schema_version;
validate_target_version($target_version);

my $is_stdin = (defined $ARGV[0] && $ARGV[0] eq '-');
my $in = open_input();
$out = open_output($output_path);

while (my $line = <$in>) {
	process_line($line, $target_version);
}

close($in) unless $is_stdin;    # close only if we opened a file (STDIN is left alone)
close($out) if defined $output_path;    # close only if we opened a file (STDOUT is left alone)

print_report();

exit($error_count ? 1 : 0);
