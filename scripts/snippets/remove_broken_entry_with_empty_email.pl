#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Store qw/:all/;

my $emails_ref = retrieve("$BASE_DIRS{USERS}/users_emails.sto");

if (defined $emails_ref->{''}) {
	delete $emails_ref->{''};
	store("$BASE_DIRS{USERS}/users_emails.sto", $emails_ref);
}
