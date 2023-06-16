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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::I18N - Reads the .po files from a certain directory and processes them.

=head1 SYNOPSIS

C<ProductOpener::I18N> is used to read all ".po" files from a certain directory and merge them 
in one hash. The singular & plural entries are separated into two hashes.

=head1 DESCRIPTION

The module implements the functionality to read and process the .po files from a certain directory.
The .po files are read and then merged into a single hash which is then separated into two hashes.
One of these hashes have all plural entries and the other one has all singular entries.
The functions used in this module take the directory to look for the .po files and returns two hashrefs.

=cut

package ProductOpener::I18N;

use strict;
use warnings;
use File::Basename;
use File::Find::Rule;
use Locale::Maketext::Lexicon _auto => 0, _decode => 1, _style => "gettext", _disable_maketext_conversion => 1;
use Locale::Maketext::Lexicon::Getcontext;
use Log::Any qw($log);

my @metadata_fields = qw<
	__Content-Transfer-Encoding
	__Content-Type
	__Language
	__Language-Team
	__Last-Translator
	__MIME-Version
	__PO-Revision-Date
	__Project-Id-Version
	__X-Crowdin-Project
	__X-Crowdin-Language
	__Plural-Forms
	__X-Generator
	__X-Crowdin-File
>;

#
# read_po_files()
# -------------
# args:
# - directory to look for .po files
#
# Read all .po files from a directory, merge everything in one hash,
# returned as a reference to spare the stack.
#

=head1 FUNCTIONS

=head2 read_po_files()

C<read_po_files()> takes directory of the .po files as an input parameter, reads and merges them in one hash
That hash is returned as a reference. (Done to spare the stack) Returning a reference uses a bit less memory since there's no copy.
This function also cleans up the %Lexicon from gettext metadata 
and cleans up the empty values that are put in .po files by Crowdin when the string is not translated.

=head3 Arguments

The directory containing .po files are passed as an argument.

=head3 Return values

Returns a reference to a hash on successful execution.

=cut

sub read_po_files {
	my ($dir) = @_;

	local $log->context->{directory} = $dir;
	$log->debug("Reading po files from disk");

	return unless $dir;

	# remove trailing slash if present
	$dir =~ s/\/$//;

	my %l10n;
	my @files = File::Find::Rule->file->name("*.po")->in($dir . "/");    # Need trailing slash if $dir is a symlink

	for my $file (sort @files) {
		# read the .po file
		local $log->context->{file} = basename($file);
		$log->debug("Reading po file");

		my $lc;

		if ($file =~ /\/(\w\w).po/) {
			$lc = $1;
		}
		else {
			$log->debug("Skipping file (not in [2-letter code].po format)");
			next;
		}

		open my $fh, "<", $file or die $!;
		my %Lexicon = %{Locale::Maketext::Lexicon::Getcontext->parse(<$fh>)};
		close $fh;

		# clean up %Lexicon from gettext metadata
		delete $Lexicon{""};
		delete $Lexicon{$_} for @metadata_fields;

		# move the strings into %l10n
		for my $key (keys %Lexicon) {
			$l10n{$key}{$lc} = delete $Lexicon{$key};

			# Remove empty values that Crowdin puts in .po files when the string is not translated. issue #889
			if ($l10n{$key}{$lc} eq "") {
				delete $l10n{$key}{$lc};
			}
		}
	}

	# for debugging purposes, export the structure

	# use Data::Dumper;
	# $Data::Dumper::Sortkeys = 1;
	# open my $fh, ">", "${dir}/l10n.debug" or die "can not create ${dir}/l10n.debug : $!";
	# print $fh "I18N.pm - read_po_file - dir: $dir\n\n" . Dumper(\%l10n) . "\n";
	# close $fh;

	return \%l10n;
}

#
# split_tags()
# ----------
# Separate the singular & plural entries from a hash, as returned by
# read_po_files(), into two hashes. Obviously returned as two hashrefs.
#

=head2 split_tags()

C<split_tags()> takes the hashref returned by read_po_files as input parameter separates it into two hashes separated by
if they are singular or plural, respectively and returns them as 2 hashrefs.

=head3 Arguments

A hash is passed as an argument.

=head3 Return values

If the function executes successfully it returns two hash references. 
If the tags are malformed, it throws a warning.

=cut

sub split_tags {
	my ($l10n) = @_;

	my (%singular, %plural);
	$singular{":langname"} = $plural{":langname"} = delete $l10n->{":langname"};
	$singular{":langtag"} = $plural{":langtag"} = delete $l10n->{":langtag"};

	for my $key (keys %{$l10n}) {
		my ($tag, $kind) = split /:/, $key;

		if ($kind eq "plural") {$plural{$tag} = delete $l10n->{$key}}
		elsif ($kind eq "singular") {$singular{$tag} = delete $l10n->{$key}}
		else {warn "warning: malformed tag from .po file: $key\n"}
	}

	return \%singular, \%plural;
}

1;

__END__

