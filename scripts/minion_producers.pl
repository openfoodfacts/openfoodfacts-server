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

use Log::Any qw($log);
use Log::Log4perl;
Log::Log4perl->init("$data_root/minion_log.conf"); # Init log4perl from a config file.
use Log::Any::Adapter;
Log::Any::Adapter->set('Log4perl'); # Send all logs to Log::Log4perl

use Mojolicious::Lite;

use Minion;

# Minion backend

$log->info("starting minion producers workers", { minion_backend => $server_options{minion_backend} }) if $log->is_info();


if (not defined $server_options{minion_backend}) {

	die("No Minion backend configured in lib/ProductOpener/Config2.pm\n");
}

plugin Minion => $server_options{minion_backend};

app->minion->add_task(import_csv_file => \&ProductOpener::Producers::import_csv_file_task);

app->minion->add_task(export_csv_file => \&ProductOpener::Producers::export_csv_file_task);

app->minion->add_task(import_products_categories_from_public_database => \&import_products_categories_from_public_database_task);

app->config(
    hypnotoad => {
        listen => [ $server_options{minion_daemon_server_and_port} ],
        proxy  => 1,
    },
);

app->start;

$log->info("minion producers workers stopped", { minion_backend => $server_options{minion_backend} }) if $log->is_info();
