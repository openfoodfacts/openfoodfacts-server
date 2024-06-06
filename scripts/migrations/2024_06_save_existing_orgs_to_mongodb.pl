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
use Storable qw(lock_retrieve);
use MongoDB;
use Encode;
use ProductOpener::Paths qw/%BASE_DIRS ensure_dir_created/;
use ProductOpener::Data qw/:all/;

my $database = "off";
my $collection = "orgs";

my $orgs_collection = get_orgs_collection();

my @orgs = ();

my $start_dir = "$BASE_DIRS{ORGS}/";
ensure_dir_created($BASE_DIRS{ORGS});

sub retrieve {
    my $file = shift;
    if (!-e $file) {
        return;
    }
    my $return = undef;
    eval { $return = lock_retrieve($file); };
    return $return;
}

sub find_orgs {
    my ($dir, $code) = @_;
    my $dh;

    opendir $dh, "$dir" or die "could not open $dir directory: $!\n";
    foreach my $file (sort readdir($dh)) {
        chomp($file);
        if ($file =~ /^([a-zA-Z_][a-zA-Z0-9_]*)\.sto/) {
            push @orgs, [$code, $1];
        } else {
            next if $file =~ /\./;
            if (-d "$dir/$file") {
                find_orgs("$dir/$file", "$code$file");
            }
        }
    }
    closedir $dh or print "could not close $dir dir: $!\n";
}

sub main {
    find_orgs($start_dir, '');

    my $count = scalar @orgs;
    my $i = 0;
    my %codes = ();

    print STDERR "$count organizations to update\n";

    foreach my $code_rev_ref (@orgs) {
        my ($code, $rev) = @$code_rev_ref;

        my $org_ref = retrieve("$start_dir/$rev.sto") or print "not defined $start_dir/$rev.sto\n";

        if (defined $org_ref) {
            next if (defined $org_ref->{deleted} && $org_ref->{deleted} eq 'on');

            $org_ref->{org_id} = $code . "." . $rev;


            my $return = $orgs_collection->replace_one({"org_id" => $org_ref->{org_id}}, $org_ref, {upsert => 1});

            print STDERR "return $return\n";
            $i++;
            $codes{$code} = 1;
        }
    }

    print STDERR "$count organizations to update - $i organizations not empty or deleted\n";
    print STDERR "scalar keys codes: " . (scalar keys %codes) . "\n";
}

main();

exit(0);
