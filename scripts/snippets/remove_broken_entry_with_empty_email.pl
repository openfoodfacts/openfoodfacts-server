#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;

my $emails_ref = retrieve("$data_root/users/users_emails.sto");

if (defined $emails_ref->{''}) {
	delete $emails_ref->{''};
	store("$data_root/users/users_emails.sto", $emails_ref);
}
