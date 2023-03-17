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

=head1 NAME

gen_users_emails_list.pl - lists Open Food Facts users

=head1 SYNOPSIS

./gen_users_emails_list.pl [--all]
	Option:
	--all          allows to export all the users  

=head1 OPTIONS

=over 8

=item B<--all>

Export all the users, not just the ones registered to Open Food Facts newsletter.

=back

=head1 DESCRIPTION

B<This script> creates a list of Open Food Facts users.

It contains:
* the user's email
* the user's locale (eg. "en", "fr", "de", etc.)
* the country website where the user has registered (eg. "world", "fr", "at", "us", "uk", etc.)
* the timestamp of the user's account creation, Unix style  (eg. "1449487961")
* the country, computed based on IP geolocation
* the user id
* the newsletter field: tells if the user has registered to the Open Food Facts newsletter
* the moderator field: tells if the user is moderator

Each field is separated by a tab (TSV).

By default, the list is restricted to users registered to Open Food Facts newsletter.

=cut

use Modern::Perl '2017';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;

my @userids;
my $arg = $ARGV[0] || "";

if (scalar $#userids < 0) {
	opendir DH, "$data_root/users" or die "Couldn't open the current directory: $!";
	@userids = sort(readdir(DH));
	closedir(DH);
}

foreach my $userid (@userids) {
	next if $userid eq "." or $userid eq "..";
	next if $userid eq 'all';

	my $user_ref = retrieve("$data_root/users/$userid");

	my $first = '';
	if (!exists $user_ref->{discussion}) {
		$first = 'first';
	}

	# print $user_ref->{email} . "\tnews_$user_ref->{newsletter}$first\tdiscussion_$user_ref->{discussion}\n";

	if ($arg eq "--all" || $user_ref->{newsletter}) {
		require ProductOpener::GeoIP;
		my $country = ProductOpener::GeoIP::get_country_code_for_ip($user_ref->{ip});
		defined $country or $country = "";
		my $lc = $user_ref->{initial_lc} || "";
		my $cc = $user_ref->{initial_cc} || "";
		my $t = $user_ref->{registered_t} || "";
		my $userid = $user_ref->{userid} || "";
		my $newsletter = $user_ref->{newsletter} || "";
		my $moderator = $user_ref->{moderator} || "";
		print lc($user_ref->{email}) . "\t"
			. $lc . "\t"
			. $cc . "\t"
			. $t . "\t"
			. $country . "\t"
			. $userid . "\t"
			. $newsletter . "\t"
			. $moderator . "\n";
	}

}

exit(0);

