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


sub cmp_on_language :prototype($$) ($a, $b) {
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
	# en and xx takes precedence over all others
	return -1 if ($a eq "xx");
	return 1 if ($b eq "xx");
	return -1 if ($a eq "en");    # because of lines above, $b ne xx
	return 1 if ($b eq "en");    # because of lines above, $a ne xx
	return $a cmp $b;
}

sub iter_taxonomy_lines($fd) {
	my $last_line;
	# iterator
	return sub {
		while (my $line = <$fd>) {
			$last_line = $line;
			return $line;
		}
		# be sure to end with a blank line
		unless ($last_line =~ /^\s*$/) {
			$last_line = "\n";  # make next call terminate
			return "\n";
		}
		# end of iterator
		return;
	}
}


sub iter_taxonomy_entries ($lines_iter) {
	my $line_num = 0;  # this is global
	return sub {
		# re-init at start and after returning each entry
		my @parents = ();    # lines defining parents
		my $entry_id_line = undef;    # line defining entry id, we don't want to change it's position
		my %entries = ();    # lines defining synonyms
		my %props = ();    # lines defining properties
		my @original_lines = ();
		# non meaningful lines above a meaningful line (entry, parent or porperty)
		my @previous_lines = ();
		my $entry_start_line = $line_num + 1;
		while (my $line = $lines_iter->()) {
			$line_num += 1;
			push @original_lines, $line;    # collect lines for comparison

			# blank line means we are changing entry, so let's return collected data
			if ($line =~ /^\s*$/) {
				my $entry = {
					parents => \@parents,
					entry_id_line => $entry_id_line,
					entries => \%entries,
					props => \%props,
					original_lines => \@original_lines,
					tail_lines => \@previous_lines,
					start_line => $entry_start_line,
					end_line => $line_num,
				};
				# return $entry
				return $entry;
			}
			# parents
			elsif ($line =~ /^</) {
				push @parents, {line => $line, previous => [@previous_lines]};
				@previous_lines = ();
			}
			# synonym
			elsif ($line =~ /^(\w+):[^:]*(,.*)*$/) {
				if (!defined $entry_id_line) {
					$entry_id_line = {line => $line, previous => [@previous_lines], lc => $1};
				}
				else {
					my $lc = $1;
					if ((defined $entries{$lc}) || ($entry_id_line->{lc} eq $lc)) {
						# emit a warning as this seems like a strange case
						print STDERR "Warning: duplicate synonym for $lc, on entry line $line_num\n";
						print STDERR "- " . ($entries{$lc}{line} // $entry_id_line->{line});
						print STDERR "- " . $line;
					}
					# but try to do our best and continue
					if (defined $entries{$lc}) {
						$entries{$lc}{line} = $entries{$lc}{line} . $line;
						push @{$entries{$lc}{previous}}, @previous_lines;
					}
					else {
						$entries{$lc} = {line => $line, previous => [@previous_lines]};
					}
				}
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
		# end of iterator
		return;
	}
}

sub lint_taxonomy($entries_iterator, $is_check, $is_verbose) {
	my $has_changes = 0;
	while (my $entry_ref = $entries_iterator->()) {
		my @parents = @{$entry_ref->{parents}};
		my $entry_id_line = $entry_ref->{entry_id_line};
		my %entries = %{$entry_ref->{entries}};
		my %props = %{$entry_ref->{props}};
		my @original_lines = @{$entry_ref->{original_lines}};
		my @tail_lines = @{$entry_ref->{tail_lines}};
		my $entry_start_line = $entry_ref->{start_line};
		my $entry_end_line = $entry_ref->{end_line};
		# eventual result
		my @output_lines = ();
		# sort items
		@parents = sort {$a->{line} cmp $b->{line}} @parents;
		my @sorted_entries = sort cmp_on_language (keys %entries);
		my @sorted_props = sort cmp_on_language (keys %props);
		# print parents, line id, synonyms, sorted props
		for my $parent (@parents) {
			push @output_lines, @{$parent->{previous}};
			push @output_lines, $parent->{line};
		}
		if (defined $entry_id_line) {
			push @output_lines, @{$entry_id_line->{previous}};
			push @output_lines, $entry_id_line->{line};
		}
		for my $key (@sorted_entries) {
			push @output_lines, @{$entries{$key}->{previous}};
			push @output_lines, $entries{$key}->{line};
		}
		for my $key (@sorted_props) {
			push @output_lines, @{$props{$key}->{previous}};
			push @output_lines, $props{$key}->{line};
		}
		push @output_lines, @tail_lines;
		# print a blank line
		push @output_lines, "\n";
		my $original = join("", @original_lines);
		my $output = join("", @output_lines);
		if ($is_check) {
			# compare with original lines
			if (not $original eq $output) {
				$has_changes = 1;
				if ($is_verbose) {
					print "Error: output is not the same as original, line $entry_start_line..$entry_end_line\n";
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
	}
	return $has_changes;
}

unless (caller) {
	# main
	my $is_check = grep {$_ eq "--check"} @ARGV;
	my $is_verbose = grep {$_ eq "-v"} @ARGV;

	binmode(STDIN, ":encoding(UTF-8)");
	binmode(STDOUT, ":encoding(UTF-8)");
	binmode(STDERR, ":encoding(UTF-8)");

	my $entries_iterator = iter_taxonomy_entries(iter_taxonomy_lines(*STDIN));
	my $has_changes = lint_taxonomy($entries_iterator, $is_check, $is_verbose);
	exit($is_check and $has_changes);
}
