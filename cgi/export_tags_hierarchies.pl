#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Tags qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Images qw/:all/;
use Blogs::Lang qw/:all/;
use Blogs::Mail qw/:all/;
use Blogs::Products qw/:all/;
use Blogs::Food qw/:all/;
use Blogs::Ingredients qw/:all/;
use Blogs::Images qw/:all/;
use Blogs::Lang qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON;
# load all tags hierarchies

print STDERR "Tags.pm - exporting tags hierarchies\n";
opendir DH2, "$data_root/lang" or die "Couldn't open $data_root/lang : $!";
foreach my $langid (readdir(DH2)) {
	next if $langid eq '.';
	next if $langid eq '..';
	print STDERR "Tags.pm - reading tagtypes for lang $langid\n";
	next if ((length($langid) ne 2) and not ($langid eq 'other'));

	if (-e "$data_root/lang/$langid/tags") {
		opendir DH, "$data_root/lang/$langid/tags" or die "Couldn't open the current directory: $!";
		foreach my $tagtype (readdir(DH)) {
			next if $tagtype !~ /(.*)\.txt/;
			$tagtype = $1;
			print STDERR "Tags: exporting tagtype $langid/$tagtype\n";	
			$lc = $langid;			
			export_tags_hierarchy($langid, $tagtype);
		}
		closedir(DH);
	}

	
}
closedir(DH2);

exit(0);

