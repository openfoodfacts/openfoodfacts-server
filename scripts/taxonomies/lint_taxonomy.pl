#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2024 Association Open Food Facts
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

use Data::Compare;
use File::Basename qw/basename dirname/;
use File::Copy qw/move/;
use File::Temp;
use Getopt::Long qw/GetOptions/;
use List::Util qw/first/;

use ProductOpener::Tags qw/%taxonomy_fields %translations_from canonicalize_taxonomy_tag sanitize_taxonomy_line/;

# return true if $errors_ref list contains at least one error (as opposed to only warnings)
sub has_errors($errors_ref) {
	return !!(first {lc($_->{severity}) eq "error"} @$errors_ref);
}

# compare synonyms entries on language prefix with "xx" > "en" then alpha order
# also work for property name + language prefix
sub cmp_on_language : prototype($$) ($a, $b) {
	if ((!defined $a) || (!defined $b)) {
		return $a cmp $b;
	}
	$a = lc($a);
	$b = lc($b);
	my $a_prefix = undef;
	my $b_prefix = undef;
	# case of property name: <name>:<lang>
	if ($a =~ /^(\w+):(\w+)$/) {
		$a_prefix = $1;
		$a = $2;
	}
	if ($b =~ /^(\w+):(\w+)$/) {
		$b_prefix = $1;
		$b = $2;
	}
	if ($a_prefix && $b_prefix) {
		# property name is the first item to sort on
		return $a_prefix cmp $b_prefix if ($a_prefix ne $b_prefix);
	}
	# compare on language code
	return 0 if ($a eq $b);
	# en and xx takes precedence over all others
	return -1 if ($a eq "xx");
	return 1 if ($b eq "xx");
	return -1 if ($a eq "en");    # because of lines above, $b ne xx
	return 1 if ($b eq "en");    # because of lines above, $a ne xx
	return $a cmp $b;
}

# simple iterator on lines, ensuring last line is empty (to simplify getting last entry)
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
			$last_line = "\n";    # make next call terminate
			return "\n";
		}
		# end of iteratorsanitize_taxonomy_line
		return;
	}
}

# iter over the taxonomy entry by entry
# return a ref to a hash map with entry infos
sub iter_taxonomy_entries ($lines_iter) {
	my $line_num = 0;    # this is global
	return sub {
		# re-init at start and after returning each entry
		my @parents = ();    # lines defining parents
		my $entry_id_line = undef;    # line defining entry id, we don't want to change it's position
		my %entries = ();    # lines defining synonyms
		my %props = ();    # lines defining properties
		my @original_lines = ();
		# non meaningful lines above a meaningful line (entry, parent or porperty)
		my @previous_lines = ();
		my @errors = ();
		my $entry_start_line = $line_num + 1;
		while (my $line = $lines_iter->()) {
			$line_num += 1;
			push @original_lines, $line;    # collect lines for comparison

			# blank line means we are changing entry, so let's return collected data
			if ($line =~ /^\s*$/) {
				push(@previous_lines, "\n");
				my $entry = {
					type => "entry",
					parents => \@parents,
					entry_id_line => $entry_id_line,
					entries => \%entries,
					props => \%props,
					original_lines => \@original_lines,
					tail_lines => \@previous_lines,
					start_line => $entry_start_line,
					end_line => $line_num,
					errors => \@errors,
				};
				add_entry_id($entry, \@errors);
				# return $entry
				return $entry;
			}
			# stopwords and synonyms
			elsif ($line =~ /^(?<prefix>synonyms|stopwords):/i) {
				# synonyms and stopwords are special, return entry immediatly,
				# but verify values are as expected.
				my $entry_type = $+{prefix};
				my @checks = ();
				push(@checks, "Parents before a $entry_type line\n") if @parents;
				push(@checks, "$entry_type in the midst of a entry $entry_id_line->{line}\n") if $entry_id_line;
				push(@checks, "$entry_type surrounded by other lines") if (%entries || %props);
				for my $err (@checks) {
					push(
						@errors,
						{
							severity => "Error",
							type => "Correctness",
							line => $line_num,
							message => ($err),
						}
					);
				}
				my $entry = {
					type => $entry_type,
					parents => [],
					entry_id_line =>
						{line => $line, previous => [@previous_lines], line_num => $line_num, type => $entry_type},
					entries => {},
					props => {},
					original_lines => \@original_lines,
					tail_lines => [],
					start_line => $entry_start_line,
					end_line => $line_num,
					errors => \@errors,
				};
				add_entry_id($entry, \@errors);
				# return $entry
				return $entry;
			}
			# parents
			elsif ($line =~ /^</) {
				# if we already have an entry id, parent are not at the good position,
				# and it might mean two entries where merged inadvertantly (eg. by an auto merge)
				if ($entry_id_line) {
					push(
						@errors,
						{
							severity => "Error",
							type => "Correctness",
							line => $line_num,
							message => (
									  "Parent in the middle of an entry, might mean erroneous merge of two entries:\n"
									. "- $line"
							)
						}
					);
				}
				push @parents, {line => $line, previous => [@previous_lines], line_num => $line_num, type => "parent"};
				@previous_lines = ();
			}
			# synonym
			elsif ($line =~ /^(\w+):[^:]*(,.*)*$/) {
				if (!defined $entry_id_line) {
					$entry_id_line = {
						line => $line,
						previous => [@previous_lines],
						lc => $1,
						line_num => $line_num,
						type => "entry_id"
					};
				}
				else {
					my $lc = $1;
					if ((defined $entries{$lc}) || ($entry_id_line->{lc} eq $lc)) {
						my $previous_lc_line;
						if (defined $entries{$lc}) {
							$previous_lc_line = $entries{$lc}{line};
						}
						else {
							$previous_lc_line = $entry_id_line->{line};
						}

						push @errors,
							{
							severity => "Error",
							type => "Correctness",
							line => $line_num,
							message => ("duplicate language line for $lc:\n" . "- $previous_lc_line" . "- $line")
							};
					}
					# but try to do our best and continue
					if (defined $entries{$lc}) {
						$entries{$lc}{line} = $entries{$lc}{line} . $line;
						push @{$entries{$lc}{previous}}, @previous_lines;
					}
					else {
						$entries{$lc}
							= {line => $line, previous => [@previous_lines], line_num => $line_num, type => "entry_lc"};
					}
				}
				@previous_lines = ();
			}
			# property
			elsif ($line =~ /^(\w+):(\w{2}):(.*)$/) {
				my $prop = $1;
				my $lc = $2;
				if (defined $props{"$prop:$lc"}) {
					push(
						@errors,
						{
							severity => "Error",
							type => "Correctness",
							line => $line_num,
							message => (
									  "duplicate property language line for $prop:$lc:\n" . "- "
									. $props{"$prop:$lc"}->{line}
									. "- $line"
							)
						}
					);
				}
				# override to continue
				$props{"$prop:$lc"}
					= {line => $line, previous => [@previous_lines], line_num => $line_num, type => "property"};
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

# make entry properties that reference a taxonomy use the canonical id
sub canonicalize_entry_properties($entry_ref, $is_check) {
	return unless (defined $entry_ref->{entry_id_line});    # not a regular entry
	my @errors = ();
	my %props = %{$entry_ref->{props}};
	for my $prop_name (keys %props) {
		# If the property name matches the name of an already loaded taxonomy,
		# canonicalize the property values for the corresponding synonym
		# e.g. if an additive has a class additives_classes:en: en:stabilizer (a synonym),
		# we can map it to en:stabiliser (the canonical name in the additives_classes taxonomy)
		my ($property, $lc) = split(/:/, $prop_name);
		my $prop_tagtype = $taxonomy_fields{$property};
		if ((defined $prop_tagtype) && (exists $translations_from{$prop_tagtype})) {
			my $prop_value = substr($props{$prop_name}{line}, length($prop_name) + 1);
			my $value = $prop_value;
			$value =~ s/^\s*//;
			$value = sanitize_taxonomy_line($value);
			my @values = split(/\s*,\s*/, $value);
			# check values exists in taxonomy and canonicalize
			my @canon_values = ();
			my @not_found = ();
			my %different = ();    # better track it to display only differing values
			foreach my $v (@values) {
				my $exists;
				my $canon_value = canonicalize_taxonomy_tag($lc, $prop_tagtype, $v, \$exists);
				push(@canon_values, $canon_value);
				push(@not_found, $canon_value) unless $exists;
				$different{$v} = $canon_value if $canon_value ne $v;
			}
			if (@not_found) {
				my $not_found = join(",", @not_found);
				push(
					@errors,
					{
						severity => "Warning",
						type => "Consistency",
						entry_start_line => $entry_ref->{start_line},
						entry_id_line => $entry_ref->{entry_id_line}{line},
						message => (
							"Values $not_found do not exists in taxonomy $prop_tagtype, at $props{$prop_name}{line_num}\n"
								. "- $props{$prop_name}{line}"
						),
					}
				);
			}
			if (%different) {
				if ($is_check) {
					# values changed this is an error
					push(
						@errors,
						{
							severity => "Error",
							type => "Linting",
							entry_start_line => $entry_ref->{start_line},
							entry_id_line => $entry_ref->{entry_id_line}{line},
							message => (
									  "Property $prop_name is not canonical, at $props{$prop_name}{line_num}\n" . "- "
									. join(", ", keys %different) . "\n" . "- "
									. join(", ", values %different) . "\n"
							),
						}
					);
				}
				else {
					# replace value to lint
					$props{$prop_name}{line} = "$prop_name: " . join(", ", @canon_values) . "\n";
				}
			}
		}
	}
	return @errors;
}

# add some info about entry in errors
sub add_entry_id($entry_ref, $errors_ref) {
	my @errors = @$errors_ref;
	foreach my $e (@errors) {
		$e->{entry_start_line} = $entry_ref->{start_line};
		my $entry_id_line = $entry_ref->{entry_id_line};
		$e->{entry_id_line} = $entry_id_line->{line} if defined $entry_id_line;
	}
	return;
}

# lint lines of an entry
sub lint_entry($entry_ref, $do_sort) {
	my @parents = @{$entry_ref->{parents}};
	my $entry_id_line = $entry_ref->{entry_id_line};
	my %entries = %{$entry_ref->{entries}};
	my %props = %{$entry_ref->{props}};
	my @original_lines = @{$entry_ref->{original_lines}};
	my @tail_lines = @{$entry_ref->{tail_lines}};
	# eventual result
	my @output_lines = ();
	# sort items
	my (@sorted_entries, @sorted_props);
	if ($do_sort) {
		@parents = sort {$a->{line} cmp $b->{line}} @parents;
		@sorted_entries = sort cmp_on_language (keys %entries);
		@sorted_props = sort cmp_on_language (keys %props);
	}
	else {
		# simply sort by line number, no need to sort parents
		@sorted_entries = sort {$entries{$a}{line_num} <=> $entries{$b}{line_num}} (keys %entries);
		@sorted_props = sort {$props{$a}{line_num} <=> $props{$b}{line_num}} (keys %props);
	}
	# print parents, line id, synonyms, sorted props
	for my $parent (@parents) {
		push @output_lines, @{$parent->{previous}};
		push @output_lines, normalized_line($parent);
	}
	if (defined $entry_id_line) {
		push @output_lines, @{$entry_id_line->{previous}};
		push @output_lines, normalized_line($entry_id_line);
	}
	for my $key (@sorted_entries) {
		push @output_lines, @{$entries{$key}->{previous}};
		push @output_lines, normalized_line($entries{$key});
	}
	for my $key (@sorted_props) {
		push @output_lines, @{$props{$key}->{previous}};
		push @output_lines, normalized_line($props{$key});
	}
	push @output_lines, @tail_lines;
	return join("", @output_lines);
}

# normalize spaces on a line
sub normalized_line($entry) {
	my $line = $entry->{line};
	my $normalize_commas
		= (    ($entry->{type} eq "entry_lc")
			|| ($entry->{type} eq "entry_id")
			|| ($entry->{type} eq "synonyms")
			|| ($entry->{type} eq "stopwords"));
	# insure exactly one space after line prefix
	if ($entry->{type} eq "parent") {
		$line =~ s/^< */< /;
	}
	elsif (($entry->{type} eq "property") || ($entry->{type} eq "stopwords") || ($entry->{type} eq "synonyms")) {
		# property_name:lang: or line_type:lang:
		$line =~ s/^([^:]+):([^:]+): */$1:$2: /;
	}
	else {
		# entry_id or entry_lc just have language
		$line =~ s/^([^:]+): */$1: /;
	}
	# remove trailing space at end of line
	$line =~ s/ +$//g;
	if ($normalize_commas) {
		# remove multiple commas
		$line =~ s/,+/,/g;
		# remove trailing space and comma at end of line
		$line =~ s/[ ,]+$//g;
		# first replace special cases by a lower comma
		# but if is escape or within a number
		# in numbers
		$line =~ s/(\d),(\d)/$1‚$2/g;
		# escaped comma \,
		$line =~ s/\\,/\\‚/g;
		# ensure exactly one space after commas
		$line =~ s/,( )*/, /g;
		# put back lower comma
		$line =~ s/‚/,/g;
	}
	return $line;
}

# check that an entry is already sorted, compared to $sorted_output
sub check_linted($entry_ref, $linted_output) {
	# compare with original lines
	my $original = join("", @{$entry_ref->{original_lines}});
	my $entry_start_line = $entry_ref->{start_line};
	my $entry_end_line = $entry_ref->{end_line};
	# do not account for eventual added line at the end
	my $trimed_original = $original;
	$trimed_original =~ s/\n+$//;
	my $trimed_linted = $linted_output;
	$trimed_linted =~ s/\n+$//;
	if ($trimed_original ne $trimed_linted) {
		return {
			severity => "Error",
			type => "Linting",
			entry_start_line => $entry_start_line,
			entry_id_line => $entry_ref->{entry_id_line},
			message => (
					  "output is not the same as original, line $entry_start_line..$entry_end_line\n"
					. "Original --------------------\n"
					. "$original\n"
					. "Linted --------------------\n"
					. "$linted_output\n"
			),
		};
	}
	return;
}

# lint or check the taxonomy
sub lint_taxonomy($entries_iterator, $out, $is_check, $is_quiet, $do_sort) {
	my @errors = ();
	while (my $entry_ref = $entries_iterator->()) {
		my @entry_errors = @{$entry_ref->{errors}};
		my @canon_errors = canonicalize_entry_properties($entry_ref, $is_check);
		push(@entry_errors, @canon_errors) if @canon_errors;
		# we will try to lint only if we don't have errors so far
		my $linted_output;
		if (!has_errors(\@entry_errors)) {
			$linted_output = lint_entry($entry_ref, $do_sort);
		}
		else {
			# keep original lines
			$linted_output = join("", @{$entry_ref->{original_lines}});
		}
		if ($is_check) {
			# search for linting error only if there is no other errors
			if (!@entry_errors) {
				my $lint_error = check_linted($entry_ref, $linted_output);
				push(@entry_errors, $lint_error) if $lint_error;
			}
		}
		else {
			# immediate output
			print $out $linted_output;
			if (has_errors(\@entry_errors)) {
				# signal it was not linted
				push(
					@entry_errors,
					{
						severity => "Warning",
						type => "Linting",
						entry_start_line => $entry_ref->{start_line},
						entry_id_line => $entry_ref->{entry_id_line}{line},
						message => (
								  "Entry won't be linted because it has errors, "
								. "line $entry_ref->{start_line}..$entry_ref->{end_line}\n"
						),
					}
				);
			}
		}
		# register errors globally
		@errors = (@errors, @entry_errors);
		display_errors(\@entry_errors) unless $is_quiet;
	}
	return \@errors;
}

# display errors
sub display_errors($errors_ref) {
	foreach my $error (@$errors_ref) {
		my $entry_id_line = $error->{entry_id_line};
		my $entry_id = "";
		if ($entry_id_line) {
			$entry_id = (split(/,/, $entry_id_line))[0];
			# trim
			$entry_id =~ s/(^\s+|\s+$)//g;
			if ($entry_id) {
				$entry_id = " on $entry_id";
			}
		}
		my $entry_line = $error->{entry_start_line} ? " (line $error->{entry_start_line})" : "";
		print STDERR "$error->{severity}($error->{type}):$entry_id$entry_line\n";
		print STDERR "$error->{message}\n";
	}
	return;
}

# run the program only if called directly
unless (caller) {
	# main

	my $usage = <<TXT
Check or lint taxonomies.

If an error is encountered on an entry, this part of the taxonomy won't be linted (as it is risky)

--check: only perform checks
--verbose: print additional info about progress on stderr
--quiet: do not display errors on stderr
--no-sort: do not sort lines of each taxonomy entries
TXT
		;
	my $is_check;
	my $is_quiet;
	my $is_verbose;
	my $no_sort;

	GetOptions("check" => \$is_check, "verbose" => \$is_verbose, "quiet" => \$is_quiet, "no-sort" => \$no_sort)
		or die("Error in command line arguments.\n\n" . $usage);

	my @in_files = @ARGV;
	my $tmp_dir = File::Temp->newdir();
	my $tmp_dirname = $tmp_dir->dirname();

	if (!@in_files) {
		# we will use stdin
		@in_files = ("<",);
	}

	binmode(STDIN, ":encoding(UTF-8)");
	binmode(STDOUT, ":encoding(UTF-8)");
	binmode(STDERR, ":encoding(UTF-8)");

	my $error_code = 0;

	foreach my $file (@in_files) {
		my $fd;
		my $out;
		my $out_path;
		if ($file eq "<") {
			$fd = *STDIN;
			$out = *STDOUT;
		}
		else {
			open($fd, "<:encoding(UTF-8)", $file) or die("can't open $file");
			# out to tempfile, will replace only if no errors
			$out_path = "$tmp_dirname/" . basename($file);
			open($out, ">:encoding(UTF-8)", $out_path) or die("can't write to $out_path");
			print("Processing $file =============\n\n") if $is_verbose;
		}
		my $entries_iterator = iter_taxonomy_entries(iter_taxonomy_lines($fd));
		my $errors_ref = lint_taxonomy($entries_iterator, $out, $is_check, $is_quiet, !$no_sort);
		close($fd);
		close($out);
		if ((!$is_check) and $out_path) {
			# $file = (getcwd() . "/$file") unless ($file =~ /^\//);
			# replace file with the linted one
			move($out_path, $file) or die("unable to move $out_path to $file: $!");
		}
		# do we have errors (and not only warnings)
		if (has_errors($errors_ref)) {
			$error_code = 1;
		}
	}
	exit($error_code);
}
1;
