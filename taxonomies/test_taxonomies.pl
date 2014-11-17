#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Blogs qw/:all/;
use Blogs::Tags qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Images qw/:all/;
use Blogs::Lang qw/:all/;
use Blogs::Mail qw/:all/;
use Blogs::Products qw/:all/;
use Blogs::Food qw/:all/;
use Blogs::Ingredients qw/:all/;
use Blogs::Images qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;

use Getopt::Long;


my $tag;
my $tagtype = 'labels';
my $taglc = 'fr';
my $targetlc = 'fr';

GetOptions ('tags=s' => \$tag, 'type=s' => \$tagtype, 'taglc=s'=>\$taglc, 'targetlc=s'=>\$targetlc);

#Blogs::Display::init();

$lc = $targetlc;

print "canonicalize_taxonomy_tag($taglc,$tagtype,$tag)\n";

print canonicalize_taxonomy_tag($taglc,$tagtype,$tag) . "\n\n";

print "display_taxonomy_tag($targetlc,$taglc,$tagtype,$tag)\n";

print display_taxonomy_tag($targetlc,$tagtype,$tag) . "\n\n";

print "display_taxonomy_tag_link($targetlc,$taglc,$tagtype,$tag)\n";

print display_taxonomy_tag_link($targetlc,$tagtype,$tag) . "\n\n";

print "canonicalize_tag_link($tagtype,$tag)\n";

print canonicalize_tag_link($tagtype,$tag) . "\n\n";

print "gen_tags_hierarchy_taxonomy($taglc, $tagtype, $tag)\n";

my @tags = gen_tags_hierarchy_taxonomy($taglc,$tagtype, $tag);

foreach my $t (@tags) {

	print "> $t - " . canonicalize_taxonomy_tag($taglc,$tagtype, $t) . "\n";
}

print "\n";
print "display_tags_hierarchy_taxonomy\n";
print display_tags_hierarchy_taxonomy($targetlc,$tagtype, \@tags) . "\n";

print "\ndisplay_parents_and_children_taxonomy($tagtype,$tag)\n";

print display_parents_and_children_taxonomy($tagtype,$tag) . "\n";

exit(0);

