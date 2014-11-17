#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Index qw/:all/;
use Getopt::Long;

use XML::FeedPP;

use POSIX qw(locale_h);
use locale;
setlocale(LC_CTYPE, "fr_FR");	# May need to be changed depending on system

my $rss;
my $lang;

GetOptions ('rss=s' => \$rss, 'lang=s' => \$lang);

if (not defined $rss) {
	print STDERR "Specify the RSS url via --rss\n";
	exit;
}

if (not defined $lang) {
        print STDERR "Specify the lang via --lang\n";
        exit;
}



open(OUT, ">:encoding(UTF-8)", "$data_root/lang/$lang/texts/blog.html");

my $feed = XML::FeedPP->new($rss);

my $html;
		
my $i = 5;		
		
foreach my $entry ($feed->get_item()) {
		
	$html .= "&rarr; <a href=\"" . $entry->link . "\">" . decode_html_entities($entry->title) . "</a><br />";
	$i--;
	$i == 0 and last;
}

print OUT $html;

close(OUT);

exit(0);

