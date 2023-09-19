#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Users qw/:all/;

foreach my $name ("click here", "go forms.yandex.ru", "https://test.me") {
	ok(is_suspicious_name($name), "$name is a suspicious name");
}

foreach my $name ("danilo.go", 'roberto@test.me', "Lalilou", "Dan stanley") {
	ok(!is_suspicious_name($name), "$name is not a suspicious name");
}

done_testing();
