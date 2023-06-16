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

# Script to remove spam users created by a spammer
# https://github.com/openfoodfacts/openfoodfacts-server/pull/6616

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;

use File::Copy;

my @userids;

if (scalar $#userids < 0) {
	opendir DH, "$data_root/users" or die "Couldn't open the current directory: $!";
	@userids = sort(readdir(DH));
	closedir(DH);
}

my $i = 0;

my @emails_to_delete = ();

my $spam_users_dir = "$data_root/spam_users";

if (!-e $spam_users_dir) {
	mkdir($spam_users_dir, oct(755)) or die("Could not create $spam_users_dir : $!\n");
}

foreach my $userid (@userids) {

	next if $userid eq "." or $userid eq "..";
	next if $userid eq 'all';

	my $user_ref = retrieve("$data_root/users/$userid");

	if ((defined $user_ref) and ($user_ref->{name} =~ /:\/\//)) {
		print $user_ref->{name} . "\n";
		push @emails_to_delete, $user_ref->{email};
		move("$data_root/users/$userid", "$spam_users_dir/$userid");
		$i++;
	}
}

my $emails_ref = retrieve("$data_root/users/users_emails.sto");

foreach my $email (@emails_to_delete) {
	delete $emails_ref->{$email};
}

store("$data_root/users/users_emails.sto", $emails_ref);

print $i . "\n";

exit(0);

