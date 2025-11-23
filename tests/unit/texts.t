#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Texts
	qw/%texts_translated_route_to_text_id %texts init_translated_text_routes_for_all_languages load_texts_from_lang_directory/;

init_translated_text_routes_for_all_languages();
load_texts_from_lang_directory();

# The translated routes are initialized when the module is loaded
# Check that the French route 'decouvrir' maps to 'discover'
is($texts_translated_route_to_text_id{'decouvrir'}, 'discover', 'French route decouvrir maps to discover');

# The texts are loaded when the module is loaded
# Check that the 'discover' text is available in English and French
ok(exists $texts{'discover'}{'en'}, 'Discover text available in English');
ok(exists $texts{'discover'}{'fr'}, 'Discover text available in French');

done_testing();
