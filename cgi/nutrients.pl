#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use Modern::Perl '2017';
use utf8;

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:cgi :form escapeHTML/;

use ProductOpener::Lang qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Food qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use JSON::PP;

ProductOpener::Display::init();

# Recursively remove parent association to avoid redundant JSON data.
sub _remove_parent {
	my $current_ref = shift;

	if (defined $current_ref->{nutrients}) {
		foreach my $nutrient (@{$current_ref->{nutrients}}) {
			_remove_parent($nutrient);
		}
	}

	delete $current_ref->{parent};

	return;
}

my @table = ();
my $previous_ref;
my $previous_prefix_length = 0;
foreach (@{$nutriments_tables{$nutriment_table}}) {
	my $nid = $_;	# Copy instead of alias

	$nid =~/^#/ and next;
	my $important = ($nid =~ /^!/) ? JSON::PP::true : JSON::PP::false;
	$nid =~ s/!//g;
	my $default_edit_form = $nid =~ /-$/ ? JSON::PP::false : JSON::PP::true;
	$nid =~ s/-$//g;

	my $onid = $nid =~ s/^(-+)//gr;
	my $prefix_length = defined $1 ? length($1) : 0;
	my %current = ( id => $onid, important => $important, display_in_edit_form => $default_edit_form );
	my $current_ref = \%current;
	my $name = get_nutrient_label($onid, $lc);
	if (defined $name) {
		$current_ref->{name} = $name;
	}

	if (($prefix_length gt 0) or ($prefix_length gt $previous_prefix_length)) {
		@{$previous_ref->{nutrients}} = () unless defined $previous_ref->{nutrients};
		push @{$previous_ref->{nutrients}}, $current_ref unless not defined $current_ref;
		$current_ref->{parent} = $previous_ref;
	}
	else {
		push @table, $current_ref unless not defined $current_ref;
	}

	if (($prefix_length gt $previous_prefix_length) or ($prefix_length eq 0)) {
		$previous_ref = $current_ref;
		$previous_prefix_length = $prefix_length;
	}
}

# The parent attribute is only used to build up the structure. Just remove it here to avoid circular dependency in JSON.
foreach my $nutrient (@table) {
	_remove_parent($nutrient);
}

my %result = ( nutrients => \@table );
my $data = encode_json(\%result);
print header( -type => 'application/json', -content_language => $lc, -charset => 'utf-8', -access_control_allow_origin => '*', -cache_control => 'public, max-age: 86400' ) . $data;
