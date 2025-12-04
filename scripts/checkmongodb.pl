#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2025 Association Open Food Facts
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

use Modern::Perl '2017';
use utf8;

use Log::Any::Adapter ('Stdout');

use ProductOpener::Data qw/:all/;
use ProductOpener::Slack qw/send_slack_message/;

sub send_msg($) {

	my $msg = shift;

	send_slack_message('#infrastructure', 'checkmongodb', $msg, ':hamster:');

	return;
}

if ($@) {
	my $hostname = `hostname`;
	my $msg = "Host: $hostname - Mongodb down: $@\n";
	send_msg($msg);
	print STDERR $msg;
	$msg = "trying to restart mongod service: service mongod restart : " . `service mongod restart`;
	send_msg($msg);
	print STDERR $msg;

}

exit(0);

