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

use Modern::Perl '2017';
use utf8;

my $usage = <<TXT
export_and_import_to_public_database.pl exports product data and photos from the
platform for producers, and import them to the public database

Usage:

export_and_import_to_public_database.pl --owner org-some-producer

Options:

--days 5	indicate to export only products modified in the last 5 days
--query some_field=some_value (e.g. categories_tags=en:beers)	filter the products

TXT
;

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Producers qw/:all/;

use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;
use Log::Any qw($log);
use Spreadsheet::CSV();
use Text::CSV();
use boolean;

use Getopt::Long;


my $query_ref = {};    # filters for mongodb query
my $days;

GetOptions (
			"query:s%" => $query_ref,
			"owner=s" => \$Owner_id,
			"days:i" => \$days,
			)
  or die("Error in command line arguments:\n\n$usage");
  
if (not defined $Owner_id) {
	die("--owner is required.\n\n$usage");
}
else {
	if ($Owner_id =~ /^org-/) {
		$Org_id = $';
	}
}
	
# First export CSV from the producers platform, then import on the public platform

foreach my $field (sort keys %{$query_ref}) {
	if ($query_ref->{$field} eq 'null') {
		# $query_ref->{$field} = { '$exists' => false };
		$query_ref->{$field} = undef;
	}
	elsif ($query_ref->{$field} eq 'exists') {
		$query_ref->{$field} = { '$exists' => true };
	}
	elsif ( $field =~ /_t$/ ) {    # created_t, last_modified_t etc.
		$query_ref->{$field} += 0;
	}
}

# Add filter on number of days since last modification

if (defined $days) {
	$query_ref->{last_modified_t} = { '$gt' => time() - $days * 86400 };
}

$query_ref->{owners_tags} = $Owner_id;
$query_ref->{"data_quality_errors_producers_tags.0"} = { '$exists' => false };

my $args_ref = {
	query => $query_ref
};

# Create Minion tasks for export and import

my $results_ref = export_and_import_to_public_database($args_ref);

my $local_export_job_id = $results_ref->{local_export_job_id};
my $remote_import_job_id = $results_ref->{remote_import_job_id};
my $export_id = $results_ref->{export_id};

print STDERR "export_id: $export_id\n";
print STDERR "local_export_job_id: $local_export_job_id\n";
print STDERR "remote_import_job_id: $remote_import_job_id\n";

exit(0);

