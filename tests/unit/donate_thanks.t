#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;

use Test2::V0;
use Test2::Plugin::UTF8;
use File::Basename;

# 1. Test factorized CSS and JS files exist
my $css_file = "html/css/donate-thanks.css";
my $js_file = "html/js/donate-thanks.js";

ok(-f $css_file, "Factorized CSS file $css_file exists");
ok(-s $css_file > 500, "Factorized CSS file is non-empty");

ok(-f $js_file, "Factorized JS file $js_file exists");
ok(-s $js_file > 500, "Factorized JS file is non-empty");

# 2. Check all thanks files in html/donate/thanks/
my @thanks_files = glob("html/donate/thanks/*.html");
ok(@thanks_files >= 130, "Found at least 130 thank-you pages (found " . scalar(@thanks_files) . ")");

my @english_checks = (
    "Thank you, {name}.",
    "Your {amount} a month keeps about",
    "Your {amount} a year keeps about",
    "Your {amount} pays for about",
    "Your gift keeps product lookups free for everyone.",
    "Tell someone who looks things up too",
    "I support Open Food Facts, the free and open food database.",
    "Make it monthly?",
    "We won't ask you again for a year on this browser.",
);

foreach my $file (@thanks_files) {
    my $lang = basename($file, ".html");

    open my $fh, '<:encoding(UTF-8)', $file or die "Cannot open $file: $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    # Factorization & untranslatable checks: no inline style or script logic
    ok($content !~ /<style/i, "$file: contains no inline <style> block (factorized into CSS)");
    ok($content =~ m{<link[^>]+href="/css/donate-thanks\.css"}i, "$file: links to factorized CSS");
    ok($content =~ m{<script[^>]+src="/js/donate-thanks\.js"}i, "$file: links to factorized JS");

    # Brand term preservation
    ok($content =~ /Open Food Facts/, "$file: preserves brand name 'Open Food Facts'");

    # Template placeholder parity
    ok($content =~ /<span class="thanks-title-tpl"[^>]*>.*?\{name\}.*?<\/span>/s, "$file: title template contains {name}");
    ok($content =~ /<span class="thanks-lead-tpl"[^>]*data-interval="1 M"[^>]*>.*?\{amount\}.*?\{lookups\}.*?<\/span>/s, "$file: 1M lead template contains {amount} and {lookups}");
    ok($content =~ /<span class="thanks-lead-tpl"[^>]*data-interval="1 Y"[^>]*>.*?\{amount\}.*?\{lookups\}.*?<\/span>/s, "$file: 1Y lead template contains {amount} and {lookups}");
    ok($content =~ /<span class="thanks-lead-tpl"[^>]*data-interval="1 T"[^>]*>.*?\{amount\}.*?\{lookups\}.*?<\/span>/s, "$file: 1T lead template contains {amount} and {lookups}");
    ok($content =~ /<span class="thanks-upgrade-tpl"[^>]*>.*?\{amount\}.*?<\/span>/s, "$file: upgrade template contains {amount}");

    # Correct lang attribute
    ok($content =~ /<html[^>]+lang="\Q$lang\E"/i, "$file: html tag has correct lang='$lang'");

    # No mistranslations / unlocalized English fallback in non-English files
    unless ($lang =~ /^en(_[A-Z]{2})?$/) {
        foreach my $en_phrase (@english_checks) {
            ok($content !~ /\Q$en_phrase\E/, "$file: does not leave English fallback '$en_phrase'");
        }
    }
}

done_testing;
