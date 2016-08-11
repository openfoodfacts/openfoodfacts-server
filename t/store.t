#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 1;

use ProductOpener::Store qw/:all/;

is( get_fileid('Do not challenge me!'), 'do-not-challenge-me' );
