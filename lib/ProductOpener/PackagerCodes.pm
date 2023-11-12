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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::Food - functions related to food products and nutrition

=head1 DESCRIPTION

C<ProductOpener::PackagerCodes> contains functions specific to packager codes found on products.

..

=cut

package ProductOpener::PackagerCodes;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		%packager_codes
		@sorted_packager_codes
		%geocode_addresses
		&init_packager_codes
		&init_geocode_addresses

		$ec_code_regexp
		&normalize_packager_codes
		&localize_packager_code
		&get_canon_local_authority

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Lang qw/:all/;

use Log::Any qw($log);

$ec_code_regexp = "ce|eec|ec|eg|we|ek|ey|eu|eü";

sub normalize_packager_codes ($codes) {

	$codes = uc($codes);

	$codes =~ s/\/\///g;

	$codes =~ s/(^|,|, )(emb|e)(\s|-|_|\.)?(\d+)(\.|-|\s)?(\d+)(\.|_|\s|-)?([a-z]*)/$1EMB $4$6$8/ig;

	# FRANCE -> FR
	$codes =~ s/(^|,|, )(france)/$1FR/ig;

	# most common forms:
	# ES 12.06648/C CE
	# ES 26.00128/SS CE
	# UK DZ7131 EC (with sometime spaces but not always, can be a mix of letters and numbers)

	my $normalize_fr_ce_code = sub ($countrycode, $number) {

		$countrycode = uc($countrycode);
		$number =~ s/\D//g;
		$number =~ s/^(\d\d)(\d\d\d)(\d)/$1.$2.$3/;
		$number =~ s/^(\d\d)(\d\d)/$1.$2/;
		# put leading 0s at the end
		$number =~ s/\.(\d)$/\.00$1/;
		$number =~ s/\.(\d\d)$/\.0$1/;
		return "$countrycode $number EC";
	};

	my $normalize_uk_ce_code = sub ($countrycode, $code) {

		$countrycode = uc($countrycode);
		$code = uc($code);
		$code =~ s/\s|-|_|\.|\///g;
		return "$countrycode $code EC";
	};

	my $normalize_es_ce_code = sub ($countrycode, $code1, $code2, $code3) {

		$countrycode = uc($countrycode);
		$code3 = uc($code3);
		return "$countrycode $code1.$code2/$code3 EC";
	};

	my $normalize_ce_code = sub ($countrycode, $code) {

		$countrycode = uc($countrycode);
		$code = uc($code);
		return "$countrycode $code EC";
	};

	my $normalize_lu_ce_code = sub ($countrycode, $letters, $number) {

		$letters = uc($letters);
		$countrycode = uc($countrycode);
		return "$countrycode $letters$number EC";
	};

	my $normalize_rs_ce_code = sub ($countrycode, $code) {

		$code = uc($code);
		return "$countrycode $code EC";
	};

	# CE codes -- FR 67.145.01 CE
	#$codes =~ s/(^|,|, )(fr)(\s|-|_|\.)?((\d|\.|_|\s|-)+)(\.|_|\s|-)?(ce)?\b/$1 . $normalize_fr_ce_code->($2,$4)/ieg;	 # without CE, only for FR
	$codes
		=~ s/(^|,|, )(fr)(\s|-|_|\.)?((\d|\.|_|\s|-)+?)(\.|_|\s|-)?($ec_code_regexp)\b/$1 . $normalize_fr_ce_code->($2,$4)/ieg;

	$codes
		=~ s/(^|,|, )(uk)(\s|-|_|\.)?((\w|\.|_|\s|-)+?)(\.|_|\s|-)?($ec_code_regexp)\b/$1 . $normalize_uk_ce_code->($2,$4)/ieg;
	$codes
		=~ s/(^|,|, )(uk)(\s|-|_|\.|\/)*((\w|\.|_|\s|-|\/)+?)(\.|_|\s|-)?($ec_code_regexp)\b/$1 . $normalize_uk_ce_code->($2,$4)/ieg;

	# NO-RGSEAA-21-21552-SE -> ES 21.21552/SE

	$codes
		=~ s/(^|,|, )n(o|°|º)?(\s|-|_|\.)?rgseaa(\s|-|_|\.|:|;)*(\d\d)(\s|-|_|\.)?(\d+)(\s|-|_|\.|\/|\\)?(\w+)\b/$1 . $normalize_es_ce_code->('es',$5,$7,$9)/ieg;
	$codes
		=~ s/(^|,|, )(es)(\s|-|_|\.)?(\d\d)(\s|-|_|\.|:|;)*(\d+)(\s|-|_|\.|\/|\\)?(\w+)(\.|_|\s|-)?($ec_code_regexp)?(?=,|$)/$1 . $normalize_es_ce_code->('es',$4,$6,$8)/ieg;

	# LU L-2 --> LU L2

	$codes
		=~ s/(^|,|, )(lu)(\s|-|_|\.|\/)*(\w)( |-|\.)(\d+)(\.|_|\s|-)?($ec_code_regexp)\b/$1 . $normalize_lu_ce_code->('lu',$4,$6)/ieg;

	# RS 731 -> RS 731 EC
	my $start_pat = qr{ (?<start> ^ | [,.] ) }xsm;
	my $sep_pat = qr{ \s | - | _ | \. | / }xsm;
	my $rs_pat = qr{
					   $start_pat

					   rs

					   (?: $sep_pat )*

					   (?<code>
						   (?:
							   \d+
							   (?:
								   -
								   (?= \d )
							   )?
						   )+
					   )

					   (?: $sep_pat )*

					   (?: $ec_code_regexp )?

					   \b
			   }ixsm;
	$codes =~ s{ $rs_pat }
			   {$+{start} . $normalize_rs_ce_code->('rs', $+{code})}iegxsm;

	$codes
		=~ s/(^|,|, )(\w\w)(\s|-|_|\.|\/)*((\w|\.|_|\s|-|\/)+?)(\.|_|\s|-)?($ec_code_regexp)\b/$1 . $normalize_ce_code->($2,$4)/ieg;

	return $codes;
}

my %local_ec = (
	DE => "EG",
	EE => "EÜ",
	ES => "CE",
	FI => "EY",
	FR => "CE",
	HR => "EU",
	IT => "CE",
	NL => "EG",
	PL => "WE",
	PT => "CE",
	UK => "EC",
);

sub localize_packager_code ($code) {

	my $local_code = $code;

	if ($code =~ /^(\w\w) (.*) EC$/i) {

		my $country_code = uc($1);
		my $actual_code = $2;

		if (defined $local_ec{$country_code}) {
			$local_code = $country_code . " " . $actual_code . " " . $local_ec{$country_code};
		}
	}

	return $local_code;
}

# Load geocoded addresses

sub get_canon_local_authority ($local_authority) {

	$local_authority =~ s/LB of/London Borough of/;
	$local_authority =~ s/CC/City Council/;
	$local_authority =~ s/MBC/Metropolitan Borough Council/;
	$local_authority =~ s/MDC/Metropolitan District Council/;
	$local_authority =~ s/BC/Borough Council/;
	$local_authority =~ s/DC/District Council/;
	$local_authority =~ s/RB/Regulatory Bureau/;
	$local_authority =~ s/Co (.*)/$1 Council/;

	my $canon_local_authority = $local_authority;
	$canon_local_authority
		=~ s/\b(london borough of|city|of|rb|bc|dc|mbc|mdc|cc|borough|metropolitan|district|county|co|council)\b/ /ig;
	$canon_local_authority =~ s/ +/ /g;
	$canon_local_authority =~ s/^ //;
	$canon_local_authority =~ s/ $//;
	$canon_local_authority = get_string_id_for_lang("en", $canon_local_authority);

	return $canon_local_authority;
}

sub init_packager_codes() {
	return if (%packager_codes);

	if (-e "$data_root/packager-codes/packager_codes.sto") {
		my $packager_codes_ref = retrieve("$data_root/packager-codes/packager_codes.sto");
		%packager_codes = %{$packager_codes_ref};
		# Used to display sorted suggestions in TaxonomySuggestions.pm
		@sorted_packager_codes = sort keys %packager_codes;
	}
	return;
}

sub init_geocode_addresses() {
	return if (%geocode_addresses);

	if (-e "$data_root/packager-codes/geocode_addresses.sto") {
		my $geocode_addresses_ref = retrieve("$data_root/packager-codes/geocode_addresses.sto");
		%geocode_addresses = %{$geocode_addresses_ref};
	}
	return;
}

1;
