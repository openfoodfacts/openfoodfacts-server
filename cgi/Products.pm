# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2015 Association Open Food Facts
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

package Blogs::Products;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_Images);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
		&normalize_code
		&product_path
		&product_exists
		&init_product
		&retrieve_product
		&retrieve_product_rev
		&store_product
		&product_name_brand
		&product_name_brand_quantity
		&product_url
		&normalize_search_terms
		&index_product
		
		&compute_codes
		&compute_product_history_and_completeness
		&compute_languages
					
	
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;
use strict;
use utf8;

use Blogs::Store qw/:all/;
use Blogs::Config qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Lang qw/:all/;
use Blogs::Food qw/:all/;
use Blogs::Tags qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use MongoDB;

use Algorithm::CheckDigits;
my $ean_check = CheckDigits('ean');


sub normalize_code($) {

	my $code = shift;
	if (defined $code) {
		$code =~ s/\D//g; # Keep only digits, remove spaces, dashes and everything else
		# Add a leading 0 to valid UPC-12 codes
		# invalid 12 digit codes may be EAN-13s with a missing number
		if ((length($code) eq 12) and ($ean_check->is_valid('0' . $code))) {
			$code = '0' . $code;
		}
	}
	return $code;
}


sub product_path($) {

	my $code = shift;
	$code !~ /^\d+$/ and return "invalid";
	
	if (length($code) > 100) {
		print STDERR "invalid code, too long code: $code\n";
		return "invalid";
	}
	
	my $path = $code;
	if ($code =~ /^(...)(...)(...)(.*)$/) {
		$path = "$1/$2/$3/$4";
	}
	return $path;
}


sub product_exists($) {

	my $code = shift;
	
	my $path = product_path($code);
	if (-e "$data_root/products/$path") {
	
		my $product_ref = retrieve("$data_root/products/$path/product.sto");
		if ((not defined $product_ref) or ($product_ref->{deleted})) {
			return 0;
		}
		else {
			return $product_ref;
		}
	}
	else {
		return 0;
	}
}

sub init_product($) {

	my $code = shift;
	
	my $creator = $User_id;
	
	if ((not defined $User_id) or ($User_id eq '')) {
		$creator = "openfoodfacts-contributors";
	}
	
	my $product_ref = {
		id=>$code . '',	# treat code as string
		_id=>$code . '',
		code=>$code . '',	# treat code as string
		created_t=>time(),
		creator=>$creator,
		rev=>0,
	};
	if (defined $lc) {
		$product_ref->{lc} = $lc;
	}
	use Geo::IP;
	my $gi = Geo::IP->new(GEOIP_MEMORY_CACHE);
	# look up IP address '24.24.24.24'
	# returns undef if country is unallocated, or not defined in our database
	my $country = $gi->country_code_by_addr(remote_addr());
	if (defined $country) {
		if ($country !~ /a1|a2|o1/i) {
			$product_ref->{countries} = "en:" . $country;
			my $field = 'countries';
			if (defined $taxonomy_fields{$field}) {
				$product_ref->{$field . "_hierarchy" } = [ gen_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field}) ];
				$product_ref->{$field . "_tags" } = [];
				foreach my $tag (@{$product_ref->{$field . "_hierarchy" }}) {
					push @{$product_ref->{$field . "_tags" }}, get_taxonomyid($tag);
				}
			}			
		}
	}	
	return $product_ref;
}

sub retrieve_product($) {

	my $code = shift;
	my $path = product_path($code);
	my $product_ref = retrieve("$data_root/products/$path/product.sto");
	
	if ((defined $product_ref) and ($product_ref->{deleted})) {
		return undef;
	}
	
	return $product_ref;
}

sub retrieve_product_rev($$) {

	my $code = shift;
	my $rev = shift;
	
	if ($rev !~ /^\d+$/) {
		return undef;
	}
	
	my $path = product_path($code);
	my $product_ref = retrieve("$data_root/products/$path/$rev.sto");
	
	if ((defined $product_ref) and ($product_ref->{deleted})) {
		return undef;
	}
	
	return $product_ref;
}


sub store_product($$) {

	my $product_ref = shift;
	my $comment = shift;
	
	my $code = $product_ref->{code};
	my $path = product_path($code);
	my $rev = $product_ref->{rev};
	
	# Changing the code?
	if (defined $product_ref->{old_code}) {
	
		my $old_code = $product_ref->{old_code};
		my $old_path =  product_path($old_code);
		
		print STDERR "Products::store_product - move from $old_code to $code\n";
		
		# Move directory
		
		my $prefix_path = $path;
		$prefix_path =~ s/\/[^\/]+$//;	# remove the last subdir: we'll move it
		print STDERR "Products::store_product - path: $path - prefix_path: $prefix_path\n";
		# Create the directories for the product
		foreach my $current_dir  ($data_root . "/products", $www_root . "/images/products") {
			(-e "$current_dir") or mkdir($current_dir, 0755);
			foreach my $component (split("/", $prefix_path)) {
				$current_dir .= "/$component";
				(-e "$current_dir") or mkdir($current_dir, 0755);
			}
		}
		
		if ((! -e "$data_root/products/$path")
			and (! -e "$www_root/images/products/$path")) {
			use File::Copy;
			print STDERR "Products::store_product - move from $data_root/products/$old_path to $data_root/products/$path (new)\n";
			move("$data_root/products/$old_path", "$data_root/products/$path") or print STDERR "error moving data from $data_root/products/$old_path to $data_root/products/$path : $!\n";
			move("$www_root/images/products/$old_path", "$www_root/images/products/$path") or print STDERR "error moving html from $www_root/images/products/$old_path to $www_root/images/products/$path : $!\n";
			
			delete $product_ref->{old_code};
			
			$products_collection->remove({"_id" => $product_ref->{_id}});
			$product_ref->{_id} = $product_ref->{code};

		}
		else {
			print STDERR "Products::store_product - cannot move from $data_root/products/$old_path to $data_root/products/$path (already exists)\n";		
		}
		
		$comment .= " - barcode changed from $old_code to $code by $User_id";
	}
	
	
	if ($rev < 1) {
		# Create the directories for the product
		foreach my $current_dir  ($data_root . "/products", $www_root . "/images/products") {
			(-e "$current_dir") or mkdir($current_dir, 0755);
			foreach my $component (split("/", $path)) {
				$current_dir .= "/$component";
				(-e "$current_dir") or mkdir($current_dir, 0755);
			}
		}
	}
	
	# Check lock and previous version
	my $changes_ref = retrieve("$data_root/products/$path/changes.sto");
	if (not defined $changes_ref) {
		$changes_ref = [];
	}
	my $current_rev = scalar @$changes_ref;
	if ($rev != $current_rev) {
		# The product was updated after the form was loaded..
		
		# New product over deleted product?
		if ($rev == 0) {
			$rev = $current_rev;
		}
	}
	
	# Increment the revision
	$rev++;
	
	$product_ref->{rev} = $rev;
	$product_ref->{last_modified_by} = $User_id;
	$product_ref->{last_modified_t} = time() + 0;
	if (not exists $product_ref->{creator}) {
		my $creator = $User_id;	
		if ((not defined $User_id) or ($User_id eq '')) {
			$creator = "openfoodfacts-contributors";
		}	
		$product_ref->{creator} = $creator;
	}
	
	push @$changes_ref, {
		userid=>$User_id,
		ip=>remote_addr(),		
		t=>$product_ref->{last_modified_t},
		comment=>$comment,
		rev=>$rev,
	};	
	

	
	compute_product_history_and_completeness($product_ref, $changes_ref);
	
	compute_codes($product_ref);
	
	compute_languages($product_ref);

	# sort_key
	# add 0 just to make sure we have a number...  last_modified_t at some point contained strings like  "1431125369"
	$product_ref->{sortkey} = 0 + $product_ref->{last_modified_t} - ((1 - $product_ref->{complete}) * 1000000000);
	
	if (not defined $product_ref->{_id}) {
		$product_ref->{_id} = $product_ref->{code} . ''; # treat id as string
	}

	# index for full text search
	index_product($product_ref);

	# make sure that code is saved as a string, otherwise mongodb saves it as number, and leading 0s are removed
	$product_ref->{code} = $product_ref->{code} . '';
	if ($product_ref->{deleted}) {
		$products_collection->remove({"_id" => $product_ref->{_id}});
	}
	else {
		$products_collection->save($product_ref);
	}
	
	store("$data_root/products/$path/$rev.sto", $product_ref);
	# Update link
	my $link = "$data_root/products/$path/product.sto";
	if (-l $link) {
		unlink($link) or print STDERR "Products::store_product could not unlink $link : $! \n";
	}
	#symlink("$data_root/products/$path/$rev.sto", $link) or print STDERR "Products::store_product could not symlink $data_root/products/$path/$rev.sto to $link : $! \n";
	symlink("$rev.sto", $link) or print STDERR "Products::store_product could not symlink $data_root/products/$path/$rev.sto to $link : $! \n";
	
	store("$data_root/products/$path/changes.sto", $changes_ref);
}



sub compute_completeness_and_missing_tags($$$) {

	my $product_ref = shift;
	my $current_ref = shift;
	my $previous_ref = shift;


	# Compute completeness and missing tags
	
	my @states_tags = ();
	
	# Images
	
	my $complete = 1;
	my $notempty = 0;
	
	if (scalar keys %{$current_ref->{uploaded_images}} < 1) {
		push @states_tags, "en:photos-to-be-uploaded";
		$complete = 0;
	}
	else {
		push @states_tags, "en:photos-uploaded";
	
		if ((defined $current_ref->{selected_images}{front}) and (defined $current_ref->{selected_images}{ingredients})
			and ((defined $current_ref->{selected_images}{nutrition}) or ($product_ref->{no_nutrition_data} eq 'on')) ) {
			push @states_tags, "en:photos-validated";
		}
		else {
			push @states_tags, "en:photos-to-be-validated";
			$complete = 0;
		}
		$notempty++;
	}
	
	my @needed_fields = qw(product_name quantity packaging brands categories );
	my $all_fields = 1;
	foreach my $field (@needed_fields) {
		if ((not defined $product_ref->{$field}) or ($product_ref->{$field} eq '')) {
			$all_fields = 0;
			push @states_tags, "en:" . get_fileid($field) . "-to-be-completed";
		}
		else {
			$notempty++;
		}
	}
	
	if ($all_fields == 0) {
		push @states_tags, "en:characteristics-to-be-completed";
		$complete = 0;
	}
	else {
		push @states_tags, "en:characteristics-completed";		
	}
	
	if ((defined $product_ref->{expiration_date}) and ($product_ref->{expiration_date} ne '')) {
		push @states_tags, "en:expiration-date-completed";
		$notempty++;
	}
	else {
		push @states_tags, "en:expiration-date-to-be-completed";
		# $complete = 0;		
	}	
	
	if ((defined $product_ref->{ingredients_text}) and ($product_ref->{ingredients_text} ne '')) {
		push @states_tags, "en:ingredients-completed";
		$notempty++;
	}
	else {
		push @states_tags, "en:ingredients-to-be-completed";
		$complete = 0;		
	}
	
	if ((scalar keys %{$current_ref->{nutriments}} > 0) or ($product_ref->{no_nutrition_data} eq 'on')) {
		push @states_tags, "en:nutrition-facts-completed";
		$notempty++;
	}
	else {
		push @states_tags, "en:nutrition-facts-to-be-completed";
		$complete = 0;		
	}
	
	if ($complete) {
		push @states_tags, "en:complete";	
		
		if ($product_ref->{checked} eq 'on') {
			push @states_tags, "en:checked"
		}
		else {
			push @states_tags, "en:to-be-checked";
		}
	}
	else {
		push @states_tags, "en:to-be-completed";		
	}

	if ($notempty == 0) {
		$product_ref->{empty} = 1;
		push @states_tags, "en:empty";	
	}
	else {
		delete $product_ref->{empty};
	}
	
	$product_ref->{complete} = $complete;
	$current_ref->{complete} = $complete;
	

	if ($complete) {
		if ((not defined $previous_ref->{complete}) or ($previous_ref->{complete} == 0)) {
			$product_ref->{completed_t} = $product_ref->{last_modified_t} + 0;
			$current_ref->{completed_t} = $product_ref->{last_modified_t} + 0;
		}
		else {
			$product_ref->{completed_t} = $previous_ref->{completed_t} + 0;
			$current_ref->{completed_t} = $previous_ref->{completed_t} + 0;
		}
	}
	else {
		delete $product_ref->{completed_t};
		delete $current_ref->{completed_t};
	}
	
	
	$product_ref->{states} = join(', ', reverse @states_tags);
	$product_ref->{"states_hierarchy" } = [reverse @states_tags];
	$product_ref->{"states_tags" } = [reverse @states_tags];

	#my $field = "states";
	#
	#$product_ref->{$field . "_hierarchy" } = [ gen_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field}) ];
	#$product_ref->{$field . "_tags" } = [];
	#foreach my $tag (@{$product_ref->{$field . "_hierarchy" }}) {
	#		push @{$product_ref->{$field . "_tags" }}, get_taxonomyid($tag);
	#}	
	
	# old name
	delete $product_ref->{status};
	delete $product_ref->{status_tags};
}


sub compute_product_history_and_completeness($$) {


	my $current_product_ref = shift;
	my $changes_ref = shift;
	my $code = $current_product_ref->{code};
	my $path = product_path($code);
	
	return if not defined $changes_ref;
	
	#push @$changes_ref, {
	#	userid=>$User_id,
	#	ip=>remote_addr(),		
	#	t=>$product_ref->{last_modified_t},
	#	comment=>$comment,
	#	rev=>$rev,
	#};	
	
	
	# Populate the entry_dates_tags field
	
	$current_product_ref->{entry_dates_tags} = [];
	my $created_t = $current_product_ref->{created_t};
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($created_t);
	push @{$current_product_ref->{entry_dates_tags}}, sprintf("%04d-%02d-%02d", $year + 1900, $mon + 1, $mday);
	push @{$current_product_ref->{entry_dates_tags}}, sprintf("%04d-%02d", $year + 1900, $mon + 1);
	push @{$current_product_ref->{entry_dates_tags}}, sprintf("%04d", $year + 1900);
	
	# Open Food Hunt 2015 - from Feb 21st (earliest) to March 1st (latest)
	if (($created_t > (1424476800 - 12 * 3600)) and ($created_t < (1424476800 - 12 * 3600 + 10 * 86400))) {
		push @{$current_product_ref->{entry_dates_tags}}, "open-food-hunt-2015";
	}

	my $last_modified_t = $current_product_ref->{last_modified_t} + 0;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($last_modified_t);
	push @{$current_product_ref->{last_edit_dates_tags}}, sprintf("%04d-%02d-%02d", $year + 1900, $mon + 1, $mday);
	push @{$current_product_ref->{last_edit_dates_tags}}, sprintf("%04d-%02d", $year + 1900, $mon + 1);
	push @{$current_product_ref->{last_edit_dates_tags}}, sprintf("%04d", $year + 1900);

	# Read all previous versions to see which fields have been added or edited
	
	my @fields = qw(lang product_name generic_name quantity packaging brands categories origins manufacturing_places labels emb_codes expiration_date purchase_places stores countries ingredients_text traces no_nutrition_data serving_size nutrition_data_per );
	
	my %previous = (uploaded_images => {}, selected_images => {}, fields => {}, nutriments => {});
	my %last = %previous;
	my %current;
	
	my @photographers = ();
	my @informers = ();
	my @correctors = ();
	my @checkers = ();
	my %photographers = ();
	my %informers = ();
	my %correctors = ();	
	my %checkers = ();
	
	my $revs = 0;
	
	my %changed_by = ();
	
	foreach my $change_ref (@$changes_ref) {
		$revs++;
		my $rev = $change_ref->{rev};
		if (not defined $rev) {
			$rev = $revs;	# was not set before June 2012
		}
		my $product_ref = retrieve("$data_root/products/$path/$rev.sto");
		
		# if not found, we may be be updating the product, with the latest rev not set yet
		if (not defined $product_ref) {
			$product_ref = $current_product_ref;
		}
		
		if (defined $product_ref) {

			%current = (uploaded_images => {}, selected_images => {}, fields => {}, nutriments => {});
			
			# Uploaded images
			
			# $product_ref->{images}{$imgid} ($imgid is a number)
			
			# Validated images
			
			# $product_ref->{images}{$id} ($id = front / ingredients / nutrition)
			
			if (defined $product_ref->{images}) {
				foreach my $imgid (keys %{$product_ref->{images}}) {
					if ($imgid =~ /^\d/) {
						$current{uploaded_images}{$imgid} = 1;
					}
					else {
						$current{selected_images}{$imgid} = $product_ref->{images}{$imgid}{imgid} . ' ' . $product_ref->{images}{$imgid}{rev} . ' ' . $product_ref->{images}{$imgid}{geometry} ;
					}
				}
			}
			
			# Regular text fields
			
			foreach my $field (@fields) {
				$current{fields}{$field} = $product_ref->{$field};
			}
			
			# Nutriments
			
			if (defined $product_ref->{nutriments}) {
				foreach my $nid (keys %{$product_ref->{nutriments}}) {
					if ((defined $product_ref->{nutriments}{$nid}) and ($product_ref->{nutriments}{$nid} ne '')) {
						$current{nutriments}{$nid} = $product_ref->{nutriments}{$nid};
					}
				}
			}
		
			$current{checked} = $product_ref->{checked};
		}
		
		# Differences and attribution to users
		
		my %diffs = ();
		
		my $userid = $change_ref->{userid};
		
		if ((not defined $userid) or ($userid eq '')) {
			$userid = "openfoodfacts-contributors";
		}
		
		$changed_by{$userid} = 1;			
		
		if (($current{checked} eq 'on') and ($previous{checked} ne 'on')) {
			if ((defined $userid) and ($userid ne '')) {
				if (not defined $checkers{$userid}) {
					$checkers{$userid} = 1;
					push @checkers, $userid;
				}
			}
		}
		
		foreach my $group ('uploaded_images', 'selected_images', 'fields', 'nutriments') {
		
			my @ids;
			
			if ($group eq 'fields') {
				@ids = @fields;
			}
			elsif ($group eq 'nutriments') {
				@ids = @{$nutriments_lists{europe}};
			}
			else {
				sub uniq { my %seen; grep !$seen{$_}++, @_ };
				@ids = uniq ( keys %{$current{$group}}, keys %{$previous{$group}}) ;
			}
			
			foreach my $id (@ids) {
			
				my $diff = undef;
				
				if (($previous{$group}{$id} eq '') and ($current{$group}{$id} ne '')) {
					$diff = 'add';
				}
				elsif (($previous{$group}{$id} ne '') and ($current{$group}{$id} eq '')) {
					$diff = 'delete';
				}
				elsif ($previous{$group}{$id} ne $current{$group}{$id}) {
					$diff = 'change';
				}
				
				if (defined $diff) {
					defined $diffs{$group} or $diffs{$group} = {};
					defined $diffs{$group}{$diff} or $diffs{$group}{$diff} = [];
					push @{$diffs{$group}{$diff}}, $id;
				
				
					# Attribution
					
					
					if (($diff eq 'add') and ($group eq 'uploaded_images')) {
						# images uploader and uploaded_t where not set before 2015/08/04, set them using the change history
						# ! only update the values if the image still exists in the current version of the product (wasn't moved or deleted)
						if (exists $current_product_ref->{images}{$id}) {
							if (not defined $current_product_ref->{images}{$id}{uploaded_t}) {
								$current_product_ref->{images}{$id}{uploaded_t} = $product_ref->{last_modified_t};
							}
							if (not defined $current_product_ref->{images}{$id}{uploader}) {
								$current_product_ref->{images}{$id}{uploader} = $userid;
							}
						
						
							# when moving images, attribute the image to the user that uploaded the image
							
							$userid = $current_product_ref->{images}{$id}{uploader};
							if ($userid eq 'unknown') {	# old unknown user
								$current_product_ref->{images}{$id}{uploader} = "openfoodfacts-contributors";
								$userid = "openfoodfacts-contributors";
							}
							$change_ref->{userid} = $userid;
							
						}
						
					}
					
					if ((defined $userid) and ($userid ne '')) {
					
						if (($diff eq 'add') and ($group eq 'uploaded_images')) {
														
							if (not defined $photographers{$userid}) {
								$photographers{$userid} = 1;
								push @photographers, $userid;
							}
						}
						elsif ($diff eq 'add') {
							if (not defined $informers{$userid}) {
								$informers{$userid} = 1;
								push @informers, $userid;
							}
						}					
						elsif ($diff eq 'change') {
							if (not defined $correctors{$userid}) {
								$correctors{$userid} = 1;
								push @correctors, $userid;
							}
						}
					}
					
					$change_ref->{diffs} = {%diffs};			
				}
			}
		}
		

		compute_completeness_and_missing_tags($product_ref, \%current, \%previous);
		
		%last = %previous;
		%previous = %current;
	}
	
	$current_product_ref->{editors_tags} = [keys %changed_by];
	
	$current_product_ref->{photographers_tags} = [@photographers];
	$current_product_ref->{informers_tags} = [@informers];
	$current_product_ref->{correctors_tags} = [@correctors];
	$current_product_ref->{checkers_tags} = [@checkers];
	
	compute_completeness_and_missing_tags($current_product_ref, \%current, \%last);

}


sub normalize_search_terms($) {

	my $term = shift;
	
	# plural?
	$term =~ s/s$//;
	return $term;
}



sub product_name_brand($) {
	my $ref = shift;
	my $full_name = '';
	if ((defined $ref->{"product_name_$lc"}) and ($ref->{"product_name_$lc"} ne '')) {
		$full_name = $ref->{"product_name_$lc"};
	}
	elsif ((defined $ref->{product_name}) and ($ref->{product_name} ne '')) {
		$full_name = $ref->{product_name};
	}
	
	if (defined $ref->{brands}) {
		my $brand = $ref->{brands};
		$brand =~ s/,.*//;	# take the first brand
		my $brandid = '-' . get_fileid($brand) . '-';
		my $full_name_id = '-' . get_fileid($full_name) . '-';
		if (($brandid ne '') and ($full_name_id !~ /$brandid/i)) {
			$full_name .= " - " . $brand;
		}
	}	
	
	$full_name =~ s/^ - //;
	return $full_name;
}

# product full name is a combination of product name, first brand and quantity

sub product_name_brand_quantity($) {
	my $ref = shift;
	my $full_name = product_name_brand($ref);
	my $full_name_id = '-' . get_fileid($full_name) . '-';
	
	if (defined $ref->{quantity}) {
		my $quantity = $ref->{quantity};
		my $quantityid = '-' . get_fileid($quantity) . '-';	
		if (($quantity ne '') and ($full_name_id !~ /$quantityid/i)) {
			$full_name .= " - " . $quantity;
		}
	}		
	
	$full_name =~ s/^ - //;
	return $full_name;
}





sub product_url($) {

	my $code_or_ref = shift;
	my $code;
	my $ref;
	
	my $product_lc = $lc;
	
	if (ref($code_or_ref) eq 'HASH') {
		$ref = $code_or_ref;
		$code = $ref->{code};
		#if (defined $ref->{lc}) {
		#	$product_lc = $ref->{lc};
		#}
	}
	else {
		$code = $code_or_ref;
	}
	
	my $path = $tag_type_singular{products}{$product_lc};
	if (not defined $path) {
		$path = $tag_type_singular{products}{en};
	}
	
	my $titleid = '';
	if (defined $ref) {
		my $full_name = product_name_brand($ref);
		$titleid = get_urlid($full_name);
		if ($titleid ne '') {
			$titleid = '/' . $titleid;
		}
	}
	
	return "/$path/$code" . $titleid;
}


sub index_product($)
{
	my $product_ref = shift;
	
	my @string_fields = qw(product_name generic_name);
	my @tag_fields = qw(brands categories origins labels);
		
	my %keywords;
	
	foreach my $field (@string_fields, @tag_fields) {
		foreach my $tag (split(/,|'|\s/, $product_ref->{$field} )) {
			if (($field eq 'categories') or ($field eq 'labels') or ($field eq 'origins')) {
				$tag =~ s/^\w\w://;
			}
			if (length(get_fileid($tag)) >= 2) {
				$keywords{normalize_search_terms(get_fileid($tag))} = 1;
			}
		}
	}
	
	$product_ref->{_keywords} = [keys %keywords];	
}


sub compute_codes($) {


	my $product_ref = shift;
	my $code = $product_ref->{code};

	my @codes = ();
	
	push @codes, "code-" . length($code);
	
	my $ean = undef;
	
	if (length($code) == 12) {
		$ean = '0' . $code;
		if (product_exists('0' . $code)) {
			push @codes, "conflict-with-ean-13";
		}
		elsif (-e ("$data_root/products/" . product_path("0" . $code)) ) {
			push @codes, "conflict-with-deleted-ean-13";		
		}
	}
	
	if ((length($code) == 13) and ($code =~ /^0/)) {
		$ean = $code;
		my $upc = $code;
		$upc =~ s/^.//;
		if (product_exists( $upc)) {
			push @codes, "conflict-with-upc-12";
		}
	}
	
	if ((defined $ean) and ($ean !~ /^0?2/)) {
		if (not $ean_check->is_valid($ean)) {
			push @codes, "invalid-ean";
		}
	}
	
	while ($code =~ /^\d/) {
		push @codes, $code;
		$code =~ s/\d(x*)$/x$1/;
	}
	
	$product_ref->{codes_tags} = \@codes;
}




# set tags with info on languages shown on the package, using the languages taxonomy
# [en:french] -> language names
# [n] -> number of languages
# en:multi -> indicates n > 1

sub compute_languages($) {

	my $product_ref = shift;

	
	my %languages = ();
	
	# check all the fields of the product
	
	foreach my $field (keys %$product_ref) {
	
		print STDERR "compute_languages - field: $field - "
			. ($field =~ /_([a-z]{2})$/)
			. " - " . $language_fields{$`}
			. " - " . $product_ref->{$field} . "\n";
	
		if (($field =~ /_([a-z]{2})$/) and (defined $language_fields{$`}) and ($product_ref->{$field} ne '')) {
			my $language = $1;
			if (defined $language_codes{$language}) {
				$language = $language_codes{$language};
			}
			$languages{$language}++;
		}
	}
	
	if (defined $product_ref->{images}) {
		foreach my $id (keys %{ $product_ref->{images}}) {
	
			if ($id =~ /_([a-z]{2})$/)  {
				my $language = $1;
				if (defined $language_codes{$language}) {
					$language = $language_codes{$language};
				}
				$languages{$language}++;
			}
		}
	}

	my @languages = keys %languages;
	my $n = scalar(@languages);
	push @languages, "en:$n";
	if ($n > 1) {
		push @languages, "en:multiple-languages";
	}
	
	$product_ref->{languages} = \%languages;
	$product_ref->{languages_tags} = \@languages;
}


1;

