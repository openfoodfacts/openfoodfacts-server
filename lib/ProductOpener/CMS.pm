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

Uses the WordPress API to fetch pages content.

We use WPML to manage the translations of the pages on WordPress and get them 
here from the /graphql endpoint (WPMLGraphQL plugin).

=head2 DETAILS

- Be aware that if a page is published, and the default translation has not been created (even if empty), 
  it won't show up in the graphql response. 
  Ex: You create a French page, publish it, then, at least, you have to create/start the 
  	  English translation (let it empty for the moment if you want). After that you'll 
	  be able to see the french page in Product Opener. As an admin do /content/refresh

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
use HTTP::Tiny;
use Log::Any qw($log);
use JSON;

my $default_wp_language_code = 'en';
# {
#    // translations are stored with the id of the default page translation ('en')
#    // but to get the actual content from WordPress (REST API) we use the 'id' (8 for en, 22 for fr)
#   '8' => {
#             'en' => {
#                       'languageCode' => 'en',
#                       'title' => 'Contribute to Open Food Facts',
#                       'slug' => 'contribute',
#                       'id' => 8
#                     },
#             'fr' => {
#                       'slug' => 'contribuer',
#                       'languageCode' => 'fr',
#                       'id' => 22,
#                       'title' => "Contribuer à Open Food Facts"
#                     }
#           }
# }
my $page_metadata_cache_by_id = {};
#
# {
#   'fr' => { 'contribuer' => 8 },
#   'en' => {'contribute' => 8 }
# }
my $page_id_by_localized_slug = {};

sub wp_get_page_from_slug ($lc, $slug) {
	my $default_translation_id = $page_id_by_localized_slug->{$lc}{$slug};
	my $page_id = $page_metadata_cache_by_id->{$default_translation_id}{$lc}{id};
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
If the page isn't available in that language, it defaults to C<$default_wp_language_code>

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

sub wp_get_available_pages ($lc) {
	my @available_translations;
	foreach my $page_id (keys %{$page_metadata_cache_by_id}) {
		my $existing_lc = (exists $page_metadata_cache_by_id->{$page_id}{$lc}) ? $lc : $default_wp_language_code;
		my $page = $page_metadata_cache_by_id->{$page_id}{$existing_lc};
		if (!$page) {
			next;
		}
		$page = {
			id => $page->{id},
			lc => $existing_lc,
			link => "/content/$existing_lc/$page->{slug}",
			title => $page->{title},
			order => $page->{order},
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

At the end C<$page_metadata_cache_by_id> associate id with the result of C<_wp_list_pages> 

=cut

sub load_cms_data () {
	my @pages = _wp_list_pages();
	if (not $ProductOpener::Config2::wordpress_url) {
		print STDERR "No WordPress URL defined in ProductOpener::Config2::wordpress_url\n";
		return 0;
	}
	if (!@pages) {
		print STDERR "Couldn't get pages metadata from WordPress$@\n";
		return 0;
	}

	my $format_and_store = sub {
		my ($page, $grouping_id) = @_;
		$page->{order} = scalar(delete $page->{menuOrder} // 0);
		$page->{id} = delete $page->{databaseId};
		my $lc = $page->{languageCode};
		$page_metadata_cache_by_id->{$grouping_id}{$lc} = $page;
		$page_id_by_localized_slug->{$lc}{$page->{slug}} = $grouping_id;
	};

	foreach my $page (@pages) {
		$format_and_store->($_, $page->{databaseId}) for (@{$page->{translations}});
		# we flatten the available translations. We don't need to keep this redundant info
		delete $page->{translations};
		$format_and_store->($page, $page->{databaseId});
	}

	return 1;
}

=head2 _wp_list_pages ()

Get the list of pages from the CMS

=head3 Returns

An list of pages with their translations

=cut  

sub _wp_list_pages () {
	my $query = '{
    pages {
      nodes {
          databaseId
          slug
          title
          languageCode
		  menuOrder
          translations {
            databaseId
            slug
            title
			menuOrder
            languageCode
          }
        }
    }
  }';
	my @pages;
	my $response = _wp_graphql_query($query);
	if ($response) {
		return @{$response->{pages}{nodes}};
	}
	return ();
}

=head2 _wp_graphql_query ($query)

Query the WordPress using the GraphQL API (need plugins: WPGraphQL + WPMLGraphQL )

=cut

sub _wp_graphql_query ($query) {
	my $http = HTTP::Tiny->new();
	my $response = $http->post(
		$ProductOpener::Config2::wordpress_url . '/graphql',
		{
			headers => {'Content-Type' => 'application/json'},
			content => encode_json({query => $query}),
		}
	);
	my $json;
	if ($response->{success}) {
		eval {$json = decode_json($response->{content});};
		if ($@) {
			$log->debug("_get_json_from_url_and_decode", {error => $@, query => $query}) if $log->is_debug();
		}
		else {
			return $json->{data};
		}
	}
	return $json // [];
}

sub _wp_get_page_by_id ($page_id) {
	# we don't use graphql because it's more efficient to get the content from the REST API
	my $url = $ProductOpener::Config2::wordpress_url . '/wp-json/wp/v2/pages/' . $page_id;
	return _get_json_from_url_and_decode($url);
}

sub _get_json_from_url_and_decode ($url) {
	my $response = get($url);
	my $json;
	eval {$json = decode_json($response);};
	if ($@) {
		$log->debug("_get_json_from_url_and_decode", {error => $@, url => $url}) if $log->is_debug();
	}
	return $json // [];
}

1;
