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

use ProductOpener::PerlStandards;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Users qw/:all/;

use File::Copy;
use POSIX qw/strftime/;
use JSON;
use Getopt::Long;

my $usage = <<EOF
Usage: $0 [--dry-run]

Try to find and remove users created by a spammer
EOF
	;

my $dry_run = 0;
GetOptions("dry-run" => \$dry_run,)
	or die("Error in command line arguments:\n\n$usage");

my @userids;

if (scalar $#userids < 0) {
	opendir DH, $BASE_DIRS{USERS} or die "Couldn't open the current directory: $!";
	@userids = sort(readdir(DH));
	closedir(DH);
}

my $i = 0;

my @emails_to_delete = ();

my $spam_users_dir = "$data_root/spam_users";

if (!-e $spam_users_dir) {
	mkdir($spam_users_dir, oct(755)) or die("Could not create $spam_users_dir : $!\n");
}

# jsonl of removed users
my $time_prefix = strftime("%Y-%m-%d-%H-%M-%S", localtime);
open(my $jsonl_file, ">:encoding(UTF-8)", "$spam_users_dir/$time_prefix-spam-users.jsonl");
my $json = JSON->new->allow_nonref->canonical;

foreach my $userid (@userids) {

	next if $userid eq "." or $userid eq "..";
	next if $userid eq 'all';

	my $user_ref = retrieve("$BASE_DIRS{USERS}/$userid");

	if ((defined $user_ref) and (is_suspicious_name($user_ref->{name}))) {
		print $user_ref->{name} . "\n";
		push @emails_to_delete, $user_ref->{email};
		eval {print $jsonl_file $json->encode($user_ref) . "\n";};
		$dry_run or move("$BASE_DIRS{USERS}/$userid", "$spam_users_dir/$userid");
		$i++;
	}
}

close($jsonl_file);

my $emails_ref = retrieve("$BASE_DIRS{USERS}/users_emails.sto");

foreach my $email (@emails_to_delete) {
	delete $emails_ref->{$email};
}

$dry_run or store("$BASE_DIRS{USERS}/users/users_emails.sto", $emails_ref);

print "$i accounts removed\n";

exit(0);

