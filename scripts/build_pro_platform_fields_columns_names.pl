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
	print_success("All producer column mappings built successfully");
}

exit($has_any_errors ? 1 : 0);
