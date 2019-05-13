#!/usr/bin/perl -w

use Modern::Perl '2012';

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Display qw/:all/;
use ProductOpener::Lang qw/:all/;

# date tests
my $t = 1472292529;
$lc = 'en';
is( display_date($t), 'August 27, 2016 at 12:08:49 PM CEST' );
is( display_date_tag($t), '<time datetime="2016-08-27T12:08:49">August 27, 2016 at 12:08:49 PM CEST</time>' );
$lc = 'de';
is( display_date($t), '27. August 2016 um 12:08:49 CEST' );
is( display_date_tag($t), '<time datetime="2016-08-27T12:08:49">27. August 2016 um 12:08:49 CEST</time>' );

done_testing();
