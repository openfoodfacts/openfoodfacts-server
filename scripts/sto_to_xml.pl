#!/usr/bin/perl

use Modern::Perl '2012';

use Data::Dumper;

use Storable qw(lock_store lock_nstore lock_retrieve);

sub retrieve {
	my $file = shift @_;
	# If the file does not exist, return undef.
	if (! -e $file) {
		return;
	}
	return lock_retrieve($file);
}

print $ARGV[0];

my $ref = retrieve($ARGV[0]);


print Dumper($ref) . "\n" ;
