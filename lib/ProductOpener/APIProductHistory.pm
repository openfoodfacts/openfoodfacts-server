# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

=head1 NAME

ProductOpener::APIProductHistory - authenticated product history API

=cut

package ProductOpener::APIProductHistory;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&read_product_history_api
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::API qw/add_error normalize_requested_code/;
use ProductOpener::HTTP qw/single_param/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Products qw/is_valid_code product_id_for_owner product_path retrieve_product/;
use ProductOpener::Store qw/retrieve_object/;
use ProductOpener::Users qw/$Owner_id/;

my $default_page_size = 20;
my $max_page_size = 1000;

=head2 read_product_history_api ($request_ref)

Process GET /api/v3/product/{code}/history requests.

The endpoint deliberately reads the compact change metadata from the product's
history file. It does not return diffs, snapshots, or IP addresses.

=cut

sub read_product_history_api ($request_ref) {
	$log->debug("read_product_history_api - start", {request => $request_ref}) if $log->is_debug();

	my $response_ref = $request_ref->{api_response};

	# init_user() has already authenticated both session cookies and bearer
	# tokens by the time API handlers are dispatched.
	if (not defined $request_ref->{user_id}) {
		add_error(
			$response_ref,
			{
				message => {id => "authentication_required"},
				impact => {id => "failure"},
			},
			401
		);
		return;
	}

	my ($code) = normalize_requested_code($request_ref->{code}, $response_ref);
	if (not is_valid_code($code // '')) {
		add_error(
			$response_ref,
			{
				message => {id => "invalid_code"},
				field => {id => "code", value => $request_ref->{code}},
				impact => {id => "failure"},
			},
			400
		);
		$response_ref->{result} = {id => "product_not_found"};
		return;
	}

	my $product_ref = retrieve_product(product_id_for_owner($Owner_id, $code));
	if (not defined $product_ref or not defined $product_ref->{code}) {
		add_error(
			$response_ref,
			{
				message => {id => "product_not_found"},
				field => {id => "code", value => $code},
				impact => {id => "failure"},
			},
			404
		);
		$response_ref->{result} = {id => "product_not_found"};
		return;
	}

	my $changes_ref = retrieve_object("$BASE_DIRS{PRODUCTS}/" . product_path($product_ref) . "/changes");
	$changes_ref = [] if ref($changes_ref) ne 'ARRAY';

	my $total = scalar @{$changes_ref};
	my $current_rev = $product_ref->{rev};
	$current_rev = $total if not defined $current_rev or $current_rev !~ /^\d+$/;

	# Product list endpoints parse pagination values by keeping the leading
	# numeric portion. Match that behavior here, including zero for empty or
	# non-numeric values, and clamp only page_size to the established maximum.
	my $page = _pagination_parameter('page', 1);
	my $page_size = _pagination_parameter('page_size', $default_page_size);
	$page_size = $max_page_size if $page_size > $max_page_size;

	my @revisions;
	for (my $index = $total - 1; $index >= 0; $index--) {
		my $change_ref = $changes_ref->[$index];

		my $revision = $change_ref->{rev};
		if (not defined $revision or $revision !~ /^\d+$/) {
			$revision = $current_rev;
		}
		$current_rev--;

		my $revision_ref = {rev => 0 + $revision};
		foreach my $field (qw/t userid comment app_uuid app_version clientid/) {
			$revision_ref->{$field} = $change_ref->{$field} if defined $change_ref->{$field};
		}
		push @revisions, $revision_ref;
	}

	my @paged_revisions;
	if ($page_size > 0 and $page >= 1) {
		my $offset = ($page - 1) * $page_size;
		if ($offset < $total) {
			my $last = $offset + $page_size - 1;
			$last = $total - 1 if $last >= $total;
			@paged_revisions = @revisions[$offset .. $last];
		}
	}

	# Reuse the existing localized result message; the response payload carries
	# the endpoint-specific history data below.
	$response_ref->{result} = {id => "product_found"};
	$response_ref->{code} = $code;
	$response_ref->{history} = \@paged_revisions;
	$response_ref->{page} = 0 + $page;
	$response_ref->{page_size} = 0 + $page_size;
	$response_ref->{total} = 0 + $total;

	return;
}

sub _pagination_parameter ($name, $default) {
	my $value = single_param($name);
	return $default if not defined $value;
	$value =~ s/\D.*$//;
	return ($value // 0) + 0;
}

1;
