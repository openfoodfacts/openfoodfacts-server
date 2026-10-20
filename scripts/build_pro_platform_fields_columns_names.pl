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

use ProductOpener::PerlStandards;
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Producers qw/:all/;
use ProductOpener::Lang qw/@Langs/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::ProducerMappingsCache qw/mappings_cache_valid write_mappings_cache_manifest/;
use File::Path qw/remove_tree/;
use Term::ANSIColor;

sub print_error ($msg) {
	print STDERR colored("error: ", 'red'), "$msg\n";
	return;
}

sub print_info ($msg) {
	print colored("$msg", 'bold'), "\n";
	return;
}

sub print_success ($msg) {
	print colored("$msg", 'green bold'), "\n";
	return;
}

my $is_terminal = -t STDOUT;    ## no critic (InputOutput::ProhibitInteractiveTest) - we don't want to add progress output to logs
my $built_count = 0;
my $total_count = scalar @Langs;

sub print_status ($language) {
	my $label = "Building ($built_count/$total_count): ";
	$label = colored($label, 'bold green') if $is_terminal;
	print $label . "$language\n";
	return;
}

print_info("Building producer column mappings for $total_count languages");

if ($total_count == 0) {
	print_error("No languages found. Run scripts/build_lang.pl before building producer column mappings.");
	exit(1);
}

# CI opts in with a key covering the source inputs and runtime build configuration.
# Include the runtime configuration so other flavors cannot reuse OFF mappings.
my $cache_key = $ENV{PRODUCER_MAPPINGS_CACHE_KEY} // '';
my $cache_directory = "$BASE_DIRS{CACHE_BUILD}/pro";
if ($cache_key ne '') {
	$cache_key = join(':',
		$cache_key,
		$ENV{PRODUCT_OPENER_FLAVOR_SHORT},
		$server_options{producers_platform} // 0,
		$server_domain);
	if (mappings_cache_valid($cache_directory, $cache_key, \@Langs)) {
		print_success("Using cached producer column mappings for $total_count languages");
		exit(0);
	}

	# Invalidate before writing anything: failed or interrupted builds must never be cache hits.
	if (-e "$cache_directory/manifest.sha256") {
		unlink("$cache_directory/manifest.sha256") or die("Cannot invalidate producer mappings cache: $!\n");
	}
	remove_tree("$cache_directory/fields_column_names");
}

# Generate the files that match potential column names from producers to OFF fields
my $has_any_errors = 0;
foreach my $l (@Langs) {
	print_status($l);

	my $success = eval {
		build_fields_columns_names_for_lang($l);
		1;
	};

	$built_count++;
	if (!$success) {
		$has_any_errors = 1;
		my $error = $@ || "unknown error";
		chomp $error;
		print_error("Failed to build producer column mappings for $l: $error");
	}
}

if (!$has_any_errors) {
	write_mappings_cache_manifest($cache_directory, $cache_key, \@Langs) if $cache_key ne '';
	print_success("All producer column mappings built successfully");
}

exit($has_any_errors ? 1 : 0);
