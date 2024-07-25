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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::CMS - manages integration with the CMS

=head1 SYNOPSIS

C<ProductOpener::CMS> contains functions that interact with the CMS


=head1 DESCRIPTION

Uses the WordPress API to fetch pages content

=cut

package ProductOpener::CMS;

use ProductOpener::PerlStandards;
use Exporter qw< import >;


BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&wp_list_pages
        &wp_get_page_by_id
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);

}
use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Config2 qw/:all/;
use LWP::Simple;
use Log::Any qw($log);
use JSON;

=head2 wp_list_pages

Fetches the list of pages from the CMS

=cut    

sub wp_list_pages() {
    my $url = $ProductOpener::Config2::wordpress_url . '/wp-json/wp/v2/pages?';
    $url .= "_fields[]= " . join('&_fields[]=', qw(id title modified_gmt link slug));

    my $response = get($url);
    my $json;
    eval {
        $json = decode_json($response);
    };
    return $json;
}

sub wp_get_page_by_id($page_id) {
    my $url = $ProductOpener::Config2::wordpress_url . '/wp-json/wp/v2/pages/' . $page_id;
    my $response = get($url);
    my $json;
    eval {
        $json = decode_json($response);
    };
    return $json;
}

sub wp_get_page_by_url($url) {
    my $response = get($url);
    my $json;
    eval {
        $json = decode_json($response);
    };
    return $json;
}

1;