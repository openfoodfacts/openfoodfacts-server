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

use ProductOpener::Config qw/:all/;
use ProductOpener::Producers qw/:all/;

use Minion;

$minion->add_task(import_csv_file => \&ProductOpener::Producers::import_csv_file_task);
$minion->add_task(export_csv_file => \&ProductOpener::Producers::export_csv_file_task);
$minion->add_task(import_products_categories_from_public_database => \&import_products_categories_from_public_database_task);

print STDERR "Perform 1 job in current process\n";

# Perform one job manually in this process
my $worker = $minion->repair->worker->register;

my $job = $worker->dequeue(0 => {queues => [$server_options{minion_local_queue}]});;
if (my $err = $job->execute) { print STDERR "Error: $err\n"; $job->fail($err);  }
else                         {print STDERR "Done\n";  $job->finish }
$worker->unregister;


