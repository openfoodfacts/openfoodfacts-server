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

use Modern::Perl '2012';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use Geo::IP;

my @userids;

if (scalar $#userids < 0) {
	opendir DH, "$data_root/users" or die "Couldn't open the current directory: $!";
	@userids = sort(readdir(DH));
	closedir(DH);
}

foreach my $userid (@userids)
{
	next if $userid eq "." or $userid eq "..";
	next if $userid eq 'all';

	my $user_ref = retrieve("$data_root/users/$userid");

	my $first = '';
	if (! exists $user_ref->{discussion}) {
		$first = 'first';
	}

	# print $user_ref->{email} . "\tnews_$user_ref->{newsletter}$first\tdiscussion_$user_ref->{discussion}\n";

	if ($user_ref->{newsletter}) {
		use ProductOpener::GeoIP;
		my $country = ProductOpener::GeoIP::get_country_code_for_ip($user_ref->{ip});
		defined $country or $country = "";
		my $lc = $user_ref->{initial_lc} || "";
		my $cc = $user_ref->{initial_cc} || "";
		my $t = $user_ref->{registered_t} || "";
		print lc($user_ref->{email}) . "\t" . $lc . "\t" .  $cc . "\t" . $t . "\t"
			. $country . "\n";
	}

}

exit(0);

