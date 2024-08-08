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

ProductOpener::CMS - manages integration with the CMS. Currently WordPress.

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
		&wp_get_page_from_slug
		&wp_get_available_pages
		&wp_update_pages_metadata_cache
		&load_cms_data
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);

}
use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Config2 qw/:all/;
use LWP::Simple;
use Log::Any qw($log);
use JSON;

my $page_metadata_cache_by_id = {};    # { 16 => { en => page_metadata } }
my $page_id_by_localized_slug = {};    # { en => { my-test-page => 16 },
                                       #   fr => { ma-page-test => 16 } }

=head2 get_page_from_slug($lc, $slug)

Fetches a page from the CMS by its slug

=head3 Parameters

=over

=item $slug

The slug of the page to fetch: 
e.g. 'my-test-page' or 'journees-open-food-facts-2024-reviennent-en-septembre-a-paris'

=back

=cut 

sub wp_get_page_from_slug($lc, $slug) {

	my $page_id = $page_id_by_localized_slug->{$lc}{$slug};
	if ($page_id) {
		my $page_data = _wp_get_page_by_id($page_id);
		return {
			title => $page_data->{title}{rendered},
			content => $page_data->{content}{rendered},
			link => "/content/$lc/$page_data->{slug}",
		};
	}
	return;
}

=head2  wp_get_available_pages($lc)

Gets the list of available pages, given a language code.
If the page isn't available in that language, it defaults to 'en'

=head3 Returns

An list of pages:

(
    {
		id: '6'
        lc: 'en',
        link: '/content/en/test-page',
        title: 'Test Page'
    },
)

=cut

sub wp_get_available_pages($lc) {
	my @available_translations;
	foreach my $page_id (keys %{$page_metadata_cache_by_id}) {
		my $existing_lc = (exists $page_id_by_localized_slug->{$lc}{$page_id}) ? $lc : 'en';
		my $page = $page_metadata_cache_by_id->{$page_id}{$existing_lc};
		$page = {
			id => $page_id,
			lc => $existing_lc,
			link => "/content/$existing_lc/$page->{slug}",
			title => $page->{title},
		};
		push @available_translations, $page;
	}
	$log->debug("wp_get_available_pages", {lc => $lc, available_translations => \@available_translations})
		if $log->is_debug();
	return @available_translations;
}

=head2 wp_update_pages_metadata_cache()

Fill the cache with the metadata of pages published in WordPress.
This function is called in L<ProductOpener::LoadData>

At the end C<@page_metadata_cache_by_id> associate id with the result of C<_wp_list_pages> 

=cut

sub load_cms_data() {
	my @pages = _wp_list_pages();
	if (!@pages) {
		print STDERR "Couldn't get pages metadata from WordPress$@\n";
		return 0;
	}
	foreach my $page (@pages) {
		# TODO: change this to support multiple languages when WPML is enabled
		$page->{title} = $page->{title}{rendered};
		$page->{wp_url} = $page->{link};
		$page_metadata_cache_by_id->{$page->{id}}{en} = $page;
		$page_id_by_localized_slug->{en}{$page->{slug}} = $page->{id};
	}
	return 1;
}

=head2 _wp_list_pages()

Fetches the list of pages from the CMS

=head3 Returns

An array of pages:

[
    {
        "id": 16,
        "title": {
            "rendered": "Test Page"
        },
        "modified_gmt": "2021-09-29T14:00:00",
        "link": "https://wordpress_url/test-page",
        "slug": "test-page"
    },
]

=cut  

sub _wp_list_pages() {
	my $url = $ProductOpener::Config2::wordpress_url . '/wp-json/wp/v2/pages?';
	$url .= "_fields[]= " . join('&_fields[]=', qw(id title modified_gmt link slug));
	return @{_get_json_from_url_and_decode($url)};
}

sub _wp_get_page_by_id($page_id) {
	my $url = $ProductOpener::Config2::wordpress_url . '/wp-json/wp/v2/pages/' . $page_id;
	return _get_json_from_url_and_decode($url);
}

sub _get_json_from_url_and_decode($url) {
	my $response = get($url);
	my $json;
	eval {$json = decode_json($response);};
	if ($@) {
		$log->debug("_get_json_from_url_and_decode", {error => $@, url => $url}) if $log->is_debug();
	}
	return $json // [];
}

1;
