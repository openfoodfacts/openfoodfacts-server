use strict;
use warnings;

use Test::More;
use File::Find;
use File::Basename;

# ------------------------------------------------------------
# Lightweight taxonomy validation
#
# This test performs minimal structural checks to prevent
# obvious syntax regressions in taxonomy files.
#
# It intentionally does NOT reimplement the full taxonomy
# parser and is independent from developer tooling.
# ------------------------------------------------------------

sub lint_file {
	my ($file) = @_;

	open my $fh, '<:encoding(UTF-8)', $file
		or return ["Could not open file: $!"];

	my @errors;
	my %seen_props;
	my $line_num = 0;

	# language prefix (lightweight check only)
	my $lang_re = qr/(?:[a-zA-Z]{2,3}(?:[-_][a-zA-Z0-9]{2,8})*|xx)/;

	while (my $line = <$fh>) {
		$line_num++;
		chomp $line;
		$line =~ s/\s+#.*$//;    # strip inline comments only when preceded by whitespace
		$line =~ s/^\s+|\s+$//g;

		next if $line eq '' || $line =~ /^#/;

		# id line
		if ($line =~ /^$lang_re:/) {
			%seen_props = ();
			next;
		}

		# property line
		if ($line =~ /^([^:]+):\s*($lang_re):(.*)$/) {
			my ($prop, $lang, $value) = ($1, lc($2), $3);
			$value =~ s/^\s+|\s+$//g;

			my $key = "$prop:$lang:$value";
			if ($seen_props{$key}++) {
				push @errors, "Duplicate property '$prop:$lang' with value '$value' at line $line_num";
			}
			next;
		}

		# allow known structural lines
		next if $line =~ /^</;
		next if $line =~ /^(synonyms|stopwords):/i;

		# ignore legacy semicolon formats used in some taxonomies
		next if $line =~ /;/;

		push @errors, "Unknown line format at line $line_num: $line";
	}

	close $fh;
	return \@errors;
}

# ------------------------------------------------------------
# Discover taxonomy files
# ------------------------------------------------------------

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

foreach my $file (@files) {
	my $errors = lint_file($file);
	is_deeply($errors, [], "Linting $file")
		or diag(join("\n", @$errors));
}

done_testing();
