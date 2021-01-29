#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Tags qw/:all/;

use Getopt::Long;


$lc = 'fr';

my $tagtype = 'additives';


GetOptions ("lc=s"   => \$lc,      # string
			"tagtype=s" => \$tagtype,

			);


while(<STDIN>) {
	chomp();
	my ($canon_tagid, $tagid, $tag) = spellcheck_taxonomy_tag($lc, $tagtype, $_);
	if (defined $tagid) {
		print "- " . $canon_tagid . "\t" . $tagid . "\t" . $tag . "\n";
	}
	else {
		print "-\n";
	}
}
			
exit(0);

