#!/usr/bin/env perl

# Lightweight taxonomy linter.
#
# Speed: this script avoids loading the full Product Opener environment and is
# intended for quick local passes on large taxonomy files. On a ~100k-line
# taxonomy such as taxonomies/food/ingredients.txt, it should typically run in
# about a second on a developer machine.
#
# Disclaimer: this is not a full replacement for lint_taxonomy.pl. It mirrors
# the lightweight structural parts of the official linter: entry parsing,
# duplicate language/property detection, whitespace/comma normalization and
# entry sorting. It deliberately does not run ProductOpener-dependent checks,
# especially taxonomy-backed property canonicalization.

use strict;
use warnings;
use utf8;
use File::Copy qw(move);
use File::Temp qw(tempfile);
use Getopt::Long qw(GetOptions);

binmode STDIN, ":encoding(UTF-8)";
binmode STDOUT, ":encoding(UTF-8)";
binmode STDERR, ":encoding(UTF-8)";

my $is_check;
my $no_sort;
GetOptions(
	"check" => \$is_check,
	"no-sort" => \$no_sort,
) or die "usage: $0 [--check] [--no-sort] taxonomy.txt [...]\n";

my @files = @ARGV;
die "usage: $0 [--check] [--no-sort] taxonomy.txt [...]\n" unless @files;

my $language_prefix_re = qr/([a-zA-Z]{2,3}(?:[-_][a-zA-Z]{2,4})?)/;
my $current_file;

sub cmp_on_language {
	my ($a, $b) = @_;
	$a = lc($a);
	$b = lc($b);
	my ($a_prefix, $b_prefix);
	if ($a =~ /^([\w-]+):([a-zA-Z]{2,3}(?:[-_][a-zA-Z]{2,4})?)$/) {
		$a_prefix = $1;
		$a = $2;
	}
	if ($b =~ /^([\w-]+):([a-zA-Z]{2,3}(?:[-_][a-zA-Z]{2,4})?)$/) {
		$b_prefix = $1;
		$b = $2;
	}
	if ($a_prefix && $b_prefix && ($a_prefix ne $b_prefix)) {
		return $a_prefix cmp $b_prefix;
	}
	return 0 if $a eq $b;
	return -1 if $a eq "xx";
	return 1 if $b eq "xx";
	return -1 if $a eq "en";
	return 1 if $b eq "en";
	return $a cmp $b;
}

sub normalized_line {
	my ($item) = @_;
	my $line = $item->{line};
	my $type = $item->{type};
	my $normalize_commas = (($type eq "entry_lc") || ($type eq "entry_id") || ($type eq "synonyms") || ($type eq "stopwords"));
	if ($type eq "parent") {
		$line =~ s/^< *([^:]+): *(.+)/< $1: $2/;
	}
	elsif (($type eq "property") || ($type eq "stopwords") || ($type eq "synonyms")) {
		$line =~ s/^([^:]+): *([^:]+): */$1:$2: /;
	}
	else {
		$line =~ s/^([^:]+): */$1: /;
	}
	$line =~ s/ +$//g;
	if ($normalize_commas) {
		$line =~ s/,+/,/g;
		$line =~ s/[ ,]+$//g;
		$line =~ s/(\d),(\d)/$1__LIGHT_LINT_DECIMAL_COMMA__$2/g;
		$line =~ s/\\,/\\__LIGHT_LINT_ESCAPED_COMMA__/g;
		$line =~ s/,( )*/, /g;
		$line =~ s/__LIGHT_LINT_DECIMAL_COMMA__/,/g;
		$line =~ s/__LIGHT_LINT_ESCAPED_COMMA__/,/g;
	}
	return $line;
}

sub lint_entry {
	my ($entry) = @_;
	return join("", @{$entry->{original_lines}}) if @{$entry->{errors}};

	my @out;
	my @parents = $no_sort ? @{$entry->{parents}} : sort { $a->{line} cmp $b->{line} } @{$entry->{parents}};
	for my $parent (@parents) {
		push @out, @{$parent->{previous}}, normalized_line($parent);
	}
	if ($entry->{entry_id_line}) {
		push @out, @{$entry->{entry_id_line}{previous}}, normalized_line($entry->{entry_id_line});
	}
	my @entry_keys = $no_sort
		? sort { $entry->{entries}{$a}{line_num} <=> $entry->{entries}{$b}{line_num} } keys %{$entry->{entries}}
		: sort { cmp_on_language($a, $b) } keys %{$entry->{entries}};
	for my $key (@entry_keys) {
		push @out, @{$entry->{entries}{$key}{previous}}, normalized_line($entry->{entries}{$key});
	}
	my @prop_keys = $no_sort
		? sort { $entry->{props}{$a}{line_num} <=> $entry->{props}{$b}{line_num} } keys %{$entry->{props}}
		: sort { cmp_on_language($a, $b) } keys %{$entry->{props}};
	for my $key (@prop_keys) {
		push @out, @{$entry->{props}{$key}{previous}}, normalized_line($entry->{props}{$key});
	}
	push @out, @{$entry->{tail_lines}};
	return join("", @out);
}

sub new_entry {
	my ($start_line) = @_;
	return {
		parents => [],
		entry_id_line => undef,
		entries => {},
		props => {},
		original_lines => [],
		tail_lines => [],
		errors => [],
		start_line => $start_line,
	};
}

sub add_error {
	my ($entry, $line_num, $msg) = @_;
	push @{$entry->{errors}}, "$current_file:$line_num: $msg";
}

sub lint_file {
	my ($file) = @_;
	$current_file = $file;
	open(my $in, "<:encoding(UTF-8)", $file) or die "can't open $file: $!\n";
	my @lines = <$in>;
	close($in);
	push @lines, "\n" unless @lines && $lines[-1] =~ /^\s*$/;

	my @outputs;
	my @errors;
	my $entry = new_entry(1);
	my @previous;
	my $line_num = 0;

	for my $line (@lines) {
		$line_num++;
		push @{$entry->{original_lines}}, $line;

		if ($line =~ /^\s*$/) {
			push @previous, "\n";
			$entry->{tail_lines} = [@previous];
			push @errors, @{$entry->{errors}};
			push @outputs, lint_entry($entry);
			$entry = new_entry($line_num + 1);
			@previous = ();
			next;
		}
		if ($line =~ /^(synonyms|stopwords):/i) {
			my $type = $1;
			if (@{$entry->{parents}} || $entry->{entry_id_line} || keys %{$entry->{entries}} || keys %{$entry->{props}}) {
				add_error($entry, $line_num, "$type surrounded by other lines");
			}
			$entry->{entry_id_line} = {line => $line, previous => [@previous], line_num => $line_num, type => lc($type)};
			push @errors, @{$entry->{errors}};
			push @outputs, lint_entry($entry);
			$entry = new_entry($line_num + 1);
			@previous = ();
			next;
		}
		if ($line =~ /^</) {
			add_error($entry, $line_num, "parent in the middle of an entry") if $entry->{entry_id_line};
			push @{$entry->{parents}}, {line => $line, previous => [@previous], line_num => $line_num, type => "parent"};
			@previous = ();
			next;
		}
		if ($line =~ /^([\w-]+):\s*$language_prefix_re:(.*)$/) {
			my $key = "$1:$2";
			add_error($entry, $line_num, "duplicate property language line for $key") if defined $entry->{props}{$key};
			$entry->{props}{$key} = {line => $line, previous => [@previous], line_num => $line_num, type => "property"};
			@previous = ();
			next;
		}
		if ($line =~ /^$language_prefix_re:.+(,.*)*$/) {
			my $lc = $1;
			if (!$entry->{entry_id_line}) {
				$entry->{entry_id_line} = {line => $line, previous => [@previous], lc => $lc, line_num => $line_num, type => "entry_id"};
			}
			else {
				add_error($entry, $line_num, "duplicate language line for $lc")
					if defined $entry->{entries}{$lc} || $entry->{entry_id_line}{lc} eq $lc;
				if (defined $entry->{entries}{$lc}) {
					$entry->{entries}{$lc}{line} .= $line;
					push @{$entry->{entries}{$lc}{previous}}, @previous;
				}
				else {
					$entry->{entries}{$lc} = {line => $line, previous => [@previous], line_num => $line_num, type => "entry_lc"};
				}
			}
			@previous = ();
			next;
		}
		if ($line =~ /^#/) {
			push @previous, $line;
			next;
		}
		add_error($entry, $line_num, "unknown line type: $line");
		push @previous, $line;
	}

	return (\@errors, join("", @outputs), join("", @lines));
}

my $exit_code = 0;
for my $file (@files) {
	my ($errors, $output, $original) = lint_file($file);
	if (@$errors) {
		print STDERR join("\n", @$errors), "\n";
		$exit_code = 1;
		next;
	}
	if ($is_check) {
		if ($output ne $original) {
			print STDERR "$file: lint output differs from original\n";
			$exit_code = 1;
		}
		next;
	}
	my ($tmp_fh, $tmp_path) = tempfile("light_lint_taxonomy_XXXX", TMPDIR => 1, UNLINK => 0);
	binmode $tmp_fh, ":encoding(UTF-8)";
	print $tmp_fh $output;
	close($tmp_fh);
	move($tmp_path, $file) or die "unable to replace $file: $!\n";
}

exit $exit_code;
