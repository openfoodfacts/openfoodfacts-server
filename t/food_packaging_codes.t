#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Number::Delta relative => 1.001;
use Log::Any::Adapter 'TAP';

use ProductOpener::Tags qw/:all/;
use ProductOpener::Food qw/:all/;

is(normalize_packager_codes("emb54253"), "EMB 54253");

is(normalize_packager_codes("ES 12.0664/C CE"), "ES 12.0664/C EC");
is(normalize_packager_codes("ES 12.0664/C EC"), "ES 12.0664/C EC");
is(normalize_packager_codes("ES 12.0664/C EC, ES 14.0434/A EC"), "ES 12.0664/C EC, ES 14.0434/A EC");

done_testing();
