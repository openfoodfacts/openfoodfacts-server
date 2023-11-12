#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test::More;
use Log::Any::Adapter 'TAP';

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;

# Recursive function to go through the templates directory and compile
# every template to check for errors.

# Note that only compilation errors will be found.
# Runtime errors (e.g. a scalar instead of a list etc.) will not be tested.

sub test_template($);

sub test_template($) {

	my $path = shift;
	my $full_path = "$data_root/templates/" . $path;

	if (-d $full_path) {
		my $dh;
		opendir $dh, $full_path or die("Could not open $full_path directory: $!\n");
		foreach my $file (sort readdir($dh)) {
			chomp($file);
			next if $file eq '.';
			next if $file eq '..';

			test_template($path . '/' . $file);
		}
	}
	else {

		ok($path =~ /\.tt\./) or diag("file $path does not contain .tt.");

		$path =~ s/^\.\///;
		eval {$tt->template($path);};
		ok(not $@) or diag("failed to fetch template: $@");
	}
	return;
}

test_template(".");

done_testing();
