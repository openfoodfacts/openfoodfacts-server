#!/usr/bin/perl -w

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

use ProductOpener::PerlStandards;
use Term::ANSIColor;

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;

use Log::Any qw($log);
use Log::Log4perl qw(:levels);
use Log::Log4perl::Layout::PatternLayout;
use Log::Any::Adapter;
use JSON::MaybeXS;
use Term::ANSIColor;
use Getopt::Long;

# Define custom conversion specifiers
# %S: Serialized MDC context as JSON
Log::Log4perl::Layout::PatternLayout::add_global_cspec(
	'S',
	sub {
		my $context = Log::Log4perl::MDC->get_context;
		return JSON::MaybeXS->new->allow_nonref->convert_blessed->canonical->encode($context);
	}
);

# %K: Colored priority (log level)
Log::Log4perl::Layout::PatternLayout::add_global_cspec(
	'K',
	sub {
		my ($layout, $message, $category, $priority) = @_;
		my $color = 'reset';
		if ($priority eq 'ERROR' or $priority eq 'FATAL') {$color = 'red';}
		elsif ($priority eq 'WARN') {$color = 'yellow';}
		elsif ($priority eq 'DEBUG') {$color = 'cyan';}
		return ($color eq 'reset') ? $priority : color($color) . $priority . color('reset');
	}
);

# Init log4perl to log to screen
my $log_level = $ENV{LOG_LEVEL} // 'INFO';
Log::Log4perl->init(
	{
		'log4perl.rootLogger' => "$log_level, Screen",
		'log4perl.appender.Screen' => 'Log::Log4perl::Appender::Screen',
		'log4perl.appender.Screen.stderr' => 1,
		'log4perl.appender.Screen.layout' => 'PatternLayout',
		'log4perl.appender.Screen.layout.ConversionPattern' => '[%d] [%K] %m %S%n',
	}
);

Log::Any::Adapter->set('Log4perl');    # Send all logs to Log::Log4perl

my $tagtype = $ARGV[0];

my $publish = 1;
my $max_workers = 1;
my $verbose = 0;

GetOptions(
	"publish=i" => \$publish,
	"jobs|j=i" => \$max_workers,
	"verbose|v" => \$verbose,
) or die("Error in command line arguments\n");

$tagtype = '*' if !defined $tagtype || $tagtype eq '';

my $IS_GITHUB_CI = $ENV{GITHUB_ACTIONS} // 0;

sub print_error ($msg) {
	print STDERR colored("error: ", 'red'), "$msg\n";
	return;
}

sub print_success ($msg) {
	print colored("$msg", 'green bold'), "\n";
	return;
}

sub print_info ($msg) {
	print colored("$msg", 'bold'), "\n";
	return;
}

my $is_terminal = -t STDOUT;
my $built_count = 0;
my $total_count = 0;

sub print_status ($children) {
	return unless $is_terminal && !$IS_GITHUB_CI;
	my @active = sort map {$_->{taxonomy}} values %$children;
	if (@active) {
		my $label = colored("Building ($built_count/$total_count): ", 'bold green');
		my $names = join(", ", @active);
		# \r returns to start of line, \e[K clears to end of line
		print "\r" . $label . $names . "\e[K";
		$| = 1;    # Flush STDOUT
	}
}

sub clear_status () {
	return unless $is_terminal && !$IS_GITHUB_CI;
	print "\r\e[K";
	$| = 1;
}

sub build_taxonomy ($taxonomy) {
	# We don't print "Building $taxonomy..." here as it's handled by print_status in the parent.
	# But we print it in the child's log in case of error.
	print "Building $taxonomy taxonomy...\n";
	my @errors = ProductOpener::Tags::build_tags_taxonomy($taxonomy, $publish);
	if (@errors) {
		print_error("Failed to build $taxonomy taxonomy with " . scalar(@errors) . " error(s):");
		foreach my $error (@errors) {
			print_error(ProductOpener::Tags::_taxonomy_error_display($error));
		}
		return 0;
	}
	else {
		print "$taxonomy taxonomy built successfully\n";
		return 1;
	}
}

sub wait_for_child ($children, $has_any_errors_ref) {
	my $pid = wait();
	if ($pid > 0 && exists $children->{$pid}) {
		my $child = delete $children->{$pid};
		my $fh = $child->{reader};
		my $log = do {local $/; <$fh>};
		close $fh;

		$built_count++;

		if ($? != 0) {
			$$has_any_errors_ref = 1;
			clear_status();
			print map {colored("[$child->{taxonomy}] ", 'red') . $_ . "\n"} split("\n", $log);
		}
		elsif ($verbose) {
			clear_status();
			print map {colored("[$child->{taxonomy}] ", 'green') . $_ . "\n"} split("\n", $log);
		}
		print_status($children);
	}
}

print_info("Building tags taxonomy (tagtype: $tagtype, max_workers: $max_workers)");

my @taxonomy_list;
if ($tagtype eq '*') {
	@taxonomy_list = (@ProductOpener::Tags::taxonomy_fields, 'test');
	# Exclude "traces" and any taxonomy starting with "data_quality_"
	@taxonomy_list = grep {$_ ne "traces" && rindex($_, 'data_quality_', 0) != 0}
		sort @taxonomy_list;
	print_info("Found " . scalar(@taxonomy_list) . " taxonomies to build: " . join(", ", @taxonomy_list));
}
else {
	@taxonomy_list = ($tagtype);
}

$total_count = scalar @taxonomy_list;

my $has_any_errors = 0;
my %children;    ## { pid => { taxonomy => ..., reader => ... } }

foreach my $taxonomy (@taxonomy_list) {
	# If we reached the max number of workers, wait for one to finish
	while (keys %children >= $max_workers) {
		wait_for_child(\%children, \$has_any_errors);
	}

	my ($reader, $writer);
	pipe($reader, $writer) or die "Could not open pipe: $!";

	my $pid = fork();
	if (!defined $pid) {
		die "Could not fork: $!";
	}
	if ($pid == 0) {
		# Child process
		close $reader;
		# Redirect STDOUT and STDERR to the pipe
		open(STDOUT, ">&", $writer) or die "Could not redirect STDOUT: $!";
		open(STDERR, ">&", $writer) or die "Could not redirect STDERR: $!";
		close $writer;

		my $success = build_taxonomy($taxonomy);
		exit($success ? 0 : 1);
	}
	else {
		# Parent process
		close $writer;
		$children{$pid} = {
			taxonomy => $taxonomy,
			reader => $reader,
		};
		print_status(\%children);
	}
}

# Wait for all remaining children
while (keys %children > 0) {
	wait_for_child(\%children, \$has_any_errors);
}

clear_status();

if (!$has_any_errors) {
	if ($tagtype eq '*') {
		print_success("All taxonomies built successfully");
	}
	else {
		print_success("$tagtype taxonomy built successfully");
	}
}

exit($has_any_errors ? 1 : 0);
