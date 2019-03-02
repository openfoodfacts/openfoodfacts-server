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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package ProductOpener::APIv2::Products;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					&display_api_v2
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::APIv2::URL qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;

use Apache2::RequestRec;
use HAL::Tiny;
use HTTP::Accept;
use JSON::PP;
use Log::Any qw($log);

sub display_api_v2 {
	my $request_ref = shift;
	my $r = shift;

	my $code = normalize_code($request_ref->{code});
	if ((defined $code) and (len($code) > 0)){
		return hal_product_by_code($code, $request_ref, $r);
	}
	else {
		return hal_products($request_ref, $r);
	}
}

sub hal_product_by_code {
	my $code = shift;
	my $request_ref = shift;
	my $r = shift;

	$log->info('displaying product api', { code => $code }) if $log->is_info();

	my $product_ref = retrieve_product($code);
	return hal_product($product_ref, $request_ref, $r);
}

sub hal_product {
	my $product_ref = shift;
	my $request_ref = shift;
	my $r = shift;

	# Check that the product exist, is published, is not deleted, and has not moved to a new url
	if ((not defined $product_ref) or (not defined $product_ref->{code})) {
		return;
	}

	my $state_ref = {
		id => $product_ref->{code}
	};

	# If the request specified a value for the fields parameter, return only the fields listed
	my @filter = ();
	if (defined $request_ref->{fields}) {
		@filter = split(/,/, $request_ref->{fields});
	}

	my $filter_count = scalar @filter;

	foreach my $field_name (@export_fields) {
		next if (($filter_count > 0) and not ((grep $_ eq $field_name, @filter)));

		my @field_values = ();
		foreach my $olc (sort keys %{$product_ref->{languages_codes}}) {
			my $key = $field_name . $olc;
			$key = $key unless defined $product_ref->{$key};
			next unless defined $product_ref->{$key};

			my $field = { lang => $olc, name => $product_ref->{$key} };
			if (defined $tags_fields{$key}) {
				$field->{href} = resource_url($request_ref, 'tags') . '/' . $key;
			}

			push @field_values, $field;
		}

		if ((scalar @field_values) > 1) {
			$state_ref->{$field_name} = @field_values;
		}
	}

	return HAL::Tiny->new(
		state => $state_ref,
		links => +{
			self => resource_url($request_ref, 'products') . '/' . $product_ref->{code},
			find => {
				href => resource_url($request_ref, 'products') . '{/code}',
				templated => JSON::PP::true,
			},
		}
	);
}

sub hal_products {
	my $request_ref = shift;
	my $r = shift;

	# Will fill $request_ref->{structured_response}
	search_and_display_products($request_ref, {}, undef, undef, undef);

	my $products = [];
	for my $product_ref (@{$request_ref->{structured_response}{products}}) {
		push @{$products}, hal_product($product_ref);
	}

	my $resource = HAL::Tiny->new(
		state => +{
			count => $request_ref->{structured_response}{count},
		},
		links => +{
			self => resource_url($request_ref, 'products') . '?page=' . $request_ref->{structured_response}{page},
			next => resource_url($request_ref, 'products') . '?page=' . $request_ref->{structured_response}{page} + 1,
			find => {
				href => resource_url($request_ref, 'products') . '{/code}',
				templated => JSON::true,
			},
		},
		embedded => +{
			products => $products,
		},
	);
}

1;
