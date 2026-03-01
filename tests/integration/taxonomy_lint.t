use strict;
use warnings;

use Test::More;
use File::Find;
use File::Basename;
use File::Spec;
use FindBin;
use IPC::Open3;
use IO::Select;
use Symbol qw(gensym);

# ------------------------------------------------------------
# Taxonomy validation
#
# This test runs the canonical taxonomy linter in --check mode
# to prevent syntax regressions in taxonomy files.
# ------------------------------------------------------------

sub run_taxonomy_lint {
	my ($lint_script, $files_ref) = @_;
	my $err = gensym;
	my @cmd = ($^X, $lint_script, '--check', @$files_ref);
	my $pid = open3(my $in, my $out, $err, @cmd);
	close $in;
	my $output = '';
	my $selector = IO::Select->new($out, $err);
	while (my @ready = $selector->can_read) {
		for my $fh (@ready) {
			my $line = <$fh>;
			if (defined $line) {
				$output .= $line;
			}
			else {
				$selector->remove($fh);
				close $fh;
			}
		}
	}
	waitpid($pid, 0);
	my $exit_code = $? >> 8;
	return ($exit_code, $output);
}

# ------------------------------------------------------------
# Discover taxonomy files
# ------------------------------------------------------------

my $repo_root = File::Spec->catdir($FindBin::Bin, File::Spec->updir, File::Spec->updir);
chdir $repo_root or BAIL_OUT("Could not chdir to $repo_root: $!");

my $lint_script = File::Spec->catfile($repo_root, 'scripts', 'taxonomies', 'lint_taxonomy.pl');
BAIL_OUT("Missing lint script at $lint_script") unless -f $lint_script;

my @files;
find(
	sub {
		return unless -f $_;
		return unless /\.txt$/;
		return if $File::Find::name =~ m{/old/|/unused/};

		push @files, $File::Find::name;
	},
	'taxonomies'
);

ok(@files > 0, "Found taxonomy files");

my ($exit_code, $output) = run_taxonomy_lint($lint_script, \@files);
is($exit_code, 0, 'Linting taxonomies (lint_taxonomy.pl --check)')
	or diag($output || "Lint failed with exit code $exit_code");

done_testing();
