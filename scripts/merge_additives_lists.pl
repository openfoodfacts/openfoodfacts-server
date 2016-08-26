#!/usr/bin/perl -w

use strict;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;

my %additives = ();

	open(IN, "<:encoding(UTF-8)", "$data_root/ingredients/additives.txt");
	while (<IN>) {
		chomp;
		next if /^\#/;
		
		$_ =~ s/’/'/g;
		
		my ($canon_name, $other_names, $misc, $desc, $level, $warning) = split("\t");
		my $id = get_fileid($canon_name);
		
		$additives{$canon_name} = {langs => {fr => $other_names}};
		
	}
	close IN;
	
my %langs = ();

open (IN, "<:encoding(UTF-8)", "eu_additives_teolemon.txt");
while (<IN>) {
		chomp;
		next if /^\#/;
		
		$_ =~ s/’/'/g;
		
		if ($_ =~ /^(\w\w): (.*?), (.*)$/) {
			my $lang = $1;
			my $canon_name = $2;
			my $other_names = $3;
			
			$canon_name =~ s/^E /E/;
			
			$other_names =~ s/fcf/FCF/g;
			
			if ($other_names =~ /\(/) {
				# print " ( --> " . $other_names . "\n";
			}
			
			defined $additives{$canon_name} or $additives{$canon_name} = { langs => {}};
			
			if (not defined $additives{$canon_name}{langs}{$lang}) {
				$additives{$canon_name}{langs}{$lang} = $other_names;
			}
			else {
				foreach my $other_name (split(/,/, $other_names)) {
					$other_name =~ s/^\s+//;
					$other_name =~ s/\s+$//;
					next if $other_name =~ /\\|\+/;
					if ($additives{$canon_name}{langs}{$lang} !~ /$other_name/i) {
						$additives{$canon_name}{langs}{$lang} .= ', ' . $other_name;
						print "other_name: $other_name\n";
					}
				}
			}
			
			$langs{$lang} ++;
		}		
}
close IN;

foreach my $e (keys %additives) {

	my $number = $e;
	$number =~ s/x/9/ig; # 14XX
	$number =~ s/\D//g;
	$number += 0;
	$additives{$e}{number} = $number;

	if (not defined $additives{$e}{langs}{en}) {
		$additives{$e}{langs}{en} = "$e food additive";
	}
	
}

my @langs = sort(keys %langs);

open (OUT, ">:encoding(UTF-8)", "merged_additives.txt");


foreach my $e ( sort { ($additives{$a}{number} <=> $additives{$b}{number}) || ($a cmp $b) } keys %additives ) {

	print OUT "\n";
	
	print OUT "en:$e, " . $additives{$e}{langs}{en} . "\n";
	
	foreach my $lang (@langs) {
		next if $lang eq 'en';
		if (not defined $additives{$e}{langs}{$lang}) {
			print OUT "$lang:$e, " . $additives{$e}{langs}{en} . "\n";
		}
		else {
			print OUT "$lang:$e, " . $additives{$e}{langs}{$lang} . "\n";
		}
	}
	print OUT "e_number:en:" . $additives{$e}{number} . "\n";
}

close (OUT);




