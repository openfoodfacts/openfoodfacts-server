#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;
use Time::HiRes qw/gettimeofday/;
use YAML::XS qw/Load Dump/;
# use YAML::Syck qw/Load Dump/;

use ProductOpener::PerlStandards;
use ProductOpener::Store qw/store_object retrieve_object retrieve store/;
use ProductOpener::Paths qw/%BASE_DIRS/;

# Serializes an object in our preferred object store, removing it from legacy storage if it is present
# It looks like YAML sorts keys by default...
sub store_config ($path, $ref, $delete_old = 1) {
	my $new_path = $path =~ s/\.sto$/\.yaml/ri;
	if (open(my $OUT, ">", $new_path)) {
		print $OUT Dump($ref);
		close($OUT);

		# Delete the old file if it was a storable
		if ($delete_old and $path =~/.*\.sto/ and -e $path) {
			unlink($path);
		}
	}
	# TODO Handle errors
}

sub retrieve_config($path) {
	my $new_path = $path =~ s/\.sto$/\.yaml/ri;
	if (-e $new_path) {
		if (open(my $IN, "<", $new_path)) {
			local $/;    #Enable 'slurp' mode
			my $ref = Load(<$IN>);
			close($IN);
			return $ref;
		}
	}
	# Fallback to old method
	return retrieve($path);
}


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
		if ($entry =~ /\d+\.[sto|json]/) {
			# print STDERR "$mode: $file_path\n";
			if ($mode eq 'BENCHMARK') {
				# Just load each file
				my $product = retrieve($file_path);
			}
			elsif ($mode eq 'STORABLE') {
				# Load and save the STO file
				my $product = retrieve($file_path);
				store($file_path, $product);
			}
			elsif ($mode eq 'STO_TO_JSON') {
				# Load the STO file and save as JSON
				my $product = retrieve_object($file_path);
				store_object($file_path, $product);
			}
			elsif ($mode eq 'JSON_TO_JSON') {
				# Load the JSON file and save as JSON
				my $product = retrieve_object($file_path);
				store_object($file_path, $product);
			}
			elsif ($entry =~ /.*\.json/) {
				# Restore the STO file
				my $product = retrieve_object($file_path);
				if ($product) {
					store($file_path =~ s/\.json$/\.sto/ri, $product);
				}
				unlink($file_path);
			}
			$count += 1;
		}
	}

	return $count;
}

sub run_for_mode($mode) {
	my $started_t = gettimeofday();
	my $count = update_products($BASE_DIRS{PRODUCTS}, '', $mode);
	print STDERR "$mode: $count files in " . (gettimeofday() - $started_t) . " s\n";
}

# Read taxonomies. First convert to JSON non-destructively
sub read_taxonomies($mode) {
	my $started_t = gettimeofday();
	my $dir = $BASE_DIRS{TAXONOMIES_SRC};
	opendir(DH, $dir);
	my @files = readdir(DH);
	closedir(DH);
	foreach my $entry (sort @files) {
		my $file_path = "$dir/$entry";
		if ($entry =~ /.*\.sto/) {
			if ($mode eq "PREPARE") {
				# Load the STO file and save as YAML
				my $ref = retrieve_config($file_path);
				store_object($file_path, $ref, 0);    # Non-destructive store
				store_config($file_path, $ref, 0);    # Non-destructive store
			}
			elsif ($mode eq "STORABLE") {
				my $ref = retrieve($file_path);
			}
		}
		elsif ($entry =~ /.*\.json/) {
			if ($mode eq "CLEANUP") {
				unlink($file_path);
			}
			elsif ($mode eq 'JSON') {
				my $ref = retrieve_object($file_path);
			}
		}
		elsif ($entry =~ /.*\.yaml/) {
			if ($mode eq "CLEANUP") {
				unlink($file_path);
			}
			elsif ($mode eq 'YAML') {
				my $ref = retrieve_config($file_path);
			}
		}
	}
	print STDERR "$mode: Read all taxonomy files in " . (gettimeofday() - $started_t) . " s\n";
}

#read_taxonomies('PREPARE');
read_taxonomies('STORABLE');
read_taxonomies('JSON');
read_taxonomies('YAML');
#read_taxonomies('CLEANUP');

# run_for_mode('BENCHMARK');
# run_for_mode('STORABLE');
# run_for_mode('STO_TO_JSON');
# run_for_mode('JSON_TO_JSON');
# run_for_mode('CLEANUP');

