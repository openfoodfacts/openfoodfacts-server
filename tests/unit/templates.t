#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/$tt/;

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
			# Ignore README files
			next if $file =~ /\.md$/;

			test_template($path . '/' . $file);
		}
	}
	else {
		# Skip README.md files as they are documentation, not templates
		return if $path =~ /README\.md$/;

		ok($path =~ /\.tt\./) or diag("file $path does not contain .tt.");

		$path =~ s/^\.\///;
		eval {$tt->template($path);};
		ok(not $@) or diag("failed to fetch template: $@");
	}
	return;
}

test_template(".");

my $report_problem_template = "api/knowledge-panels/report_problem/incomplete_or_incorrect_data.tt.json";

foreach my $flavor (qw(off obf opf opff)) {
	my $rendered_template = "";
	my $template_data_ref = {
		flavor => $flavor,
		static_subdomain => "https://static.example.org",
		panel => {nutripatrol_enabled => 0},
		edq => sub {return shift;},
		lang => sub {return "generic_" . shift;},
		lang_flavor => sub {return shift . "_" . $flavor;},
	};

	ok($tt->process($report_problem_template, $template_data_ref, \$rendered_template),
		"report problem template renders for the $flavor flavor");
	like(
		$rendered_template,
		qr{"subtitle": "incomplete_or_incorrect_data_subtitle_$flavor"},
		"report problem subtitle uses the $flavor translation"
	);
	like(
		$rendered_template,
		qr{https://static\.example\.org/images/logos/$flavor-logo-icon-light\.svg},
		"report problem icon uses the $flavor logo"
	);
	like(
		$rendered_template,
		qr{incomplete_or_incorrect_data_content_correct_$flavor},
		"report problem content uses the $flavor translation"
	);
	ok(-e "$www_root/images/logos/$flavor-logo-icon-light.svg", "$flavor logo asset exists");
}

done_testing();
