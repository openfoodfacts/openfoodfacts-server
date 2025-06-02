#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;
use Time::HiRes qw/gettimeofday/;

use ProductOpener::PerlStandards;
use ProductOpener::Store qw/read_json write_json write_canonical_json retrieve store store_config retrieve_config/;
use ProductOpener::Paths qw/%BASE_DIRS/;

# Performance test.
# Directory scanning version
sub update_products($dir, $code, $mode) {
	my $count = 0;
	opendir DH, "$dir" or die "could not open $dir directory: $!\n";
	my @files = readdir(DH);
	closedir DH;
	foreach my $entry (sort @files) {
		next if $entry =~ /^\.\.?$/;
		my $file_path = "$dir/$entry";

		if (-d $file_path) {
			$count += update_products($file_path, "$code$entry", $mode);
			next;
		}

		# Only do change files as the product files are just links
		if ($entry =~ /\d+\.sto/) {
			# print STDERR "$mode: $file_path\n";
			if ($mode eq 'STORABLE') {
				# Load and save the STO file
				my $product = retrieve($file_path);
				store($file_path, $product);
				$count += 1;
			}
			elsif ($mode eq 'STO_TO_JSON') {
				# Load the STO file and save as JSON
				my $product = retrieve($file_path);
				my $stripped_path = substr($file_path, 0, -4);
				write_json("$stripped_path.json", $product);
				$count += 1;
			}
		}
		elsif ($entry =~ /\d+\.json/) {
			my $stripped_path = substr($file_path, 0, -5);
			if ($mode eq 'JSON_TO_JSON') {
				# Load the JSON file and save as JSON
				my $product = read_json($file_path);
				write_json($file_path, $product);
				$count += 1;
			}
			elsif ($mode eq 'CLEANUP') {
				# Delete the JSON file
				unlink($file_path);
				$count += 1;
			}
		}
	}

	return $count;
}

sub run_for_mode($mode) {
	my $started_t = gettimeofday();
	my $count = update_products($BASE_DIRS{PRODUCTS}, '', $mode);
	print STDERR "$mode: $count files in " . (gettimeofday() - $started_t) . " s\n";

	return;
}

# Read taxonomies. First convert to JSON non-destructively
sub read_taxonomies($mode) {
	my $count = 0;
	my $started_t = gettimeofday();
	my $dir = "$BASE_DIRS{CACHE_BUILD}/taxonomies-result";
	opendir(DH, $dir);
	my @files = readdir(DH);
	closedir(DH);
	foreach my $entry (sort @files) {
		my $file_path = "$dir/$entry";
		if ($entry =~ /.*result\.sto$/) {
			if ($mode eq "CLEANUP") {
				unlink($file_path);
				$count++;
			}
			elsif ($mode eq "STORABLE") {
				my $ref = retrieve($file_path);
				$count++;
			}
		}
		elsif ($entry =~ /.*result\.json$/) {
			if ($mode eq "PREPARE") {
				# Load the JSON file and save as STO
				my $ref = read_json($file_path);
				my $stripped_path = substr($file_path, 0, -5);
				store("$stripped_path.sto", $ref);
				$count++;
			}
			elsif ($mode eq 'JSON') {
				my $ref = read_json($file_path);
				$count++;
			}
		}
	}
	print STDERR "$mode: Read all $count taxonomy files in " . (gettimeofday() - $started_t) . " s\n";

	return;
}

read_taxonomies('PREPARE');
read_taxonomies('JSON');
read_taxonomies('STORABLE');
read_taxonomies('CLEANUP');

run_for_mode('STORABLE');
run_for_mode('STO_TO_JSON');
run_for_mode('JSON_TO_JSON');
run_for_mode('CLEANUP');
