#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2024 Association Open Food Facts
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

# This script is meant to be called through process_new_image_off.sh, itself run through an icrontab

use ProductOpener::PerlStandards;

use ProductOpener::Config qw/:all/;
use ProductOpener::Redis qw/:all/;
use ProductOpener::Auth qw/get_oidc_implementation_level/;

use Log::Any qw($log);
use Log::Any::Adapter ('Stderr', log_level => 'debug');

sub main() {
	$log->info("Starting listen_to_redis_stream.pl") if $log->is_info();

	if (get_oidc_implementation_level() < 2) {
		$log->info("OIDC implementation level is less than 2, not listening to Redis stream") if $log->is_info();
		return;
	}

	if (!$redis_url) {
		# No Redis URL provided, we can't push to Redis
		$log->error("Redis URL not provided for streaming") if $log->is_error();
		return;
	}

	# The following will block until there is an error
	subscribe_to_redis_streams();

	return;
}

main();
