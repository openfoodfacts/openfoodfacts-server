#!/usr/bin/perl -w

use ProductOpener::PerlStandards;
use ProductOpener::Users;

my $type = 'add';
my $rndm = ProductOpener::Users::generate_token(4);
my $request_ref = {};
my $uid = $rndm . 0;
my $user_ref = {
	email => $uid . '@example.org',
	userid => $uid,
	name => $uid,
	password => 'testtest',
	preferred_language => 'de',
	country => 'de:Germany'
};
my @errors = ();
ProductOpener::Users::check_user_form($request_ref, $type, $user_ref, \@errors);

if ($#errors > 0) {
	use Data::Dumper;
	print STDERR Dumper(\@errors) . "\n";
	return 1;
}

for (my $i = 1; $i <= 200000; $i++) {
	my $uid = $rndm . $i;
	$user_ref->{email} = $uid . '@example.org';
	$user_ref->{userid} = $uid;
	$user_ref->{name} = $uid;
	ProductOpener::Users::process_user_form($type, $user_ref, $request_ref);
}
