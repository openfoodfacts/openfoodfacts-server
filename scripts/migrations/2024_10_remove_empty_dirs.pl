#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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

use CGI::Carp qw(fatalsToBrowser);

# use ProductOpener::PerlStandards;
# not available in old versions of ProductOpener running on obf, opf, opff

use 5.24.0;
use strict;
use warnings;
use feature (qw/signatures :5.24/);
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Texts qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Data qw/:all/;
use ProductOpener::Orgs qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

use File::Copy (qw/move/);

use Data::Dumper;

my $dirs_removed = 0;
my $dirs_errors = 0;

# Recursively remove empty directories

sub remove_empty_dirs ($dir) {

	my $dh;
	if (!opendir($dh, $dir)) {
		print STDERR "ERROR: Can't opendir $dir: $!\n";
		$dirs_errors++;
		return;
	}
	my @files = readdir($dh);
	closedir $dh;

	foreach my $file (sort @files) {

		next if $file eq '.' or $file eq '..';

		my $path = "$dir/$file";

		if (-d $path) {
			remove_empty_dirs($path);
		}
	}

	# Re-read directory to check if it's empty after recursive removal
	if (!opendir($dh, $dir)) {
		print STDERR "ERROR: Can't re-open $dir: $!\n";
		$dirs_errors++;
		return;
	}
	@files = readdir($dh);
	closedir $dh;

	# Only . and .. means empty directory
	if (scalar @files == 2) {
		print "Removing empty directory $dir\n";
		if (rmdir $dir) {
			$dirs_removed++;
		}
		else {
			print STDERR "ERROR: Failed to remove directory $dir: $!\n";
			$dirs_errors++;
		}
	}
	return;
}

use Getopt::Long;

my $dir;

GetOptions('dir=s' => \$dir,);

if (not defined $dir) {
	print <<USAGE
Usage: $0 --dir /path/to/dir
USAGE
		;
	exit(1);
}

if (! -e $dir) {
	die "ERROR: Directory $dir does not exist\n";
}

if (! -d $dir) {
	die "ERROR: $dir is not a directory\n";
}

print "Starting to remove empty directories from $dir...\n";

remove_empty_dirs($dir);

print "\nOperation complete:\n";
print "  Directories removed: $dirs_removed\n";
print "  Errors encountered: $dirs_errors\n";

exit(0);

