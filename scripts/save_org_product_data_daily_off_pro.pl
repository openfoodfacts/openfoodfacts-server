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

use ProductOpener::PerlStandards;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Data qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS ensure_dir_created/;
use ProductOpener::Users qw/$Owner_id/;
use ProductOpener::Orgs qw/retrieve_org/;
use ProductOpener::CRM qw/update_public_products update_pro_products/;
use Storable qw(store);

# This script is run daily to gather organisation data
# such as number of products, number of products with errors etc.
# Some data such as number of products on the public platform and in the producer platform
# are synced with the CRM.

ensure_dir_created($BASE_DIRS{ORGS});

my $products_collection = get_products_collection();
my $orgs_collection = get_orgs_collection();

sub get_org_data ($org_id) {
	# First query on the "off-pro" database
	my $org_data = $products_collection->aggregate(
		[
			{'$match' => {'owner' => "org-" . $org_id}},
			{
				'$group' => {
					'_id' => '$owner',
					'number_of_products' => {'$sum' => 1},
					'number_of_data_quality_errors' => {
						'$sum' => {
							'$cond' => {
								'if' => {'$isArray' => '$data_quality_errors_tags'},
								'then' => {'$size' => '$data_quality_errors_tags'},
								'else' => 0
							}
						}
					},
					'number_of_data_quality_warnings' => {
						'$sum' => {
							'$cond' => {
								'if' => {'$isArray' => '$data_quality_warnings_tags'},
								'then' => {'$size' => '$data_quality_warnings_tags'},
								'else' => 0
							}
						}
					},
					'number_of_products_without_nutriscore' => {
						'$sum' => {
							'$cond' => [{'$in' => ['en:nutriscore-not-computed', '$misc_tags']}, 1, 0]
						}
					},
					'opportunities_to_improve_nutriscore' => {
						'$sum' => {
							'$cond' => [{'$in' => ['possible-improvements', '$misc_tags']}, 1, 0]
						}
					},
					'products_to_be_exported' => {
						'$sum' => {
							'$cond' => [{'$regexMatch' => {input => '$states', regex => 'en:to-be-exported'}}, 1, 0]
						}
					},
					'products_exported' => {
						'$sum' => {
							'$cond' => [{'$regexMatch' => {input => '$states', regex => 'en:exported'}}, 1, 0]
						}
					},
					'date_of_last_update' => {'$max' => '$last_modified_t'}
				}
			}
		]
	)->next;

	# Second query on the "off" database
	my $off_products_collection = get_products_collection({database => "off"});
	my $off_org_data = $off_products_collection->aggregate(
		[
			{'$match' => {'owners_tags' => "org-" . $org_id}},
			{
				'$group' => {
					'_id' => '$owner',
					'number_of_products' => {'$sum' => 1}
				}
			}
		]
	)->next;

	my $number_of_products = $org_data->{number_of_products} // 0;

	# Using off-query to count products with a specific owners_tags seems very slow
	# use Time::Monotonic qw(monotonic_time);
	# my $start = monotonic_time();
	# my $count = execute_count_tags_query({owners_tags => "org-" . $org_id});
	# my $end = monotonic_time();
	# print STDERR "$org_id\t$number_of_products\t$count\ttime: " . ($end - $start) . "\n";
	my $number_of_products_without_nutriscore = $org_data->{number_of_products_without_nutriscore} // 0;
	my $number_of_products_with_nutriscore = $number_of_products - $number_of_products_without_nutriscore;
	my $percentage_of_products_with_nutriscore
		= $number_of_products > 0 ? ($number_of_products_with_nutriscore / $number_of_products) * 100 : 0;

	return {
		'products' => {
			'number_of_products_on_public_platform' => $off_org_data->{number_of_products} // 0,
			'number_of_products_on_producer_platform' => $number_of_products,
			'number_of_data_quality_errors' => $org_data->{number_of_data_quality_errors} // 0,
			'number_of_data_quality_warnings' => $org_data->{number_of_data_quality_warnings} // 0,
			'number_of_products_without_nutriscore' => $number_of_products_without_nutriscore,
			'percentage_of_products_with_nutriscore' => $percentage_of_products_with_nutriscore,
			'opportunities_to_improve_nutriscore' => $org_data->{opportunities_to_improve_nutriscore} // 0,
			'products_to_be_exported' => $org_data->{products_to_be_exported} // 0,
			'products_exported' => $org_data->{products_exported} // 0,
			'date_of_last_update' => $org_data->{date_of_last_update} // 0,
		},
	};
}

sub update_org_data ($org_id) {

	my $data = get_org_data($org_id);

	$orgs_collection->update_one({'org_id' => $org_id}, {'$set' => {'data' => $data}}, {'upsert' => 1});

	my $org_file_path = "$BASE_DIRS{ORGS}/$org_id.sto";
	my $org_ref = retrieve_org($org_id);

	$org_ref->{'data'} = $data;

	# sync crm
	update_public_products($org_ref, $org_ref->{data}{products}{number_of_products_on_public_platform});
	update_pro_products($org_ref, $org_ref->{data}{products}{number_of_products_on_producer_platform});

	store($org_ref, $org_file_path);
	return;
}

sub gather_org_data {
	my @orgs = $orgs_collection->find()->all();
	my $count = scalar @orgs;
	my $i = 0;

	foreach my $org (@orgs) {
		my $org_id = $org->{'org_id'};
		print "Processing organization $i/$count: $org_id\n";
		eval {update_org_data($org_id)};
		my $org_error = $@;
		print STDERR "Error computing data for org $org_id: $org_error\n" if $org_error;
		$i++;
	}
	return;
}

gather_org_data();

print "Organization data gathering completed.\n";
