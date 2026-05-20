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

use Modern::Perl '2017';
use utf8;
use feature 'signatures';
no warnings 'experimental::signatures';
use Term::ANSIColor;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;

my $tagtype = $ARGV[0] // '*';
my $publish = $ARGV[1] // 1;

my $IS_GITHUB_CI = $ENV{GITHUB_ACTIONS} // 0;

sub print_group ($name) {
	if ($IS_GITHUB_CI) {
		print "::group::$name\n";
	}
	else {
		print "\n" . colored("--- $name ---", 'bold blue') . "\n";
	}
	return;
}

sub print_endgroup () {
	if ($IS_GITHUB_CI) {
		print "::endgroup::\n";
	}
	else {
		print "\n";
	}
	return;
}

sub print_error ($msg) {
	if ($IS_GITHUB_CI) {
		print STDERR "::error::$msg\n";
	}
	else {
		print STDERR colored("ERROR: ", 'red'), "$msg\n";
	}
	return;
}

sub print_success ($msg) {
	print colored("$msg", 'green bold'), "\n";
	return;
}

sub print_info ($msg) {
	print colored("$msg", 'bold'), "\n";
	return;
}

print_info("Building tags taxonomy (tagtype: $tagtype)");

my $has_any_errors = 0;

if ($tagtype eq '*') {
	print_group("Building all taxonomies");
	my $errors_ref = ProductOpener::Tags::build_all_taxonomies($publish);
	foreach my $taxonomy (sort keys %{$errors_ref}) {
		if (@{$errors_ref->{$taxonomy}}) {
			print_error((scalar @{$errors_ref->{$taxonomy}}) . " errors while building $taxonomy taxonomy");
			$has_any_errors = 1;
		}
	}
	if (!$has_any_errors) {
		print_success("All taxonomies built successfully");
	}
	print_endgroup();
}
else {
	print_group("Building $tagtype taxonomy");
	my @errors = ProductOpener::Tags::build_tags_taxonomy($tagtype, $publish);
	if (@errors) {
		print_error((scalar @errors) . " errors while building $tagtype taxonomy");
		$has_any_errors = 1;
	}
	else {
		print_success("$tagtype taxonomy built successfully");
	}
	print_endgroup();
}

if ($has_any_errors) {
	print_error("Completed with errors");
	exit(1);
}

exit(0);
