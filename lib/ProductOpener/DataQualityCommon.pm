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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::DataQualityCommon - check the quality of data common to any type of products

=head1 DESCRIPTION

C<ProductOpener::DataQualityFood> is a submodule of C<ProductOpener::DataQuality>.

It implements quality checks that are not specific to a given type of products,
and that are thus run for all products.

=cut

package ProductOpener::DataQualityCommon;

use utf8;
use Modern::Perl '2017';
use Exporter qw(import);


BEGIN
{
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&check_quality_common
		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use ProductOpener::Store qw(:all);
use ProductOpener::Tags qw(:all);

use Log::Any qw($log);


=head1 FUNCTIONS

=head2 check_bugs( PRODUCT_REF )

Checks related to issues that are due to bugs that exist or existed in the code.

=cut

sub check_bugs($) {

	my $product_ref = shift;

	check_bug_missing_or_unknown_main_language($product_ref);

	check_bug_code_missing($product_ref);
	check_bug_created_t_missing($product_ref);

	return;
}

=head2 check_bug_missing_or_unknown_main_language( PRODUCT_REF )

Products that do not have the lc or lang field set, or a lang field set to "xx" (unknown)

lc and lang fields should always be set, but there has been some bugs in the past
that caused them not to be set in certain conditions.

=cut

sub check_bug_missing_or_unknown_main_language($) {

	my $product_ref = shift;

	if ((not (defined $product_ref->{lc}))) {
		push @{$product_ref->{data_quality_bugs_tags}}, "en:main-language-code-missing";
	}

	if ((not (defined $product_ref->{lang}))) {
		push @{$product_ref->{data_quality_bugs_tags}}, "en:main-language-missing";
	}
	elsif ($product_ref->{lang} eq 'xx') {
		push @{$product_ref->{data_quality_warnings_tags}}, "en:main-language-unknown";
	}

	return;
}

sub check_bug_code_missing($) {

	my $product_ref = shift;

	# https://github.com/openfoodfacts/openfoodfacts-server/issues/185#issuecomment-364653043
	if ((not (defined $product_ref->{code}))) {
		push @{$product_ref->{data_quality_bugs_tags}}, "en:code-missing";
	}
	elsif ($product_ref->{code} eq '') {
		push @{$product_ref->{data_quality_bugs_tags}}, "en:code-empty";
	}
	elsif ($product_ref->{code} == 0) {
		push @{$product_ref->{data_quality_bugs_tags}}, "en:code-zero";
	}

	return;
}

sub check_bug_created_t_missing($) {

	my $product_ref = shift;

	# https://github.com/openfoodfacts/openfoodfacts-server/issues/185
	if ((not (defined $product_ref->{created_t}))) {
		push @{$product_ref->{data_quality_bugs_tags}}, "en:created-missing";
	}
	elsif ($product_ref->{created_t} == 0) {
		push @{$product_ref->{data_quality_bugs_tags}}, "en:created-zero";
	}

	return;
}

=head2 check_codes( PRODUCT_REF )

Checks related to the barcodes.

=cut

sub check_codes($) {

	my $product_ref = shift;

	check_code_gs1_prefixes($product_ref);

	return;
}

sub check_code_gs1_prefixes($) {

	my $product_ref = shift;

	if ((not (defined $product_ref->{code}))) {
		return;
	}

	my $code = $product_ref->{code};
	# https://github.com/openfoodfacts/openfoodfacts-server/issues/1129
	if ($code =~ /^99[0-9]{10,11}$/) {
		push @{$product_ref->{data_quality_info_tags}}, 'en:gs1-coupon-prefix';
	}
	elsif ($code =~ /^98[5-9][0-9]{9,10}$/) {
		push @{$product_ref->{data_quality_info_tags}}, 'en:gs1-future-coupon-prefix';
	}
	elsif ($code =~ /^98[1-4][0-9]{9,10}$/) {
		push @{$product_ref->{data_quality_info_tags}}, 'en:gs1-coupon-common-currency-area-prefix';
	}
	elsif ($code =~ /^980[0-9]{9,10}$/) {
		push @{$product_ref->{data_quality_info_tags}}, 'en:gs1-refund-prefix';
	}
	elsif ($code =~ /^97[8-9][0-9]{9,10}$/) {
		push @{$product_ref->{data_quality_info_tags}}, 'en:gs1-isbn-prefix';
	}
	elsif ($code =~ /^977[0-9]{9,10}$/) {
		push @{$product_ref->{data_quality_info_tags}}, 'en:gs1-issn-prefix';
	}
	elsif ($code =~ /^3600550[0-9]{6}$/) {
		push @{$product_ref->{data_quality_warnings_tags}}, 'en:cosmetic-product';
	}

	return;
}

=head2 check_quality_common( PRODUCT_REF )

Run all quality checks defined in the module.

=cut

sub check_quality_common($) {

	my $product_ref = shift;

	check_bugs($product_ref);
	check_codes($product_ref);

	return;
}

1;
