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
use JSON;
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


sub clean_fields($) {

	my $code = shift;
	
	foreach my $field (@fields) {
	
		if (defined $products{$code}{$field}) {
			
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
			
				$products{$code}{$field} =~ s/(<b><u>|<u><b>)/<b>/g;
				$products{$code}{$field} =~ s/(<\b><\u>|<\u><\b>)/<\b>/g;
				$products{$code}{$field} =~ s/<b> / <b>/g;
				$products{$code}{$field} =~ s/ <\/b>/<\/b> /g;
				$products{$code}{$field} =~ s/<b>|<\/b>/_/g;
			
				if ($field eq "ingredients_text_fr") {
					$products{$code}{$field} =~ s/Les informations en _gras_ sont destinées aux personnes intolérantes ou allergiques(\.)?//;
					$products{$code}{$field} =~ s/Les informations en _gras_ sont destinées aux personnes allergiques ou intolérantes(\.)?//;
					
					# Missing spaces
					# Poire Williams - sucre de canne - sucre - gélifiant : pectines de fruits - acidifiant : acide citrique.Préparée avec 55 g de fruits pour 100 g de produit fini.Teneur totale en sucres 56 g pour 100 g de produit fini.Traces de _fruits à coque_ et de _lait_..
					$products{$code}{$field} =~ s/\.([A-Z][a-z])/\. $1/g;
				}
			
			}
			$products{$code}{$field} =~ s/\.(\.+)$/\./;
			$products{$code}{$field} =~ s/(\s|-|_|;|,)*$//;
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
						assign_value($code, $target_field, $product_ref->{$source_field});					
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


1;

