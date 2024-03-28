use utf8;
use strict;
use warnings;
use Test::More;
use FindBin qw/$Bin/;
use Test::Pod;
use Path::Tiny;

# files to inspect
my @poddirs = ("$Bin/../lib", "$Bin/../cgi", "$Bin/../scripts" );
my @podfiles = all_pod_files( @poddirs );


foreach my $file (@podfiles) {

	# POD correctness
	pod_file_ok($file, "POD syntax in $file");


	# additional check : its better if =cut directives are preceded by a blank line
	#
	# see L<perpod> : To end a Pod block, use a blank line, then a line
	# beginning with "=cut", and a blank line after it. This lets Perl
	# (and the Pod formatter) know that this is where Perl code is
	# resuming. (The blank line before the "=cut" is not technically
	# necessary, but many older Pod processors require it.)
	my @lines      = path($file)->lines_utf8;
	my @pod_lines  = grep {$lines[$_] =~ /^=/} 0 .. $#lines;
	my @bad_pod    = grep {$lines[$_ - 1] !~ /^\h*$/ || $lines[$_ + 1] !~ /^\h*$/} @pod_lines;
	ok !@bad_pod, "empty lines around = directives in $file: " . join(", ", @bad_pod); 
}


done_testing;
