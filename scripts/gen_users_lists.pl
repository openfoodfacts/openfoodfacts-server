#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2015';
use utf8;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Users qw/:all/;

my @userids;

my %emails = ();

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
	
	$userid =~ s/\.sto$//;
	
	my $email = $user_ref->{email};
	
	if ((defined $email) and ($email =~/\@/)) {
		defined $emails{$email} or $emails{$email} = [];
		push @{$emails{$email}}, $userid;
	}
}

store("$data_root/users_emails.sto", \%emails);

exit(0);

