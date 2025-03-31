use ProductOpener::PerlStandards;
use Test2::V0;
use FindBin qw/$Bin/;
use Test::Pod;
use Path::Tiny;

# files to inspect
my $root = path($Bin)->parent(2);
my @poddirs = map {$root->child($_)->canonpath} qw/lib cgi scripts/;
my @podfiles = all_pod_files(@poddirs);

foreach my $file (@podfiles) {

	my $short_file = path($file)->relative($root);

	# regular check for POD correctness
	pod_file_ok($file, "POD syntax in $short_file");

	# additional check : it's better if =cut directives are preceded by a blank line
	#
	# see L<perpod> : To end a Pod block, use a blank line, then a line
	# beginning with "=cut", and a blank line after it. This lets Perl
	# (and the Pod formatter) know that this is where Perl code is
	# resuming. (The blank line before the "=cut" is not technically
	# necessary, but many older Pod processors require it.)
	my @lines = path($file)->lines_utf8;
	my @pod_lines = grep {$lines[$_] =~ /^=/} 0 .. $#lines;
	my @bad_pod = grep {$lines[$_ - 1] !~ /^\h*$/ || $lines[$_ + 1] !~ /^\h*$/} @pod_lines;
	ok !@bad_pod, "empty lines around = directives in $short_file: " . join(", ", @bad_pod);
}

done_testing;
