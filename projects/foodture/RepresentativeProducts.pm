# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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

=head1 NAME

RepresentativeProducts - functions shared by the representative products scripts of projects/foodture

=head1 DESCRIPTION

Used by select_representative_products.pl and list_campaign_needed_categories.pl:
countries of the dataset, completeness of products, categories recomputed with the current taxonomy,
scans read from the scans.json file of each product.

=cut

package RepresentativeProducts;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK);
	@EXPORT_OK = qw(
		@dataset_countries
		%foodture_countries
		@complete_states
		%missing_names
		&dataset_countries_ccs
		&count_uploaded_photos
		&get_current_categories
		&retrieve_product_scans
		&country_year_scans
		&global_year_scans
		&is_better
		&open_jsonl
	);
}

use vars @EXPORT_OK;

use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Store qw/retrieve_object/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Products qw/product_path_from_id/;

# Countries of the representative products dataset: the 32 FOODTURE countries, plus Canada and Iceland
@dataset_countries = qw/
	Austria
	Belgium
	Bulgaria
	Canada
	Croatia
	Cyprus
	Czechia
	Denmark
	Estonia
	Finland
	France
	Germany
	Greece
	Hungary
	Iceland
	Ireland
	Italy
	Latvia
	Lithuania
	Luxembourg
	Malta
	Montenegro
	Netherlands
	Norway
	Poland
	Portugal
	Romania
	Serbia
	Slovakia
	Slovenia
	Spain
	Sweden
	Switzerland
	UK
	/;

# Countries that FOODTURE does not need
my %not_foodture = (Canada => 1, Iceland => 1);
%foodture_countries = map {$_ => ($not_foodture{$_} ? 0 : 1)} @dataset_countries;

@complete_states = qw/en:nutrition-facts-completed en:ingredients-completed en:photos-uploaded/;
%missing_names = (
	'en:nutrition-facts-completed' => 'nutrition facts',
	'en:ingredients-completed' => 'ingredients',
	'en:photos-uploaded' => 'photos',
);

=head2 dataset_countries_ccs ()

Return a hash ref: country tag -> country codes used in scans.json (GeoIP uses gb for the United Kingdom)

=cut

sub dataset_countries_ccs () {
	my %countries_ccs = ();
	foreach my $country (@dataset_countries) {
		my $country_tag = canonicalize_taxonomy_tag('en', 'countries', $country);
		my $cc = country_to_cc($country_tag) // die "No country code for $country_tag\n";
		$countries_ccs{$country_tag} = [$cc];
		push @{$countries_ccs{$country_tag}}, 'gb' if $cc eq 'uk';
	}
	return \%countries_ccs;
}

=head2 count_uploaded_photos ($product_ref)

Number of uploaded photos (images.uploaded, or numeric keys of images in older schemas)

=cut

sub count_uploaded_photos ($product_ref) {
	my $images_ref = $product_ref->{images};
	return 0 if ref $images_ref ne 'HASH';
	return scalar keys %{$images_ref->{uploaded}} if ref $images_ref->{uploaded} eq 'HASH';
	return scalar grep {/^\d+$/} keys %$images_ref;
}

# Cache of recomputed categories, as many products have the same categories
my %categories_cache = ();

=head2 get_current_categories ($product_ref)

Categories of the product (with parents), recomputed with the current taxonomy from the input tags of all sources
(tags_sources), or from the categories field for products with an older schema.
Stored categories_tags can have old tags and old parents.

=cut

sub get_current_categories ($product_ref) {
	my ($tag_lc, @input_tags);
	my $sources_ref = $product_ref->{tags_sources}{categories};
	if (ref $sources_ref eq 'HASH') {
		# schema >= 1005: categories_tags is made from the tags of all sources (users, producers etc.)
		my %tags = map {$_ => 1} map {@{$_->{tags} // []}} grep {ref $_ eq 'HASH'} values %$sources_ref;
		($tag_lc, @input_tags) = ('en', sort keys %tags);
	}
	elsif (($product_ref->{categories} // '') ne '') {
		# older schema: categories_tags is made from the categories field
		($tag_lc, @input_tags) = (
			$product_ref->{categories_lc} // $product_ref->{lc} // 'en',
			split(/\s*,\s*/, $product_ref->{categories})
		);
	}
	else {
		# fall back to the stored tags
		($tag_lc, @input_tags) = ('en', @{$product_ref->{categories_tags} // []});
	}
	my $key = join("\t", $tag_lc, @input_tags);
	$categories_cache{$key} //= [gen_tags_list_with_parents($tag_lc, 'categories', \@input_tags)];
	return $categories_cache{$key};
}

=head2 retrieve_product_scans ($code)

Content of the scans.json file of the product (empty hash if there is none)

=cut

sub retrieve_product_scans ($code) {
	return retrieve_object("$BASE_DIRS{PRODUCTS}/" . product_path_from_id($code) . "/scans") // {};
}

=head2 country_year_scans ($scans_ref, $years_ref, $ccs_ref)

Unique scans of each year of $years_ref in the country (sum of its country codes $ccs_ref)

=cut

sub country_year_scans ($scans_ref, $years_ref, $ccs_ref) {
	my @year_scans = ();
	foreach my $year (@$years_ref) {
		my $scans_by_country_ref = $scans_ref->{$year}{unique_scans_n_by_country} // {};
		my $year_scans = 0;
		$year_scans += $scans_by_country_ref->{$_} // 0 for @$ccs_ref;
		push @year_scans, $year_scans;
	}
	return @year_scans;
}

=head2 global_year_scans ($scans_ref, $years_ref)

Unique scans of each year of $years_ref in all countries

=cut

sub global_year_scans ($scans_ref, $years_ref) {
	return map {$scans_ref->{$_}{unique_scans_n} // 0} @$years_ref;
}

=head2 is_better ($a_ref, $b_ref)

1 if the ranking key $a_ref is better than $b_ref.
Ranking keys: [total scans, scans for each year (most recent first), code]

=cut

sub is_better ($a_ref, $b_ref) {
	for my $i (0 .. $#$a_ref - 1) {
		return 1 if $a_ref->[$i] > $b_ref->[$i];
		return 0 if $a_ref->[$i] < $b_ref->[$i];
	}
	return ($a_ref->[-1] lt $b_ref->[-1]) ? 1 : 0;
}

=head2 open_jsonl ($file)

Open a JSONL file, compressed with gzip if its name ends with .gz

=cut

sub open_jsonl ($file) {
	my $IN;
	if ($file =~ /\.gz$/) {
		open($IN, '-|', 'gzip', '-dc', $file) or die "Cannot read $file: $!\n";
	}
	else {
		open($IN, '<', $file) or die "Cannot read $file: $!\n";
	}
	return $IN;
}

1;
