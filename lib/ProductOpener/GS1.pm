# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

# This package is used to convert CSV or XML file sent by producers to
# an Open Food Facts CSV file that can be loaded with import_csv_file.pl / Import.pm

=head1 NAME

ProductOpener::GS1 - convert data from GS1 Global Data Synchronization Network (GDSN) to the Open Food Facts format.

=head1 SYNOPSIS

=head1 DESCRIPTION

..

=cut

package ProductOpener::GS1;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

use Log::Any qw($log);


BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&init_csv_fields
		&read_gs1_json_file
		&write_off_csv_file

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Config qw/:all/;

use JSON::PP;
use boolean;

=head1 FUNCTIONS

=head2 convert_gs1_json_to_off_csv_fields

Thus function converts the data for one product in the GS1 format converted to JSON.
GS1 format is in XML, it needs to be transformed to JSON with xml2json first.
In some cases, the conversion to JSON has already be done by a third party (e.g. the CodeOnline database from GS1 France).

=head3 Arguments

=head4 json text

=head3 Return value

=head4 Reference to a hash of fields

The function returns a reference to a hash.

Each key is the name of the OFF csv field, and it is associated with the corresponding value for the product.

=cut


my %maps = (

	# gs1:T4078
	"allergens" => {

		"AC" => "Crustacés",
		"AE" => "Oeuf",
		"AF" => "Poisson",
		"AM" => "Lait",
		"AN" => "Fruits à coque",
		"AP" => "Cacahuètes",
		"AS" => "Sésame",
		"AU" => "Sulfites",
		"AW" => "Gluten",
		"AY" => "Soja",
		"BC" => "Céleri",
		"BM" => "Moutarde",
		"GB" => "Orge",
		"NL" => "Lupin",
		"SA" => "Amandes",
		"SB" => "Graines",
		"SH" => "Noisette",
		"SW" => "Noix",
		"UM" => "Mollusques",
		"UW" => "Blé",
	},
);


my %gs1_to_off = (

	# source_field => target_field : assign the value of the source field to the target field
	gtin => "code",

	# source_field => source_hash : go down one level
	informationProviderOfTradeItem => {
		# source_field => target_field1,target_field2 : assign value of the source field to multiple target fields
		partyName => "sources_fields:org-gs1:partyName, org_name",
	},
	
	# http://apps.gs1.org/GDD/Pages/clDetails.aspx?semanticURN=urn:gs1:gdd:cl:ContactTypeCode&release=4
	# source_field => array of hashes: go down one level, expect an array
	tradeItemContactInformation => [
		{
			# match => hash of key value conditions: assign values to field only if the conditions match
			match => {
				contactTypeCode => "CXC",
			},
			contactAddress => "customer_service_fr",
		},
	],
	
	tradeItemInformation => {
		productionVariantDescription => {
			'$t' => "sources_fields:org-gs1:productionVariantDescription, producer_version_id",
		},
		
		extension => {
			"allergen_information:allergenInformationModule" => {
				allergenRelatedInformation => {
					allergen => [
						{
							match => {
								levelOfContainmentCode => "CONTAINS",
							},
							# source_field => +target_field' : add to field, separate with commas if field is not empty
							# source_field => target_field%map_id : map the target value using the specified map_id
							# (do not assign a value if there is no corresponding entry in the map)
							allergenTypeCode => '+allergens%allergens',
						},
						{
							match => {
								levelOfContainmentCode => "MAY_CONTAIN",
							},
							# source_field => +target_field' : add to field, separate with commas if field is not empty
							# source_field => target_field%map_id : map the target value using the specified map_id
							# (do not assign a value if there is no corresponding entry in the map)
							allergenTypeCode => '+traces%allergens',
						},						
					],
				},
			},
		},
	},
);


my %seen_csv_fields = ();
my @csv_fields = ();

=head2 init_csv_fields ()

%seen_fields and @fields are used to output the fields in the order of the GS1 to OFF mapping configuration

=cut

sub init_csv_fields() {

	%seen_csv_fields = ();
	@csv_fields = ();	
}


=head2 gs1_to_off ($gs1_to_off_ref, $json_ref, $results_ref)

Recursive function to go through all first level keys of the $gs1_to_off_ref mapping.
All values that can be assigned at that level are assigned, and if we need to go into a nested level,
the function calls itself again.

=head3 Arguments

=head4 $gs1_to_off_ref - Mapping configuration from GS1 to off for the current level

=head4 $json_ref - JSON structure for the current level

=head4 $results_ref - Hash of key / value pairs to store the complete output of the mapping

The same hash reference is passed to recursive calls to the gs1_to_off function.

=cut


sub gs1_to_off;

sub gs1_to_off ($$$) {
	
	my $gs1_to_off_ref = shift;
	my $json_ref = shift;
	my $results_ref = shift;
	
	$log->debug("gs1_to_off", { json_ref_keys => [sort keys %$json_ref] }) if $log->is_debug();

	foreach my $source_field (sort keys %$gs1_to_off_ref) {
		
		$log->debug("gs1_to_off - source fields", { source_field => $source_field }) if $log->is_debug();
		
		if (defined $json_ref->{$source_field}) {
			
			$log->debug("gs1_to_off - existing source fields",
				{ source_field => $source_field, ref => ref($gs1_to_off_ref->{$source_field}) }) if $log->is_debug();
		
			# Is the value a scalar, it is a target field (or multiple target fields)			
			if (ref($gs1_to_off_ref->{$source_field}) eq "") {
				
				$log->debug("gs1_to_off - source field directly maps to target field",
						{ source_field => $source_field, target_field => $gs1_to_off_ref->{$source_field} }) if $log->is_debug();
				
				# We may have multiple target fields, separated by commas
				foreach my $target_field (split(/\s*,\s*/, $gs1_to_off_ref->{$source_field})) {
								
					my $source_value = $json_ref->{$source_field};
					
					# allergenTypeCode => '+traces%allergens',
					# % sign means we will use a map to transform the source value
					if ($target_field =~ /\%/) {
						$target_field = $`;
						my $map = $';
						
					}
					
					$log->debug("gs1_to_off - assign value to target field",
						{ source_field => $source_field, source_value => $source_value, target_field => $target_field }) if $log->is_debug();
					
					if ((defined $source_value) and ($source_value ne "")) {
					
						# allergenTypeCode => '+traces%allergens',
						# + sign means we will create a comma separated list if we have multiple values
						if ($target_field =~ /^\+/) {
							$target_field = $';
							
							if (defined $results_ref->{$target_field}) {
								$results_ref->{$target_field} .= ', ' . $source_value;
							}
							else {
								$results_ref->{$target_field} = $source_value;
							}
						}
						else {
							$results_ref->{$target_field} = $source_value;
						}
						
						if (not defined $seen_csv_fields{$target_field}) {
							push @csv_fields, $target_field;
							$seen_csv_fields{$target_field} = 1;
						}
					}
				}
			}
			
			elsif (ref($gs1_to_off_ref->{$source_field}) eq "ARRAY") {
				
	# http://apps.gs1.org/GDD/Pages/clDetails.aspx?semanticURN=urn:gs1:gdd:cl:ContactTypeCode&release=4
	# source_field => array of hashes: go down one level, expect an array
	#
	# tradeItemContactInformation => [
	#	{
	#		# match => hash of key value conditions: assign values to field only if the conditions match
	#		match => {
	#			contactTypeCode => "CXC",
	#		},
	#		contactAddress => "customer_service_fr",
	#	},
	#],				
	
				$log->debug("gs1_to_off - array field", { source_field => $source_field }) if $log->is_debug();
	
				# Loop through the array entries of the GS1 to OFF mapping
				
				foreach my $gs1_to_off_array_entry_ref (@{$gs1_to_off_ref->{$source_field}}) {
					
					# Loop through the array entries of the JSON file
							
					foreach my $json_array_entry_ref (@{$json_ref->{$source_field}}) {
						
						my $match = 1;
						
						if (defined $gs1_to_off_array_entry_ref->{match}) {
							foreach my $match_field (keys %{$gs1_to_off_array_entry_ref->{match}}) {
								
								if ((not defined $json_array_entry_ref->{$match_field})
									or ($json_array_entry_ref->{$match_field} ne $gs1_to_off_array_entry_ref->{match}{$match_field})) {
										
									$match = 0;
									
									$log->debug("gs1_to_off - array field - condition does not match",
										{ source_field => $source_field, match_field => $match_field,
											match_value => $gs1_to_off_array_entry_ref->{match}{$match_field},
											actual_value => $json_array_entry_ref->{$match_field} }) if $log->is_debug();
									
									last;
								}
								
							}
						}
						
						if ($match) {
							gs1_to_off($gs1_to_off_array_entry_ref, $json_array_entry_ref, $results_ref);
						}
					}
				}
			}			
			
			elsif (ref($gs1_to_off_ref->{$source_field}) eq "HASH") {
				
				# Go down one level
				gs1_to_off($gs1_to_off_ref->{$source_field}, $json_ref->{$source_field}, $results_ref);
			}
		}
	}
}



=head2 convert_gs1_json_to_off_csv_fields ($json)

Thus function converts the data for one product in the GS1 format converted to JSON.
GS1 format is in XML, it needs to be transformed to JSON with xml2json first.
In some cases, the conversion to JSON has already be done by a third party (e.g. the CodeOnline database from GS1 France).

=head3 Arguments

=head4 json text

=head3 Return value

=head4 Reference to a hash of fields

The function returns a reference to a hash.

Each key is the name of the OFF csv field, and it is associated with the corresponding value for the product.

=cut

sub convert_gs1_json_to_off_csv($) {

	my $json = shift;
	
	my $json_ref = decode_json($json);
	
	# The JSON can contain only the product information "tradeItem" level
	# or the tradeItem can be encapsulated in a message
	
	# catalogue_item_notification:catalogueItemNotificationMessage
	# - transaction
	# -- documentCommand
	# --- catalogue_item_notification:catalogueItemNotification
	# ---- catalogueItem
	# ----- tradeItem
	
	foreach my $field (qw(
		catalogue_item_notification:catalogueItemNotificationMessage
		transaction
		documentCommand
		catalogue_item_notification:catalogueItemNotification
		catalogueItem
		tradeItem)) {
		if (defined $json_ref->{$field}) {
			$json_ref = $json_ref->{$field};
			$log->debug("convert_gs1_json_to_off_csv - remove encapsulating field", { field => $field }) if $log->is_debug();
		}
	}
	
	if (not defined $json_ref->{gtin}) {
		
		$log->debug("convert_gs1_json_to_off_csv - no gtin - skipping", { json_ref => $json_ref }) if $log->is_debug();
		return {};
	}
	
	if ((not defined $json_ref->{isTradeItemAConsumerUnit}) or ($json_ref->{isTradeItemAConsumerUnit} ne "true")) {
		$log->debug("convert_gs1_json_to_off_csv - isTradeItemAConsumerUnit not true - skipping", 
			{ isTradeItemAConsumerUnit => $json_ref->{isTradeItemAConsumerUnit} }) if $log->is_debug();
		return {};
	}
	
	my $results_ref = {};
	
	gs1_to_off(\%gs1_to_off, $json_ref, $results_ref);
	
	return $results_ref;
}


=head2 read_gs1_json_file ($json_file, $products_ref)

Read a GS1 file on json format, convert it to the OFF format, return the
result, and store the result in the $products_ref array (if not undef)

=head3 Arguments

=head4 input json file path and name $json_file

=head4 reference to output products array $products_ref

=cut

sub read_gs1_json_file($$) {
	
	my $json_file = shift;
	my $products_ref = shift;
	
	$log->debug("read_gs1_json_file", { json_file => $json_file }) if $log->is_debug();
	
	open (my $in, "<", $json_file) or die("Cannot open json file $json_file : $!\n");
	my $json = join (q{}, (<$in>));
	close($in);
		
	my $results_ref = convert_gs1_json_to_off_csv($json);
	
	if ((defined $products_ref) and (defined $results_ref->{code})) {
		push @$products_ref, $results_ref;
	}
	
	return $results_ref;
}


=head2 write_off_csv_file ($csv_file, $products_ref)

Write all product data from the $products_ref array to a CSV file in OFF format.

=head3 Arguments

=head4 output CSV file path and name

=head4 reference to output products array $products_ref

=cut

sub write_off_csv_file($$) {
	
	my $csv_file = shift;
	my $products_ref = shift;
	
	open(my $filehandle, ">" . $csv_file) or die("Cannot write csv file $csv_file : $!\n");
	
	my $separator = "\t";
	
	my $csv = Text::CSV->new ( { binary => 1 , sep_char => $separator } )  # should set binary attribute.
		or die "Cannot use CSV: ".Text::CSV->error_diag ();

	# Print the header line with fields names
	$csv->print ($filehandle, \@csv_fields);
	print $filehandle "\n";
	
	foreach my $product_ref (@$products_ref) {
		
		my @csv_fields_values = ();
		foreach my $field (@csv_fields) {
			push @csv_fields_values, $product_ref->{$field};
		}
		
		$csv->print ($filehandle, \@csv_fields_values);
		print $filehandle "\n";
	}
	
	close $filehandle;
}

1;

