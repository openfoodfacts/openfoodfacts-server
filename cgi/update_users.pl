#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;


my @userids;

if (scalar $#userids < 0) {
	opendir DH, "$data_root/users" or die "Couldn't open the current directory: $!";
	@userids = sort(readdir(DH));
	closedir(DH);
}

foreach my $userid (@userids)
{
	next if $userid eq "." or $userid eq "..";
	next if $userid eq 'all';

	my $user_ref = retrieve("$data_root/users/$userid");
	
	my @keys = qw(name email password twitter);
	
	foreach my $key (@keys) {
			utf8::is_utf8($user_ref->{$key}) or utf8::decode($user_ref->{$key});
	}
	
	store("$data_root/users/$userid", $user_ref);
}

exit(0);

