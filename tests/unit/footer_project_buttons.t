#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/$tt/;

my $layout_template = "web/common/site_layout.tt.html";

# Test for each flavor
my %test_cases = (
    off => {
        flavor => 'off',
        should_have => ['footer_obf_link', 'footer_opf_link', 'footer_opff_link', 'footer_op_link'],
        should_not_have => [],
    },
    obf => {
        flavor => 'obf',
        should_have => ['footer_opf_link', 'footer_opff_link', 'footer_op_link'],
        should_not_have => ['footer_obf_link'],
    },
    opf => {
        flavor => 'opf',
        should_have => ['footer_obf_link', 'footer_opff_link', 'footer_op_link'],
        should_not_have => ['footer_opf_link'],
    },
    opff => {
        flavor => 'opff',
        should_have => ['footer_obf_link', 'footer_opf_link', 'footer_op_link'],
        should_not_have => ['footer_opff_link'],
    },
);

foreach my $flavor (sort keys %test_cases) {
    my $rendered = "";
    my $tc = $test_cases{$flavor};
    my $vars = {
        flavor => $flavor,
        static_subdomain => "https://static.example.org",
        producers_platform_url => "https://world.pro.openfoodfacts.org/",
        options => { site_name => "Open Food Facts" },
        request => {},
        oidc_implementation_level => 0,
        edq => sub { return shift; },
        lang => sub { return shift; },
        lang_flavor => sub { return shift . "_" . $flavor; },
        f_lang => sub { return shift; },
        display_icon => sub { return ""; },
    };

    my $ok = eval { $tt->process($layout_template, $vars, \$rendered); };
    if (!$ok || $@) {
        diag("Error rendering $flavor: " . ($@ || $tt->error()));
    }
    ok($ok, "site_layout renders for $flavor");

    foreach my $must_have (@{$tc->{should_have}}) {
        like($rendered, qr/\Q$must_have\E/, "$flavor footer contains $must_have");
    }
    foreach my $must_not_have (@{$tc->{should_not_have}}) {
        unlike($rendered, qr/\Q$must_not_have\E/, "$flavor footer does NOT contain $must_not_have");
    }

    # Public platform should contain producers_platform_url button
    like($rendered, qr{href="https://world\.pro\.openfoodfacts\.org/"}, "$flavor footer contains producers platform button");
}

# Test producers platform
{
    my $rendered = "";
    my $vars = {
        flavor => 'off',
        server_options_producers_platform => 1,
        static_subdomain => "https://static.example.org",
        producers_platform_url => "https://world.pro.openfoodfacts.org/",
        options => { site_name => "Open Food Facts" },
        request => {},
        oidc_implementation_level => 0,
        edq => sub { return shift; },
        lang => sub { return shift; },
        lang_flavor => sub { return shift . "_off"; },
        f_lang => sub { return shift; },
        display_icon => sub { return ""; },
    };

    my $ok = eval { $tt->process($layout_template, $vars, \$rendered); };
    if (!$ok || $@) {
        diag("Error rendering producers platform: " . ($@ || $tt->error()));
    }
    ok($ok, "site_layout renders for producers platform");
    unlike($rendered, qr{href="https://world\.pro\.openfoodfacts\.org/"}, "producers platform footer does NOT contain producers platform button");
    like($rendered, qr/footer_obf_link/, "producers platform footer still contains footer_obf_link");
    like($rendered, qr/footer_opf_link/, "producers platform footer still contains footer_opf_link");
    like($rendered, qr/footer_opff_link/, "producers platform footer still contains footer_opff_link");
}

done_testing();
