#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use Modern::Perl '2017';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Data qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::URL qw/:all/;
use ProductOpener::Users qw/:all/;

use Log::Any qw($log);
use Log::Any::Adapter ('Stdout');
use Log::Any::Adapter ('Stderr');
Log::Any::Adapter->set(
    'Multiplex',
    adapters => {
        'Stdout' => [ log_level => 'info' ],
        'Stderr' => [ log_level => 'warn' ]
    },
);

use File::Path qw(make_path remove_tree);
use Web::Sitemap;

my $sitemap_root = "$www_root/data/sitemaps";
remove_tree($sitemap_root);
make_path($sitemap_root, { chmod => 0755 });

sub _create_products_sitemap {
	my ($sitemaps_ref, $occ) = @_;

	my $fields_ref = {};
	$fields_ref->{code} = 1;
	my $query_ref = {'code' => { "\$ne" => "" }}, {'empty' => { "\$ne" => 1 }};
	$country = $country_codes{$occ};
	$query_ref->{countries_tags} = $country if $country ne 'en:world';
	my $cursor = get_products_collection()->query($query_ref)->fields($fields_ref);
	my %sitemaps = %{$sitemaps_ref};
	my %url_lists = ();
	foreach my $olc (@{$country_languages{$occ}}) {
		$url_lists{$olc} = ();
	}

	while (my $product_ref = $cursor->next) {
		my $product_url = product_url($product_ref);
		foreach my $olc (keys %sitemaps) {
			push @{$url_lists{$olc}}, { loc => $product_url };
		}
	}

	foreach my $olc (keys %sitemaps) {
		$sitemaps{$olc}->add(\@{$url_lists{$olc}});
	}
}

sub _create_taxonomies_sitemap {
	my ($sitemaps_ref, $occ) = @_;

	my %sitemaps = %{$sitemaps_ref};
	my %url_lists = ();
	foreach my $olc (@{$country_languages{$occ}}) {
		$url_lists{$olc} = ();
	}

	foreach my $tagtype (@taxonomy_fields) {
		foreach my $canon_tagid (keys %{$translations_to{$tagtype}}) {
			next if defined $just_synonyms{$tagtype}{$canon_tagid};
			foreach my $olc (keys %sitemaps) {
				next if not defined $translations_to{$tagtype}{$canon_tagid}{$olc};
				next if not defined $tag_type_singular{$tagtype}{$olc};
				my $tag = $translations_to{$tagtype}{$canon_tagid}{$olc};
				my $tagid = get_string_id_for_lang($olc, $tag);
				my $tag_url = '/' . $tag_type_singular{$tagtype}{$olc} . '/' . $tagid;
				push @{$url_lists{$olc}}, { loc => $tag_url };
			}
		}
	}

	foreach my $olc (keys %sitemaps) {
		$sitemaps{$olc}->add(\@{$url_lists{$olc}});
	}
}

sub _create_sitemap_cc {
	my ($root, $occ) = @_;

	my %sitemaps = ();
	foreach my $olc (@{$country_languages{$occ}}) {
		my $osubdomain = "$occ-$olc";
		if ($olc eq $country_languages{$occ}[0]) {
			$osubdomain = $occ;
		}
		$sitemaps{$olc} = Web::Sitemap->new(
			output_dir => $root,
			loc_prefix => format_subdomain($osubdomain),
			index_name => $osubdomain,
			default_tag => '',
			file_prefix => $osubdomain . '.',
			mobile => 0,
			images => 0,
			charset => 'utf8'
		);
	}

	_create_products_sitemap(\%sitemaps, $occ);
	_create_taxonomies_sitemap(\%sitemaps, $occ);

	foreach my $olc (keys %sitemaps) {
		$sitemaps{$olc}->finish;
	}
}

foreach my $occ (keys %country_codes, 'world') {
	_create_sitemap_cc($sitemap_root, $occ);
}
