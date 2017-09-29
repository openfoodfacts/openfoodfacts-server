# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2015 Association Open Food Facts
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

package ProductOpener::I18N;

use strict;
use warnings;
use File::Find::Rule;
use Locale::Maketext::Lexicon _auto => 0, _decode => 1, _style => "gettext";
use Locale::Maketext::Lexicon::Getcontext;


my @metadata_fields = qw<
    __Content-Transfer-Encoding
    __Content-Type
    __Language
    __Language-Team
    __Last-Translator
    __MIME-Version
    __PO-Revision-Date
    __Project-Id-Version
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
sub read_po_files {
    my ($dir) = @_;

	print STDERR "Reading po files from dir $dir\n";
	
    return unless $dir;
	
	# remove trailing slash if present
	$dir =~ s/\/$//;

    my %l10n;
    my @files = File::Find::Rule->file->name("*.po")->in($dir . "/"); # Need trailing slash if $dir is a symlink

    for my $file (sort @files) {
        # read the .po file
		
		print STDERR "Reading $file\n";
		
		my $lc;
		
		if ($file =~ /\/(\w\w).po/) {
			$lc = $1;
		}
		else {
			print STDERR "Skipping $file (not in [2-letter code].po format)\n";
			next;
		}
		
        open my $fh, "<", $file or die $!;
        my %Lexicon = %{ Locale::Maketext::Lexicon::Getcontext->parse(<$fh>) };
        close $fh;

        # clean up %Lexicon from gettext metadata
        delete $Lexicon{""};
        delete $Lexicon{$_} for @metadata_fields;

        # move the strings into %l10n
        for my $key (keys %Lexicon) {
            # fix extra ~ added before []
            # 		months: ~['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'~],
            $l10n{$key}{$lc} = delete $Lexicon{$key};
            $l10n{$key}{$lc} =~ s/\~(\[|\])/$1/g;
			
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

    return \%l10n
}


#
# split_tags()
# ----------
# Separate the singular & plural entries from a hash, as returned by
# read_po_files(), into two hashes. Obviously returned as two hashrefs.
#
sub split_tags {
    my ($l10n) = @_;

    my (%singular, %plural);
    $singular{":langname"} = $plural{":langname"} = delete $l10n->{":langname"};
    $singular{":langtag"}  = $plural{":langtag"}  = delete $l10n->{":langtag"};

    for my $key (keys %$l10n) {
        my ($tag, $kind) = split /:/, $key;

        if    ($kind eq "plural"  ) { $plural{$tag}   = delete $l10n->{$key} }
        elsif ($kind eq "singular") { $singular{$tag} = delete $l10n->{$key} }
        else  { warn "warning: malformed tag from .po file: $key\n" }
    }

    return \%singular, \%plural
}


__PACKAGE__

__END__

