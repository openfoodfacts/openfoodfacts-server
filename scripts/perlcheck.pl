#!/usr/bin/env perl

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# This script performs parallel syntax checks (perl -c) on Perl files.
# It uses native Perl File::Find for discovery and a fork-based worker pool.

use ProductOpener::PerlStandards;
use File::Find;
use Term::ANSIColor;
use Getopt::Long qw(:config);

# Parse options
my $no_fast_fail = 0;
GetOptions("no-fast-fail" => \$no_fast_fail)
	or die "Usage: $0 [--no-fast-fail] [files or directories...]\n";

# Determine number of workers
my $max_workers = $ENV{CPU_COUNT};
if (!defined $max_workers || $max_workers !~ /^\d+$/ || $max_workers < 1) {
	$max_workers = 1;
}
else {
	$max_workers = int($max_workers);
}
my $perlcheck_ignore_file = $ENV{PERLCHECK_IGNORE} || '.perlcheckignore';

sub load_ignore ($file) {
	my @patterns;
	if (-f $file) {
		open my $fh, '<', $file or die "Cannot open $file: $!";
		while (<$fh>) {
			chomp;
			# Skip blank lines and comments
			next if /^\s*$/ || /^\s*#/;
			push @patterns, gitignore_to_regex($_);
		}
		close $fh;
	}
	return @patterns;
}

sub gitignore_to_regex ($pattern) {
	my $original = $pattern;
	my $negate = ($pattern =~ s/^!//);
	my $dir_only = ($pattern =~ s{/$}{});

	# Escape regex special chars
	my $regex = $pattern;
	$regex =~ s/([.+^$()\[\]{}|\\])/\\$1/g;

	# Handle **
	$regex =~ s{/\*\*/}{/(?:[^/]*/)*?}g;
	$regex =~ s{^\*\*/}{(?:[^/]*/)*?}g;
	$regex =~ s{/\*\*$}{/(?:.*)?}g;

	# Handle * and ?
	$regex =~ s/\*/[^\\\/]*/g;
	$regex =~ s/\?/[^\\\/]/g;

	if ($pattern =~ m{/}) {
		if ($pattern =~ m{^/}) {
			$regex = '^' . substr($regex, 1);
		}
		else {
			$regex = '^' . $regex;
		}
	}
	else {
		$regex = '(^|/)' . $regex;
	}

	if ($dir_only) {
		$regex .= '/';
	}
	else {
		$regex .= '(?:/|$)';
	}

	return {
		regex => qr/$regex/,
		negate => $negate,
		original => $original,
	};
}

my @ignore_patterns = load_ignore($perlcheck_ignore_file);

sub is_ignored ($path, $is_dir) {
	my $ignored = 0;
	my $test_path = $path;
	$test_path .= '/' if $is_dir;

	for my $p (@ignore_patterns) {
		if ($test_path =~ $p->{regex}) {
			$ignored = $p->{negate} ? 0 : 1;
		}
	}
	return $ignored;
}

# Find files to check using native File::Find
my @files;
my @roots = @ARGV;
if (!@roots) {
	@roots = ('.');
}

# Normalize "./path" to "path"
sub normalize_path ($path) {
	$path =~ s/^\.\///;
	return $path;
}

# Warn if explicitly specified files are in the excludes list
my %explicit_files;
foreach my $arg (@roots) {
	if (!-f $arg) {
		next;
	}
	my $path = $arg;
	$path = normalize_path($path);
	if (is_ignored($path, 0)) {
		print colored("warning: ", "bold yellow")
			. "File '$path' is explicitly specified but matches an exclude pattern. Skipping.\n";
	}
	else {
		$explicit_files{$path} = 1;
	}

}

# Collect files to check, applying excludes and pruning directories
sub on_wanted() {
	my $path = $File::Find::name;
	$path = normalize_path($path);

	# If the file was explicitly passed on the command line and not excluded, we always check it
	if ($explicit_files{$path}) {
		push @files, $path if $path =~ /\.(pl|pm|t)$/;
		return;
	}

	# Prune hidden directories (except .) and obsolete directories, or if ignored
	if (-d $_) {
		if (($path ne '.' && $path =~ m{(^|/)\.}) || $path =~ m{(^|/)obsolete($|/)} || is_ignored($path, 1)) {
			$File::Find::prune = 1;
			return;
		}
	}
	# Filter for Perl files
	return unless -f $_;
	return unless $path =~ /\.(pl|pm|t)$/;

	# Skip explicitly excluded files
	return if is_ignored($path, 0);

	push @files, $path;
	return;
}

# Run the find with our custom wanted function
find({wanted => \&on_wanted, no_chdir => 1,}, @roots);

if (!@files) {
	print colored("No Perl files to check.\n", "bold white");
	exit 0;
}

my $total = scalar @files;
print colored("Checking $total files using $max_workers workers ...\n", "bold white");

my %running;    # pid => { file => ..., pipe => ... }
my @failed;
my $finished = 0;
my $started = 0;
my $fast_failing = 0;

sub terminate_workers() {
	my @pids = keys %running;
	return unless @pids;
	kill 'TERM', @pids;
	# Give workers a moment to terminate gracefully
	sleep 1;
	kill 'KILL', @pids;
	return;
}

sub wait_for_worker() {
	my $pid = wait();
	if ($pid <= 0) {
		return;    # No children
	}

	my $job = delete $running{$pid};
	my $file = $job->{file};
	my $fh = $job->{pipe};

	# Read any output from the pipe
	my $output = do {local $/; <$fh>};
	close $fh;

	if ($? != 0 && !$fast_failing) {
		# Check if it was a real failure or if we killed it
		# (If we killed it, $? will indicate a signal)
		my $was_signaled = $? & 127;

		if (!$was_signaled) {
			print "\n" . colored("error: ", "bold red") . "Syntax error in $file:\n";
			# Indent each line of the output with a tab and color it red
			my $indented_output = $output;
			$indented_output =~ s/^/\t/mg;
			print colored($indented_output, "red") . "\n";
			push @failed, $file;

			if (!$no_fast_fail) {
				$fast_failing = 1;
				print colored("warning: ", "bold yellow")
					. "Fast-fail enabled, terminating remaining workers... (pass --no-fast-fail to disable)\n";
				terminate_workers();
			}
		}
	}
	$finished++;
	return;
}

# Set up signal handling for graceful termination
my $interrupted = 0;
$SIG{INT} = $SIG{TERM} = sub {
	$interrupted = 1;
	print "\n" . colored("Interrupted, terminating workers...\n", "bold white");
	local $SIG{INT} = 'IGNORE';    # Avoid recursion
	local $SIG{TERM} = 'IGNORE';
	terminate_workers();
	exit 1;
};

# Ensure stdout is unbuffered for smooth progress updates
$| = 1;

foreach my $file (@files) {
	# If we are in fast-fail mode and a failure has occurred, stop spawning new workers
	last if $fast_failing;

	$started++;

	# Limit the number of concurrent workers
	while (keys %running >= $max_workers) {
		wait_for_worker();
	}

	# Print progress: "(started/total) Checking [file]" in light gray (standard white)
	print colored(sprintf("\r(%d/%d) Checking %-60.60s", $started, $total, $file), "white");

	# Create a pipe to capture child output
	pipe(my $read_fh, my $write_fh) or die colored("error: ", "bold red") . "Pipe failed: $!";

	my $pid = fork();
	if (!defined $pid) {
		die colored("error: ", "bold red") . "Fork failed: $!";
	}

	if ($pid == 0) {
		# Child process
		close $read_fh;

		# Redirect STDOUT and STDERR to the pipe
		open STDOUT, '>&', $write_fh or die "Can't dup STDOUT: $!";
		open STDERR, '>&', $write_fh or die "Can't dup STDERR: $!";
		close $write_fh;

		$ENV{PO_NO_LOAD_DATA} = 1;

		# Use the current interpreter and its include paths
		my @inc_flags = map {"-I$_"} @INC;

		exec($^X, @inc_flags, '-CS', '-c', $file);
		die "Exec failed: $!";
	}
	else {
		# Parent process
		close $write_fh;
		$running{$pid} = {file => $file, pipe => $read_fh};
	}
}

# Wait for all remaining workers to finish
while (keys %running > 0) {
	wait_for_worker();
}

print "\r" . (" " x 80) . "\r";

if (@failed) {
	print colored("error: ", "bold red") . "Check failed. See above for details.\n";
	exit 1;
}
else {
	print colored("All files passed syntax check.\n", "bold green");
	exit 0;
}
