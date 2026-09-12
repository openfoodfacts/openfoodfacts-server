# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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

use ProductOpener::PerlStandards;
use Exporter qw/import/;

our @EXPORT_OK = qw/$language_code_re normalize_language_code language_tag base_language
	language_fallbacks lookup_with_language_fallback/;
our %EXPORT_TAGS = (all => \@EXPORT_OK);
our $language_code_re = qr/[a-z]{2,3}(?:[-_][a-z]{4})?(?:[-_](?:[a-z]{2}|[0-9]{3}))?/iaa;

use File::Basename;
use File::Find::Rule;
use Locale::Maketext::Lexicon
	_auto => 0,
	_decode => 1,
	_style => "gettext",
	_disable_maketext_conversion => 1,
	_allow_empty => 1;
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

=head2 normalize_language_code( $code )

=head3 Arguments

C<$code> is a two- or three-letter language, optionally followed by a script and
a region. C<$language_code_re> is the same grammar, without anchors or captures,
for use in filenames and taxonomy prefixes. Hyphens, underscores and mixed case
are accepted; callers can require the normalized spelling.

=head3 Return values

The internal spelling (C<pt_BR>, C<zh_Hant_TW>), or undef for unsupported syntax.
This does not register or enable a language.

=cut

sub normalize_language_code ($code) {
	return if not defined $code or $code !~ /\A$language_code_re\z/;
	my ($language, @subtags) = split /[-_]/, $code;
	return join('_', lc($language), map {length($_) == 4 ? ucfirst(lc($_)) : uc($_)} @subtags);
}

=head2 language_tag( $code )

=head3 Arguments

C<$code> is a supported internal or external language code.

=head3 Return values

The BCP-47 spelling (C<pt-BR>), or undef for unsupported syntax.

=cut

sub language_tag ($code) {
	my $tag = normalize_language_code($code);
	return if not defined $tag;
	$tag =~ s/_/-/g;
	return $tag;
}

=head2 base_language( $code )

=head3 Arguments

C<$code> is a supported internal or external language code.

=head3 Return values

The language without script or region (C<pt>, C<zh>), or undef for invalid syntax.

=cut

sub base_language ($code) {
	my $canonical = normalize_language_code($code);
	return if not defined $canonical;
	return (split /_/, $canonical)[0];
}

=head2 language_fallbacks( $code )

=head3 Arguments

C<$code> is a supported language code.

=head3 Return values

An ordered list of normalized codes, from specific to general, for example
C<zh_Hant_TW>, C<zh_Hant>, C<zh>. An invalid code returns an empty list.
No unrelated language is added.

=cut

sub language_fallbacks ($code) {
	my $canonical = normalize_language_code($code);
	return () if not defined $canonical;
	my @languages = ($canonical);
	while ($canonical =~ s/_[^_]+$//) {
		push @languages, $canonical;
	}
	return @languages;
}

=head2 lookup_with_language_fallback( $hash_ref, $code, $matched_code_ref = undef )

=head3 Arguments

C<$hash_ref> maps normalized language codes to values. C<$code> selects the
language. The optional C<$matched_code_ref> receives the code that supplied the
value, or undef on a miss. Non-language keys such as C<no_language> are exact-only.

=head3 Return values

The first defined value in the language's fallback chain, or undef. Zero and
empty strings are values too. The hash is not modified, and English fallback is
left to the caller.

=cut

sub lookup_with_language_fallback ($hash_ref, $code, $matched_code_ref = undef) {
	$$matched_code_ref = undef if defined $matched_code_ref;
	return if not defined $code or not defined $hash_ref;
	my @languages = language_fallbacks($code);
	@languages = ($code) if not @languages;
	foreach my $language (@languages) {
		if (defined $hash_ref->{$language}) {
			$$matched_code_ref = $language if defined $matched_code_ref;
			return $hash_ref->{$language};
		}
	}
	return;
}

=head2 read_po_files( $dir, $languages_ref )

Read and merge .po files into one hash, removing gettext metadata and empty
translations written by Crowdin.

=head3 Arguments

C<$dir> is the directory containing the .po files.

Basenames must use the normalized spelling: C<en.po>, C<pt_BR.po>, C<kmr_TR.po>,
C<es_419.po>, C<zh_Hant.po> or C<zh_Hant_TW.po>.
The complete code remains the translation key.

The optional C<$languages_ref> hash restricts loading to its keys, matched exactly
including case (C<pt_BR>, not C<pt_br>). Omit it to load all matching catalogs.
Callers handle language registration and translation fallbacks.

=head3 Return values

A hash reference mapping string IDs to translations by language. Returning a
reference avoids copying the hash and spares the stack.

=cut

sub read_po_files ($dir, $languages_ref = undef) {

	local $log->context->{directory} = $dir;
	$log->debug("Reading po files from disk");

	return unless $dir;

	# remove trailing slash if present
	$dir =~ s/\/$//;

	my %l10n;
	my @files = File::Find::Rule->file->name("*.po")->in($dir . "/");    # Need trailing slash if $dir is a symlink

	for my $file (sort @files) {
		# read the .po file
		my $filename = basename($file);
		local $log->context->{file} = $filename;
		$log->debug("Reading po file");

		my $lc;
		if ($filename =~ /\A($language_code_re)\.po\z/) {
			$lc = normalize_language_code($1);
		}
		else {
			$log->debug("Skipping file (not in language.po format)");
			next;
		}
		next if $filename ne "$lc.po";

		if ((defined $languages_ref) and (not exists $languages_ref->{$lc})) {
			$log->debug("Skipping file (language code is not registered with this exact case)", {lc => $lc});
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

sub read_pot_file ($file) {

	local $log->context->{file} = basename($file);
	$log->debug("Reading pot file");

	open my $fh, "<", $file or die $!;
	my %Lexicon = %{Locale::Maketext::Lexicon::Getcontext->parse(<$fh>)};
	close $fh;

	# clean up %Lexicon from gettext metadata
	delete $Lexicon{""};
	delete $Lexicon{$_} for @metadata_fields;

	return \%Lexicon;
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
	# Do not create undefined entries: po/tags catalogs do not all define these keys.
	foreach my $key (":langname", ":langtag") {
		next if not exists $l10n->{$key};
		$singular{$key} = $plural{$key} = delete $l10n->{$key};
	}

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
