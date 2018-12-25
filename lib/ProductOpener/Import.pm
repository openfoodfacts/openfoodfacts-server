# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package ProductOpener::Import;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(

		%fields
		@fields
		%products
	
		&assign_value
		
		&get_list_of_files
		
		@fields_mapping
		&load_csv_file
		
		&print_csv_file
		&print_stats
		
		&clean_fields
		&clean_fields_for_all_products
		
		$lc
		%global_params
		
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Encode;
use JSON::PP;
use Time::Local;
use Data::Dumper;

use Text::CSV;

%fields = ();
@fields = ();
%products = ();

my $mode = "replace";

sub assign_value($$$) {

	my $code = shift;
	my $field = shift;
	my $value = shift;
	
	if (not exists $fields{$field}) {
		$fields{$field} = 1;
		push @fields, $field;
	}	
	
	if (not exists $products{$code}) {
		$products{$code} = {};
	}
	
	if ((defined $products{$code}{$field}) and ($products{$code}{$field} ne "") and ($mode eq "append")
		and ($products{$code}{$field} ne $value)) {
		if (exists $tags_fields{$field}) {
			$products{$code}{$field} .= ", " . $value;
		}
		else {
			$products{$code}{$field} .= "\n" . $value;
		}
	}
	else {
		$products{$code}{$field} = $value;
	}
}

sub apply_global_params_to_all_products() {
	
	$mode = "append";
	
	foreach my $code (sort keys %products) {
		foreach my $field (sort keys %global_params) {
			
			assign($code, $field, $global_params{$field});
		}
	}
}

sub split_allergens($) {
	my $allergens = shift;
	
	# simple allergen (not an enumeration) -> return _$allergens_
	if (($allergens !~ /,/)
		and (not ($allergens =~ / et /i))) {
		return "_" . $allergens . "_";
	}
	else {
		return $allergens;
	}
}


sub clean_fields($) {

	my $code = shift;
	
	foreach my $field (@fields) {
	
		if (defined $products{$code}{$field}) {
		
			$products{$code}{$field} =~ s/(\&nbsp)|(\xA0)/ /g;
			$products{$code}{$field} =~ s/’/'/g;
			
			# Remove extra line feeds
			$products{$code}{$field} =~ s/\r\n/\n/g;
			$products{$code}{$field} =~ s/\n\./\n/g;			
			$products{$code}{$field} =~ s/\n\n(\n+)/\n\n/g;
			$products{$code}{$field} =~ s/^\.$//;
			$products{$code}{$field} =~ s/^(\.|\s)+//;
			$products{$code}{$field} =~ s/\s*$//;
			$products{$code}{$field} =~ s/^\s*//;
			$products{$code}{$field} =~ s/(\s|-|_|;|,)*$//;
		
		
			if ($products{$code}{$field} =~ /^(\s|-|\.|_)$/) {
				$products{$code}{$field} = "";
			}
			
			# tag fields: turn separators to commas
			# Sans conservateur / Sans huile de palme
			if (exists $tags_fields{$field}) {
				$products{$code}{$field} =~ s/\s?(;|\/|\n)\s?/, /g;
			}
			
			if (($field =~ /_fr/) or (($lc eq 'fr') and ($field !~ /_\w\w$/))) {
				$products{$code}{$field} =~ s/^\s*(aucun(e)|autre logo)?\s*$//i;
			}
			
			if ($field =~ /^ingredients_text/) {
			
				# Traces de<b> fruits à coque </b>
			
				$products{$code}{$field} =~ s/(<b><u>|<u><b>)/<b>/g;
				$products{$code}{$field} =~ s/(<\b><\u>|<\u><\b>)/<\b>/g;
				$products{$code}{$field} =~ s/<b>\s+/ <b>/g;
				$products{$code}{$field} =~ s/\s+<\/b>/<\/b> /g;

				# empty tags
				$products{$code}{$field} =~ s/<b>\s+<\/b>/ /g;
				$products{$code}{$field} =~ s/<b><\/b>//g;
				# _fromage_ _de chèvre_
				$products{$code}{$field} =~ s/<\/b>(| )<b>/$1/g;
				
				# extrait de malt d'<b>orge - </b>sel 
				$products{$code}{$field} =~ s/ -( |)<\/b>/<\/b> -$1/g;
				
				$products{$code}{$field} =~ s/<b>(.*?)<\/b>/split_allergens($1)/iesg;
				$products{$code}{$field} =~ s/<b>|<\/b>//g;

				
				if ($field eq "ingredients_text_fr") {
					$products{$code}{$field} =~ s/(Les |l')?(information|ingrédient|indication)(s?) (.*) (personnes )?((allergiques( (ou|et) intolérant(e|)s)?)|(intolérant(e|)s( (ou|et) allergiques))?)(\.)?//i;
					
					# Missing spaces
					# Poire Williams - sucre de canne - sucre - gélifiant : pectines de fruits - acidifiant : acide citrique.Préparée avec 55 g de fruits pour 100 g de produit fini.Teneur totale en sucres 56 g pour 100 g de produit fini.Traces de _fruits à coque_ et de _lait_..
					$products{$code}{$field} =~ s/\.([A-Z][a-z])/\. $1/g;
				}
				
				# persil- poivre blanc -ail
				$products{$code}{$field} =~ s/(\w|\*)- /$1 - /g;
				$products{$code}{$field} =~ s/ -(\w)/ - $1/g;
			
				#_oeuf 8_%
				$products{$code}{$field} =~ s/_([^_,-;]+) (\d*\.?\d+\s?\%?)_/_$1_ $2/g;
				
				# _d'arachide_
				# morceaux _d’amandes_ grillées
				if (($field =~ /_fr/) or (($lc eq 'fr') and ($field !~ /_\w\w$/))) {
					$products{$code}{$field} =~ s/_(d|l)('|’)([^_,-;]+)_/$1'_$2_/ig;
				}
			}			
			
			if ($field =~ /^nutrition_grade_/) {
				$products{$code}{$field} = lc($products{$code}{$field});
			}
			
			$products{$code}{$field} =~ s/\.(\.+)$/\./;
			$products{$code}{$field} =~ s/(\s|-|;|,)*$//;
			$products{$code}{$field} =~ s/^(\s|-|;|,)+//;
			$products{$code}{$field} =~ s/^(\s|-|;|,|_)+$//;
		
		}
	}
	
	# empty or uncomplete quantity, but net_weight etc. present
	if ((not defined $products{$code}{quantity}) or ($products{$code}{quantity} eq "")
		or (($lc eq "fr") and ($products{$code}{quantity} =~ /^\d+ tranche([[:alpha:]]*)$/)) # French : "6 tranches épaisses"
		) {
		
		# See if we have other quantity related values: net_weight_value	net_weight_unit	drained_weight_value	drained_weight_unit	volume_value	volume_unit

		my $extra_quantity;
		
		if ((defined $products{$code}{net_weight_value}) and ($products{$code}{net_weight_value} ne "")) {
			$extra_quantity = $products{$code}{net_weight_value} . " " . $products{$code}{net_weight_unit};
		}
		elsif ((defined $products{$code}{drained_weight_value}) and ($products{$code}{drained_weight_value} ne "")) {
			$extra_quantity = $products{$code}{drained_weight_value} . " " . $products{$code}{drained_weight_unit};
		}
		elsif ((defined $products{$code}{volume_value}) and ($products{$code}{volume_value} ne "")) {
			$extra_quantity = $products{$code}{volume_value} . " " . $products{$code}{volume_unit};
		}
		
		if (defined $extra_quantity) {
			if ((defined $products{$code}{quantity}) and ($products{$code}{quantity} ne "")) {
				$products{$code}{quantity} .= " ($extra_quantity)";
			}
			else {
				$products{$code}{quantity} = $extra_quantity;
			}
		}
	}
}


sub clean_fields_for_all_products() {

	foreach my $code (sort keys %products) {
		clean_fields($code);
	}
}


sub load_csv_file($$$$) {

	my $file = shift;
	my $encoding = shift;
	my $separator = shift;
	my $skip_lines = shift;
	
	# e.g. load_csv_file($file, "UTF-8", "\t", 4);
	
	print STDERR "Loading CSV file $file\n";
	
	my $csv = Text::CSV->new ( { binary => 1 , sep_char => $separator } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();

	open (my $io, "<:encoding($encoding)", $file) or die("Could not open $file: $!");
	
	for (my $i = 0; $i < $skip_lines; $i++) {
		$csv->getline ($io);
	}
	

	my $headers_ref = $csv->getline ($io);
	
	#use Data::Dumper;
	#print STDERR Dumper($headers_ref);
	
	$csv->column_names($headers_ref);

	while (my $product_ref = $csv->getline_hr ($io)) {
	
		my $code = undef;	# code must be first

		foreach my $field_mapping_ref (@fields_mapping) {
		
			my $source_field = $field_mapping_ref->[0];
			my $target_field = $field_mapping_ref->[1];
		
			if (defined $product_ref->{$source_field}) {
				# print STDERR "defined source field $source_field: " . $product_ref->{$source_field} . "\n";
				
				if ($target_field eq 'code') {
					$code = $product_ref->{$source_field};
					print STDERR "reading product code $code\n";
					if (exists $products{$code}) {
						$mode = "replace";
					}
					else {
						$mode = "append";
					}
				}
				
				# ["Energie kJ", "nutriments.energy_kJ"],
				
				if ($target_field =~ /^nutriments.(.*)/) {
					$target_field = $1;
					if ($target_field =~ /^(.*)_([^_]+)$/) {
							$target_field = $1;
							my $unit = $2;
							assign_value($code, $target_field . "_value", $product_ref->{$source_field});
							if ($product_ref->{$source_field} ne "") {
								assign_value($code, $target_field . "_unit", $unit);
							}
							else {
								assign_value($code, $target_field . "_unit", "");
							}
					}
					else {
						assign_value($code, $target_field . "_value", $product_ref->{$source_field});					
					}
				}
				else {
					assign_value($code, $target_field, $product_ref->{$source_field});									
				}

			}
			else {
				print STDERR "undefined source field $source_field\n";	
				die;				
			}
		}
	
	}
}





sub get_list_of_files(@) {	

	# Read the list of files or directories passed as parameters
	
	my @files_and_dirs = @_;
	my @files = ();

	foreach my $arg (sort @files_and_dirs) {

		print STDERR "arg: $arg\n";
		
		if (-d "$arg") {
			my $dir = $arg;
			print "Opening dir $dir\n";

			if (opendir (DH, "$dir")) {
				foreach my $file (sort { $a cmp $b } readdir(DH)) {

					next if (($file eq '.') or ($file eq '..'));
					
					#if ($file =~ /^(\d+)-(\d+)_(.*)\.jpg/) {
					if ($file =~ /0(\d+)_(.*)\.png/) {
						push @files, $file;
					}
				
				}
			}

			closedir (DH);	
		}
		else {
			push @files, $arg;
		}
		
	}

	return @files;
}



sub print_csv_file() {

	my $csv_out = Text::CSV->new ( { binary => 1 , sep_char => "\t" } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();

	print join("\t", @fields) . "\n";
	
	foreach my $code (sort keys %products) {
	
		my @values = ();
	
		foreach my $field (@fields) {
			if (defined $products{$code}{$field}) {
				push @values, $products{$code}{$field};
			}
			else {
				push @values, "";
			}
		}
		
		$csv_out->print (*STDOUT, \@values) ;
		print "\n";
	
	}

}


sub print_stats() {

	my %existing_values = ();
	my $i = 0;
	
	foreach my $code (sort keys %products) {
		foreach my $field (@fields) {
			if ((defined $products{$code}{$field}) and ($products{$code}{$field} ne "")) {
				defined $existing_values{$field} or $existing_values{$field} = 0;
				$existing_values{$field}++;
			}
		}
		$i++;
	}
	
	print STDERR "products:\t$i\n";
	foreach my $field (@fields) {
		if (defined $existing_values{$field}) {
			print STDERR "$field:\t$existing_values{$field}\n";
		}
	}
}





1;

