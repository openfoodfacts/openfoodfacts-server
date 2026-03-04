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

./gen_users_emails_list.pl [--all] [--since=YYYY-MM-DD]
Options:
--all          allows to export all the users
--since        only export users registered since this date (ISO 8601 format)

=head1 OPTIONS

=over 8

=item B<--all>

Export all the users, not just the ones registered to Open Food Facts newsletter.

=item B<--since=YYYY-MM-DD>

Only export users who registered on or after the specified date (ISO 8601 format, e.g., 2024-01-15).

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
use Time::Local;


use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Users qw/retrieve_user retrieve_user_preference_ids/;
use ProductOpener::Tags qw/country_to_cc/;

my @userids;
my $arg = $ARGV[0] || "";
my $since_date = $ARGV[1] || "";
my $since_timestamp = 0;

# Parse the --since argument if provided
if ($since_date =~ /^--since=(.+)$/) {
$since_date = $1;
}
elsif ($arg =~ /^--since=(.+)$/) {
    $since_date = $1;
}

if ($since_date) {
    if ($since_date =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
        my ($year, $month, $day) = ($1, $2, $3);
        eval {
            $since_timestamp = timelocal(0, 0, 0, $day, $month - 1, $year - 1900);
        };
        if ($@) {
            die "Invalid date: $@";
        }
    } else {
        die "Invalid date format. Please use ISO 8601 format (YYYY-MM-DD), e.g., 2024-01-15";
    }
}

if (scalar $#userids < 0) {
    @userids = retrieve_user_preference_ids();
}

my $counter = 0;
my $exported_counter = 0;

foreach my $userid (@userids) {
	$counter++;
	if ($counter % 10000 == 0) {
		print STDERR "Processed $counter users\n";
	}

	my $user_ref = retrieve_user($userid);

	my $first = '';
	if (!exists $user_ref->{discussion}) {
		$first = 'first';
	}

	# print $user_ref->{email} . "\tnews_$user_ref->{newsletter}$first\tdiscussion_$user_ref->{discussion}\n";

	if ($arg eq "--all" || $user_ref->{newsletter}) {
		my $t = $user_ref->{registered_t} || 0;

		# Skip users registered before the since_timestamp
		if ($since_timestamp > 0 && $t < $since_timestamp) {
				next;
		}

		require ProductOpener::GeoIP;
		my $country = ProductOpener::GeoIP::get_country_code_for_ip($user_ref->{ip});
		defined $country or $country = "";
		my $lc = $user_ref->{preferred_language} || "";
		my $cc = country_to_cc($user_ref->{country}) || "";
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
		$exported_counter++;
	}

}

print STDERR "Total processed: $counter users\n";
print STDERR "Total exported: $exported_counter users\n";

exit(0);


