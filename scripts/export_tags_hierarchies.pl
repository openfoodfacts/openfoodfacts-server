#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2012';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Ingredients qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Lang qw/:all/;


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

