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
	
	my $first = '';
	if (! exists $user_ref->{discussion}) {
		$first = 'first';
	}
	
	# print $user_ref->{email} . "\tnews_$user_ref->{newsletter}$first\tdiscussion_$user_ref->{discussion}\n";
	
	if (1 or $user_ref->{newsletter} or not exists $user_ref->{discussion}) {
		print lc($user_ref->{email}) . "\t$userid\t" . $user_ref->{name} . "\n";
	}
	
	if ($user_ref->{twitter} ne '') {
#		print "\@" . $user_ref->{twitter} . " ";
	}
}

exit(0);

