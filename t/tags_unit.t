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

    my $synonyms_ref = {
        "en" => {
            "salted-snacks" => "en:salted-snacks",
            "salty-snacks" => "en:salted-snacks",
            "salty-snack" => "en:salted-snacks",
        }
    };

    my $lc_tagid;

    $lc_tagid = get_lc_tagid($synonyms_ref, "en", "category", "salted-snacks", "");
    is($lc_tagid, "en:salted-snacks");

    # simple synonyms
    $lc_tagid = get_lc_tagid($synonyms_ref, "en", "category", "salty-snacks", "");
    is($lc_tagid, "en:salted-snacks");

    # normalization
    $lc_tagid = get_lc_tagid($synonyms_ref, "en", "category", "Salty Snacks", "");
    is($lc_tagid, "en:salted-snacks");

    # stopzords removal
    $lc_tagid = get_lc_tagid($synonyms_ref, "en", "category", "The Salty Snacks", "");
    is($lc_tagid, "en:salted-snacks");

    # plaral removal
    $lc_tagid = get_lc_tagid($synonyms_ref, "en", "category", "Saltys Snacks", "");
    is($lc_tagid, "en:salted-snacks");


# sub get_lc_tagid($$$$$)
# {
# 	my $synonyms_ref = shift;
# 	my $lc = shift;
# 	my $tagtype = shift;
# 	my $tag = shift;
# 	my $warning = shift;
# 	$tag =~ s/^\s+//;  # normalize spaces
# 	$tag = normalize_percentages($tag, $lc);
# 	my $tagid = get_string_id_for_lang($lc, $tag);
# 	# search if this tag is associated to a canonical tag id
# 	my $lc_tagid = $synonyms_ref->{$lc}{$tagid};
# 	if (not defined $lc_tagid) {
# 		# try to remove stop words and plurals
# 		my $stopped_tagid = remove_stopwords($tagtype,$lc,$tagid);
# 		$stopped_tagid = remove_plurals($lc,$stopped_tagid);
# 		# and try again to see if it is associated to a canonical tag id
# 		$lc_tagid = $synonyms_ref->{$lc}{$stopped_tagid};
# 		if ($warning) {
# 			print STDERR "$warning tagid $tagid, trying stopped_tagid $stopped_tagid - result canon_tagid: " . ($lc_tagid // "") . "\n";
# 		}
# 
# 	}
# 	return $lc_tagid;
# }

}


done_testing();
