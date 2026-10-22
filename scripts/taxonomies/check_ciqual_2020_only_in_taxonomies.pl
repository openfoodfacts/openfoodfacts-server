#!/usr/bin/env perl
use Modern::Perl '2017';
use utf8;
use Text::CSV;

binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

use ProductOpener::Config qw/:all/;
use ProductOpener::Tags qw/:all/;

my $ciqual_2020 = 'external-data/ciqual/ciqual/CIQUAL2020_ENG_2020_07_07.csv';
my $ciqual_2025 = 'external-data/ciqual/ciqual/CIQUAL2025_ENG_2025_11_03.csv';

sub read_codes {
	my ($file) = @_;
	my %codes;
	my $csv = Text::CSV->new({sep_char => "\t", binary => 1, auto_diag => 1});
	open my $fh, '<:encoding(utf8)', $file or die "Cannot open $file: $!";
	my $header = $csv->getline($fh);
	while (my $row = $csv->getline($fh)) {
		my $code = $row->[6];
		next unless defined $code && $code =~ /^\d+$/;
		$codes{$code} = 1;
	}
	close $fh;
	return \%codes;
}

sub read_ciqual_names {
	my ($file) = @_;
	my %names;
	my $csv = Text::CSV->new({sep_char => "\t", binary => 1, auto_diag => 1});
	open my $fh, '<:encoding(utf8)', $file or die "Cannot open $file: $!";
	my $header = $csv->getline($fh);
	while (my $row = $csv->getline($fh)) {
		my $code = $row->[6];
		my $name = $row->[7];
		next unless defined $code && $code =~ /^\d+$/;
		$names{$code} = $name;
	}
	close $fh;
	return \%names;
}

my $codes_2020 = read_codes($ciqual_2020);
my $codes_2025 = read_codes($ciqual_2025);
my $names_2020_en = read_ciqual_names($ciqual_2020);
my $names_2020_fr = read_ciqual_names('external-data/ciqual/ciqual/CIQUAL2020_FR_2020_07_07.csv');

my %only_in_2020;
foreach my $code (keys %$codes_2020) {
	$only_in_2020{$code} = 1 unless exists $codes_2025->{$code};
}

my $only_2020_count = scalar keys %only_in_2020;
print "Codes only in 2020: $only_2020_count\n\n";

my %results;

foreach my $tagtype ('ingredients', 'categories') {
	foreach my $tagid (sort keys %{$translations_to{$tagtype}}) {
		next if ((exists $just_synonyms{$tagtype}) and (exists $just_synonyms{$tagtype}{$tagid}));

		foreach my $prop ('ciqual_food_code:en', 'ciqual_proxy_food_code:en') {
			my $value = get_property($tagtype, $tagid, $prop);
			next unless defined $value;
			next unless $value =~ /^\d+$/;
			next unless exists $only_in_2020{$value};
			push @{$results{$value}},
				{
				tagtype => $tagtype,
				tagid => $tagid,
				prop => $prop,
				};
		}
	}
}

my %output_rows;

foreach my $code (sort {$a <=> $b} keys %results) {
	my $name_en = $names_2020_en->{$code} // 'unknown';
	my $name_fr = $names_2020_fr->{$code} // 'unknown';

	my %category_props;
	my %ingredient_props;

	foreach my $entry (@{$results{$code}}) {
		if ($entry->{tagtype} eq 'categories') {
			$category_props{$entry->{prop}} = 1;
		}
		else {
			$ingredient_props{$entry->{prop}} = 1;
		}
	}

	my $cat_prop = join(';', sort map {my $p = $_; $p =~ s/:en$//; $p} keys %category_props);
	my $ing_prop = join(';', sort map {my $p = $_; $p =~ s/:en$//; $p} keys %ingredient_props);

	$output_rows{$code} = {
		code => $code,
		name_en => $name_en,
		name_fr => $name_fr,
		categories => $cat_prop,
		ingredients => $ing_prop,
	};
}

my $matched = scalar keys %output_rows;
my $unmatched = $only_2020_count - $matched;

print "=== 2020-only Ciqual codes referenced in taxonomies ===\n";
print "Matched in taxonomies: $matched\n";
print "Not matched: $unmatched\n\n";

foreach my $code (sort {$a <=> $b} keys %output_rows) {
	my $row = $output_rows{$code};
	print "--- Ciqual code $code ---\n";
	print "EN: $row->{name_en}\n";
	print "FR: $row->{name_fr}\n";
	printf "Categories: %s\n", $row->{categories};
	printf "Ingredients: %s\n", $row->{ingredients};
	print "\n";
}

if ($matched > 0) {
	my $csv_file = 'external-data/ciqual/ciqual/old_ciqual_2020_codes_used_in_taxonomies.csv';
	open my $fh, '>:encoding(utf8)', $csv_file or die "Cannot open $csv_file for writing: $!";
	print $fh "ciqual_code\tname_en\tname_fr\tprop_in_categories\tprop_in_ingredients\n";
	foreach my $code (sort {$a <=> $b} keys %output_rows) {
		my $row = $output_rows{$code};
		print $fh join("\t", $row->{code}, $row->{name_en}, $row->{name_fr}, $row->{categories}, $row->{ingredients})
			. "\n";
	}
	close $fh;
	print "Wrote CSV to $csv_file\n";
}

