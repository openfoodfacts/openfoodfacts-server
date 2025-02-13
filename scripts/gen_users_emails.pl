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

use Modern::Perl '2017';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Users qw/retrieve_user retrieve_userids/;

my @userids;

if (scalar $#userids < 0) {
	@userids = retrieve_userids();
}

my $emails_ref = retrieve("$BASE_DIRS{USERS}/users_emails.sto");

my $i = 0;
my $n = scalar @userids;

foreach my $userid (sort @userids) {
	my $user_ref = retrieve_user($userid);
	if (defined $user_ref) {
		my $email = $user_ref->{email};
		if ((defined $email) and ($email =~ /\@/)) {
			$emails_ref->{$email} = [$userid];
		}
	}
	$i++;
	if ($i % 1000 == 0) {
		print "$i / $n - $userid\n";
		store("$BASE_DIRS{USERS}/users_emails.sto", $emails_ref);
	}
}

store("$BASE_DIRS{USERS}/users_emails.sto", $emails_ref);

exit(0);

