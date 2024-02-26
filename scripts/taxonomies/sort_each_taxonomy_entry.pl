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

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;

my $is_check = grep {$_ eq "--check"} @ARGV;
my $is_verbose = grep {$_ eq "-v"} @ARGV;
my $has_changes = 0;

binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

sub cmp_on_language ($$) {
	my $a = shift;
	my $b = shift;
	if ((!defined $a) || (!defined $b)) {
		return $a cmp $b;
	}
	$a = lc($a);
	$b = lc($b);
	my $a_prefix = undef;
	my $b_prefix = undef;
	if ($a =~ /^(\w+):(\w+)$/) {
		$a_prefix = $1;
		$a = $2;
	}
	if ($b =~ /^(\w+):(\w+)$/) {
		$b_prefix = $1;
		$b = $2;
	}
	if ($a_prefix && $b_prefix) {
		return $a_prefix cmp $b_prefix if ($a_prefix ne $b_prefix);
	}
	return 0 if ($a eq $b);
	# en takes precedence over all others
	return -1 if ($a eq "en");
	return 1 if ($b eq "en");
	return $a cmp $b;
}

# read all in memory to take care of last line in a simple way
my @lines = (<STDIN>);

# be sure to end with a blank line
push @lines, "\n" unless $lines[-1] =~ /^\s*$/;

my @parents = ();
my %entries = ();
my %props = ();
my @previous_lines = ();
my @original_lines = ();
my $line_num = 0;
my $entry_start_line = 1;
foreach my $line (@lines) {
	$line_num += 1;
	push @original_lines, $line;    # collect lines for comparison

	# blank line means we are changing entry, so let's print collected lines
	if ($line =~ /^\s*$/) {
		my @output_lines = ();
		# sort items
		@parents = sort {$a->{line} cmp $b->{line}} @parents;
		my @sorted_entries = sort cmp_on_language (keys %entries);
		my @sorted_props = sort cmp_on_language (keys %props);
		# print parents, entrie, sorted props
		for my $parent (@parents) {
			push @output_lines, @{$parent->{previous}};
			push @output_lines, $parent->{line};
		}
		for my $key (@sorted_entries) {
			push @output_lines, @{$entries{$key}->{previous}};
			push @output_lines, $entries{$key}->{line};
		}
		for my $key (@sorted_props) {
			push @output_lines, @{$props{$key}->{previous}};
			push @output_lines, $props{$key}->{line};
		}
		# print remaining previous_lines (if any)
		push @output_lines, @previous_lines;
		# print this blank line
		push @output_lines, $line;
		my $original = join("", @original_lines);
		my $output = join("", @output_lines);
		if ($is_check) {
			# compare with original lines
			if (not $original eq $output) {
				$has_changes = 1;
				if ($is_verbose) {
					print "Error: output is not the same as original, line $entry_start_line..$line_num\n";
					print "Original --------------------\n";
					print "$original\n";
					print "Sorted --------------------\n";
					print "$output\n";
				}
			}
		}
		else {
			print "$output";
		}
		# re-init
		@parents = ();
		%entries = ();
		%props = ();
		@previous_lines = ();
		@original_lines = ();
		$entry_start_line = $line_num;
	}
	# parents
	elsif ($line =~ /^</) {
		push @parents, {line => $line, previous => [@previous_lines]};
		@previous_lines = ();
	}
	# synonym
	elsif ($line =~ /^(\w+):[^:]*(,.*)*$/) {
		my $lc = $1;
		$entries{$lc} = {line => $line, previous => [@previous_lines]};
		@previous_lines = ();
	}
	# property
	elsif ($line =~ /^(\w+):(\w+):(.*)$/) {
		my $prop = $1;
		my $lc = $2;
		$props{"$prop:$lc"} = {line => $line, previous => [@previous_lines]};
		@previous_lines = ();
	}
	# comments or undefined
	else {
		push @previous_lines, $line;
	}
}

exit($is_check and $has_changes);
