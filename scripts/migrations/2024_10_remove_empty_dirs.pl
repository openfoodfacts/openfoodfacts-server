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
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Data qw/:all/;
use ProductOpener::Orgs qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;

use File::Copy (qw/move/);

use Data::Dumper;

# Recursively remove empty directories

sub remove_empty_dirs ($dir) {

	opendir(my $dh, $dir) || die "Can't opendir $dir: $!";
	my @files = readdir($dh);
	closedir $dh;

	foreach my $file (sort @files) {

		next if $file eq '.' or $file eq '..';

		my $path = "$dir/$file";

		if (-d $path) {
			remove_empty_dirs($path);
		}
	}

	opendir($dh, $dir) || die "Can't opendir $dir: $!";
	@files = readdir($dh);
	closedir $dh;

	if (scalar @files == 2) {
		print "Removing empty directory $dir\n";
		rmdir $dir;
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

remove_empty_dirs($dir);

exit(0);

