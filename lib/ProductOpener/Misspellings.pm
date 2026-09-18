# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
# Contact: contact@openfoodfacts.org
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::Misspellings - Generic misspelling correction module

=head1 SYNOPSIS

  use ProductOpener::Misspellings qw/apply_misspelling_replacements/;

  # Apply corrections from misspellings/ingredients_misspellings.txt
  apply_misspelling_replacements("misspellings", $lc, \$text);

=head1 DESCRIPTION

This module provides generic misspelling correction functionality that can be
used across different fields (ingredients, brands, etc.) to fix common
misspellings found in product data.

Data files are stored in the misspellings/ directory, one file per field.
The filename is derived from the $field parameter: $field . ".txt".

=cut

package ProductOpener::Misspellings;
use ProductOpener::PerlStandards;

use Exporter qw/import/;
use ProductOpener::Paths qw/%BASE_DIRS/;

our @EXPORT_OK = qw/apply_misspelling_replacements init_misspellings/;
our @EXPORT = ();

my %misspellings_cache = ();

=head2 init_misspellings($field)

Loads the misspelling data file misspellings/$field.txt into a cache.
Returns early if already loaded.

=cut

sub init_misspellings ($field) {

	return if defined $misspellings_cache{$field};

	my $file_path = "$BASE_DIRS{MISSPELLINGS_SRC}/${field}_misspellings.txt";
	my %data = ();

	if (defined $file_path && -e $file_path) {
		open(my $IN, "<:encoding(UTF-8)", $file_path)
			or die "Cannot open $file_path: $!";

		while (my $line = <$IN>) {
			chomp $line;
			$line =~ s/#.*$//;
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			next unless $line;

			next unless $line =~ /^([a-z]{2}):([^->]+?)\s*->\s*(.+)$/;
			my ($lang, $misspelled, $correct) = ($1, $2, $3);
			$misspelled =~ s/^\s+//;
			$misspelled =~ s/\s+$//;
			$correct =~ s/^\s+//;
			$correct =~ s/\s+$//;

			push @{$data{$lang}}, [$misspelled, $correct];
		}
		close($IN);
	}

	$misspellings_cache{$field} = \%data;
	return;
}

=head2 apply_misspelling_replacements($field, $lc, $text_ref)

Applies misspelling corrections from misspellings/$field.txt to $text_ref.

Parameters:
- $field: the data file name (without .txt), e.g. "ingredients_misspellings"
- $lc: the language code of the text being processed
- $text_ref: reference to the text string to modify

Matching is case-insensitive. If the target string has mixed case (e.g. "Marks & Spencers"),
it is output as-is regardless of the source case. Otherwise, the source case is preserved.

=cut

sub apply_misspelling_replacements ($field, $lc, $text_ref) {

	return unless $field && $lc && ref($text_ref);

	init_misspellings($field);
	my $misspellings_ref = $misspellings_cache{$field};
	return unless defined $misspellings_ref;

	my @entries = ();
	if (defined $misspellings_ref->{$lc}) {
		push @entries, @{$misspellings_ref->{$lc}};
	}
	if (defined $misspellings_ref->{'xx'}) {
		push @entries, @{$misspellings_ref->{'xx'}};
	}	
	return unless @entries;

	foreach my $pair_ref (@entries) {
		my ($misspelled, $correct) = @$pair_ref;
		my $escaped = quotemeta($misspelled);
		$$text_ref =~ s/\b($escaped)\b/apply_case_to_misspelling($1, $correct)/ieg;
	}
}

=head2 apply_case_to_misspelling($matched, $replacement)

Determines the correct case for the replacement string based on the matched text.

If the replacement has mixed case, it is returned as-is.
Otherwise, the case pattern of the matched text is applied to the replacement:
- all uppercase → all uppercase replacement
- all lowercase → all lowercase replacement
- title case → ucfirst replacement
- otherwise → per-character case preservation

=cut

sub apply_case_to_misspelling ($matched, $replacement) {

	# If target has mixed case, output as-is
	if ($replacement ne lc($replacement) && $replacement ne uc($replacement)) {
		return $replacement;
	}

	# All uppercase source
	if ($matched eq uc($matched)) {
		return uc($replacement);
	}
	# All lowercase source
	elsif ($matched eq lc($matched)) {
		return lc($replacement);
	}
	# Title case source
	elsif ($matched eq ucfirst(lc($matched))) {
		return ucfirst(lc($replacement));
	}
	# Per-character case preservation
	else {
		my @repl_chars = split //, $replacement;
		my @match_chars = split //, $matched;
		my $result = '';
		for my $i (0..$#repl_chars) {
			if (uc($match_chars[$i]) eq $match_chars[$i]) {
				$result .= uc($repl_chars[$i]);
			} else {
				$result .= lc($repl_chars[$i]);
			}
		}
		return $result;
	}
}

1;
