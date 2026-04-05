#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;

use ProductOpener::Tags qw/:all/;

=head1 Some unit tests for Tags.pm module

=cut

=head2 Unit testing get_lc_tagid
=cut

{
	# mock download image to fetch image in inputs_dir
	my $tag_module = mock 'ProductOpener::Tags' => (
		override => [
			# a fake remove stopwords
			# we prefer to use a mock for we do not have control
			# over what the original function does as it is governed by the content of the stopwords
			# global hash (also we can save time avoiding to load full taxonomies just for this test)
			remove_stopwords => sub {
				my $tagtype = shift;
				my $lc = shift;
				my $tagid = shift;

				# naivly remove "the" at start
				$tagid =~ s/the-*//i;

				return $tagid;
			}

		]
	);

	# this would be the section of %synonyms for our tagtype (categories)
	my $synonyms_ref = {
		"en" => {
			"salted-snacks" => "en:salted-snacks",
			"salty-snacks" => "en:salted-snacks",
			"salty-snack" => "en:salted-snacks",
		}
	};

	my $lc_tagid;

	$lc_tagid = get_lc_tagid($synonyms_ref, "en", "categories", "salted-snacks", "");
	is($lc_tagid, "en:salted-snacks");

	# simple synonyms
	$lc_tagid = get_lc_tagid($synonyms_ref, "en", "categories", "salty-snacks", "");
	is($lc_tagid, "en:salted-snacks");

	# normalization
	$lc_tagid = get_lc_tagid($synonyms_ref, "en", "categories", "Salty Snacks", "");
	is($lc_tagid, "en:salted-snacks");

	# stopzords removal
	$lc_tagid = get_lc_tagid($synonyms_ref, "en", "categories", "The Salty Snacks", "");
	is($lc_tagid, "en:salted-snacks");

	# plaral removal
	$lc_tagid = get_lc_tagid($synonyms_ref, "en", "categories", "Saltys Snacks", "");
	is($lc_tagid, "en:salted-snacks");

}

# Minimal subsets of tags

is([get_minimal_tags_subset("categories", [])], []);

is([get_minimal_tags_subset("categories", ["en:vegetables", "en:carrots"])], ["en:carrots"]);

is(
	[
		get_minimal_tags_subset(
			"categories", ["en:vegetables", "en:carrots", "en:soups", "en:frozen-carrots", "en:frozen-soups"]
		)
	],
	["en:frozen-carrots", "en:frozen-soups"]
);

# display_comma_separated_tags_list_in_lc()

is(display_comma_separated_tags_list_in_lc("fr", "categories", undef), "");
is(display_comma_separated_tags_list_in_lc("fr", "categories", []), "");
is(display_comma_separated_tags_list_in_lc("en", "categories", ["en:vegetables", "en:carrots"]), "Vegetables, Carrots");
is(
	display_comma_separated_tags_list_in_lc(
		"en", "categories", ["en:vegetables", "en:carrots", "en:Some unknown carrot species"]
	),
	"Vegetables, Carrots, Some unknown carrot species"
);
is(display_comma_separated_tags_list_in_lc("fr", "categories", ["en:vegetables", "en:carrots"]), "Légumes, Carottes");
is(display_comma_separated_tags_list_in_lc("fr", "brands", ["xx:aldi", "xx:marks-spencers", "xx:Marque Inconnue"]),
	"Aldi, Marks & Spencers, Marque Inconnue");

is(
	display_comma_separated_tags_list_in_lc(
		"en", "categories", ["en:vegetables", "de:Toutafé", "fr:Catégorie tout à fait inconnue"]
	),
	"Vegetables, de:Toutafé, fr:Catégorie tout à fait inconnue"
);

# gen_tags_list_with_parents

retrieve_tags_taxonomy("test");

is([gen_tags_list_with_parents("en", "test", [])], []);
is([gen_tags_list_with_parents("en", "test", ["test"])], ["en:test"]);
is([gen_tags_list_with_parents("en", "test", ["en:test"])], ["en:test"]);
is([gen_tags_list_with_parents("en", "test", ["en:test", "en:test"])], ["en:test"]);
is([gen_tags_list_with_parents("en", "test", ["yaourts à la banane"])], ["en:yaourts à la banane"]);
is([gen_tags_list_with_parents("fr", "test", ["yaourts à la banane"])], ["en:yogurts", "en:banana-yogurts"]);
is([gen_tags_list_with_parents("fr", "test", ["yaourts au schtroumpf"])], ["fr:yaourts au schtroumpf"]);

done_testing();
