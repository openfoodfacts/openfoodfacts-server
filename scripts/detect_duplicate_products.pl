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

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/retrieve store/;
use ProductOpener::Data qw/get_products_collection/;

use Log::Any::Adapter 'TAP';


my $socket_timeout_ms = 2 * 60000;    # 2 mins, instead of 30s default, to not die as easily if mongodb is busy.

my %flavors = ();

foreach my $flavor ("off", "obf") {
	my $products_collection = get_products_collection({database => $flavor, timeout => $socket_timeout_ms});

	my $cursor = $products_collection->query({})->fields({_id => 1, code => 1, owner => 1});
	$cursor->immortal(1);

	while (my $product_ref = $cursor->next) {
		$flavors{all}{$product_ref->{code}}++;
		$flavors{$flavor}{$product_ref->{code}}++;
	}
}


foreach my $flavor (keys %flavors) {
	print "Flavor $flavor\t" . scalar(keys %{$flavors{$flavor}}) . " products\n";
}
	