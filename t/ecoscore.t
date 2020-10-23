#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::Ecoscore qw/:all/;

load_agribalyse_data();

# Taxonomy tags used by EcoScore.pm that should not be renamed
# (or that should be renamed in the code and tests as well).

my %tags = (
labels => [
	"fr:nature-et-progres",
	"fr:bio-coherence",
	"en:demeter",
	
	"fr:ab-agriculture-biologique",
	"en:eu-organic",
	
	"fr:haute-valeur-environnementale",
	"en:utz-certified",
	"en:rainforest-alliance",
	"en:fairtrade-international",
	"fr:bleu-blanc-coeur",
	"fr:label-rouge",
	"en:sustainable-seafood-msc",
	"en:responsible-aquaculture-asc",
	],
categories => [
	"en:beef",
	"en:lamb-meat",
	"en:veal-meat",
],
);

foreach my $tagtype (keys %tags) {

	foreach my $tagid (@{$tags{$tagtype}}) {
		is(canonicalize_taxonomy_tag("en", $tagtype, $tagid), $tagid);
	}
}

my @tests = (

[ { lc=>"en" }, undef ],
[ { lc=>"en", categories_tags=>["en:some-unknown-category"] }, undef ],
[ { lc=>"en", categories_tags=>["en:butters"] }, 35.3946474732019 ],
[ { lc=>"en", categories_tags=>["en:butters"], labels_tags=>["fr:ab-agriculture-biologique"] }, 50.3946474732019 ],

);

foreach my $test_ref (@tests) {

	my $product_ref = $test_ref->[0];
	compute_ecoscore($product_ref);

	is($product_ref->{ecoscore_score}, $test_ref->[1]) or diag explain $product_ref->{ecoscore_data};
}

done_testing();
