#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::MockModule;
use Test::More;

use ProductOpener::Tags qw/get_lc_tagid/;

=head1 Some unit tests for Tags.pm module

=cut

=head2 Unit testing get_lc_tagid
=cut

# a fake remove stopwords
# we prefer to use a mock for we do not have control
# over what the original function does as it is governed by the content of the stopwords
# global hash (also we can save time avoiding to load full taxonomies just for this test)
sub fake_remove_stopwords($$$) {

	my $tagtype = shift;
	my $lc = shift;
	my $tagid = shift;

	# naivly remove "the" at start
	$tagid =~ s/the-*//i;

	return $tagid;
}

{
	my $tag_module = Test::MockModule->new('ProductOpener::Tags');

	# mock download image to fetch image in inputs_dir
	$tag_module->mock('remove_stopwords', \&fake_remove_stopwords);

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

done_testing();
