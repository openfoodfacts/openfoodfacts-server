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

package ProductOpener::Products;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
		&normalize_code
		&product_path
		&product_exists
		&init_product
		&retrieve_product
		&retrieve_product_or_deleted_product
		&retrieve_product_rev
		&store_product
		&product_name_brand
		&product_name_brand_quantity
		&product_url
		&normalize_search_terms
		&index_product
		&log_change
		
		&compute_codes
		&compute_product_history_and_completeness
		&compute_languages
		&compute_changes_diff_text
		
		&add_back_field_values_removed_by_user
					
		&process_product_edit_rules
		
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::URL qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use MongoDB;
use Encode;
use Log::Any qw($log);

use Storable qw(dclone);

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


# FIXME: bug #677
sub product_path($) {

	my $code = shift;
	$code !~ /^\d+$/ and return "invalid";
	
	if (length($code) > 100) {
		$log->info("invalid code, code too long", { code => $code }) if $log->is_info();
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
		$product_ref->{lang} = $lc;
	}
	use Geo::IP;
	my $gi = Geo::IP->new(GEOIP_MEMORY_CACHE);
	# look up IP address '24.24.24.24'
	# returns undef if country is unallocated, or not defined in our database
	my $country = $gi->country_code_by_addr(remote_addr());
	
	# ugly fix: products added by yuka should have country france, regardless of the server ip
	if ($creator eq 'kiliweb') {
		$country = "france";
	}
	
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
			# if lc is not defined or is set to en, set lc to main language of country
			if (($lc eq 'en') and (defined $country_languages{lc($country)}) and (defined $country_languages{lc($country)}[0]) )  {
				$product_ref->{lc} = $country_languages{lc($country)}[0];
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
		return;
	}
	
	return $product_ref;
}

sub retrieve_product_or_deleted_product($$) {

        my $code = shift;
	my $deleted_ok = shift;
        my $path = product_path($code);
        my $product_ref = retrieve("$data_root/products/$path/product.sto");

        if ((defined $product_ref) and ($product_ref->{deleted})
		and (not $deleted_ok)) {
                return;
        }

        return $product_ref;
}


sub retrieve_product_rev($$) {

	my $code = shift;
	my $rev = shift;
	
	if ($rev !~ /^\d+$/) {
		return;
	}
	
	my $path = product_path($code);
	my $product_ref = retrieve("$data_root/products/$path/$rev.sto");
	
	if ((defined $product_ref) and ($product_ref->{deleted})) {
		return;
	}
	
	return $product_ref;
}


sub store_product($$) {

	my $product_ref = shift;
	my $comment = shift;
	
	my $code = $product_ref->{code};
	my $path = product_path($code);
	my $rev = $product_ref->{rev};
	
	# In case we need to move a product from OFF to OBF etc.
	# then we first move the existing files (product and images)
	# and then store the product with a comment.
	
	my $new_data_root = $data_root;
	my $new_www_root = $www_root;
	my $new_products_collection = $products_collection;
		
	
	# Changing the code?
	# 26/01/2017 - disallow code changes until we fix #677
	if ($admin and (defined $product_ref->{old_code})) {
	
		my $old_code = $product_ref->{old_code};
		my $old_path =  product_path($old_code);
		

		if (defined $product_ref->{new_server}) {
			my $new_server = $product_ref->{new_server};
			$new_data_root = $options{other_servers}{$new_server}{data_root};
			$new_www_root = $options{other_servers}{$new_server}{www_root};
			$new_products_collection = $options{other_servers}{$new_server}{products_collection};
			$product_ref->{server} = $product_ref->{new_server};
			delete $product_ref->{new_server};
		}
		
		$log->info("moving product", { old_code => $old_code, code => $code, new_dat_root => $new_data_root }) if $log->is_info();
		
		# Move directory
		
		my $prefix_path = $path;
		$prefix_path =~ s/\/[^\/]+$//;	# remove the last subdir: we'll move it
		if ($path eq $prefix_path) {
			# short barcodes with no prefix
			$prefix_path = '';
		}
		
		$log->debug("creating product directories", { path => $path, prefix_path => $prefix_path }) if $log->is_debug();
		# Create the directories for the product
		foreach my $current_dir  ($new_data_root . "/products", $new_www_root . "/images/products") {
			(-e "$current_dir") or mkdir($current_dir, 0755);
			foreach my $component (split("/", $prefix_path)) {
				$current_dir .= "/$component";
				(-e "$current_dir") or mkdir($current_dir, 0755);
			}
		}
		
		if ((! -e "$new_data_root/products/$path")
			and (! -e "$new_www_root/images/products/$path")) {
			use File::Copy;
			$log->debug("moving product data", { source => "$data_root/products/$old_path", destination => "$data_root/products/$path" }) if $log->is_debug();
			move("$data_root/products/$old_path", "$new_data_root/products/$path") or $log->error("could not move product data", { source => "$data_root/products/$old_path", destination => "$data_root/products/$path", error => $! });
			$log->debug("moving product images", { source => "$www_root/images/products/$old_path", destination => "$new_www_root/images/products/$path" }) if $log->is_debug();
			move("$www_root/images/products/$old_path", "$new_www_root/images/products/$path") or $log->error("could not move product images", { source => "$www_root/images/products/$old_path", destination => "$new_www_root/images/products/$path", error => $! });
			$log->debug("images and data moved");

			delete $product_ref->{old_code};
			
			$products_collection->remove({"_id" => $product_ref->{_id}});
			$product_ref->{_id} = $product_ref->{code};

		}
		else {
			(-e "$new_data_root/products/$path") and $log->error("cannot move product data, because the destination already exists", { source => "$data_root/products/$old_path", destination => "$data_root/products/$path" });
			(-e "$new_www_root/products/$path") and $log->error("cannot move product images data, because the destination already exists", { source => "$www_root/images/products/$old_path", destination => "$new_www_root/images/products/$path" });
		}
		
		$comment .= " - barcode changed from $old_code to $code by $User_id";
	}
	
	
	if ($rev < 1) {
		# Create the directories for the product
		foreach my $current_dir  ($new_data_root . "/products", $new_www_root . "/images/products") {
			(-e "$current_dir") or mkdir($current_dir, 0755);
			foreach my $component (split("/", $path)) {
				$current_dir .= "/$component";
				(-e "$current_dir") or mkdir($current_dir, 0755);
			}
		}
	}
	
	# Check lock and previous version
	my $changes_ref = retrieve("$new_data_root/products/$path/changes.sto");
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
	

	compute_codes($product_ref);
	
	compute_languages($product_ref);	
	
	compute_product_history_and_completeness($product_ref, $changes_ref);
	
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
	
	# make sure we have numbers, perl can convert numbers to string depending on the last operation done...
	$product_ref->{last_modified_t} += 0;
	$product_ref->{created_t} += 0;
	$product_ref->{complete} += 0;
	$product_ref->{sortkey} += 0;
	

	
	if ($product_ref->{deleted}) {
		$new_products_collection->remove({"_id" => $product_ref->{_id}});
	}
	else {
		$new_products_collection->save($product_ref);
	}
	
	store("$new_data_root/products/$path/$rev.sto", $product_ref);
	# Update link
	my $link = "$new_data_root/products/$path/product.sto";
	if (-l $link) {
		unlink($link) or $log->error("could not unlink old product.sto", { link => $link, error => $! });
	}
	
	symlink("$rev.sto", $link) or $log->error("could not symlink to new revision", { source => "$new_data_root/products/$path/$rev.sto", link => $link, error => $! });
	
	store("$new_data_root/products/$path/changes.sto", $changes_ref);
	
	my $change_ref = @$changes_ref[-1];
	log_change($product_ref, $change_ref);

}



sub compute_completeness_and_missing_tags($$$) {

	my $product_ref = shift;
	my $current_ref = shift;
	my $previous_ref = shift;

	my $lc = $product_ref->{lc};

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
	
		if ((defined $current_ref->{selected_images}{"front_$lc"}) and (defined $current_ref->{selected_images}{"ingredients_$lc"})
			and ((defined $current_ref->{selected_images}{"nutrition_$lc"}) or
				((defined $product_ref->{no_nutrition_data}) and ($product_ref->{no_nutrition_data} eq 'on'))) ) {
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
			push @states_tags, "en:" . get_fileid($field) . "-completed";
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
	
	if ((defined $product_ref->{emb_codes}) and ($product_ref->{emb_codes} ne '')) {
		push @states_tags, "en:packaging-code-completed";
		$notempty++;
	}
	else {
		push @states_tags, "en:packaging-code-to-be-completed";
	}
	
	if ((defined $product_ref->{expiration_date}) and ($product_ref->{expiration_date} ne '')) {
		push @states_tags, "en:expiration-date-completed";
		$notempty++;
	}
	else {
		push @states_tags, "en:expiration-date-to-be-completed";
		# $complete = 0;		
	}	
	
	if ((defined $product_ref->{ingredients_text}) and ($product_ref->{ingredients_text} ne '') and (not ($product_ref->{ingredients_text} =~ /\?/))) {
		push @states_tags, "en:ingredients-completed";
		$notempty++;
	}
	else {
		push @states_tags, "en:ingredients-to-be-completed";
		$complete = 0;		
	}
	
	if (((defined $current_ref->{nutriments}) and (scalar keys %{$current_ref->{nutriments}} > 0))
		or ((defined $product_ref->{no_nutrition_data}) and ($product_ref->{no_nutrition_data} eq 'on')) ) {
		push @states_tags, "en:nutrition-facts-completed";
		$notempty++;
	}
	else {
		push @states_tags, "en:nutrition-facts-to-be-completed";
		$complete = 0;		
	}
	
	
	if ($complete) {
		push @states_tags, "en:complete";	
		
		if ((defined $product_ref->{checked}) and ($product_ref->{checked} eq 'on')) {
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
	my $created_t = $current_product_ref->{created_t} + 0;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($created_t + 0);
	push @{$current_product_ref->{entry_dates_tags}}, sprintf("%04d-%02d-%02d", $year + 1900, $mon + 1, $mday);
	push @{$current_product_ref->{entry_dates_tags}}, sprintf("%04d-%02d", $year + 1900, $mon + 1);
	push @{$current_product_ref->{entry_dates_tags}}, sprintf("%04d", $year + 1900);
	
	# Open Food Hunt 2015 - from Feb 21st (earliest) to March 1st (latest)
	if (($created_t > (1424476800 - 12 * 3600)) and ($created_t < (1424476800 - 12 * 3600 + 10 * 86400))) {
		push @{$current_product_ref->{entry_dates_tags}}, "open-food-hunt-2015";
	}

	my $last_modified_t = $current_product_ref->{last_modified_t} + 0;
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($last_modified_t + 0);
	$current_product_ref->{last_edit_dates_tags} = [];
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
		if ((not defined $product_ref) or ($rev == $current_product_ref->{rev})) {
			$product_ref = $current_product_ref;
			$log->warn("specified product revision was not found, using current product ref", { revision => $rev }) if $log->is_warn();
		}
		
		if (defined $product_ref) {

			# fix last_modified_t using the one from change_ref if it greater than the current_product_ref
			
			if ($change_ref->{t} > $current_product_ref->{last_modified_t}) {
				$current_product_ref->{last_modified_t} = $change_ref->{t};
			}		
		
			%current = (rev => $rev, lc => $product_ref->{lc}, uploaded_images => {}, selected_images => {}, fields => {}, nutriments => {});
			
			# Uploaded images
			
			# $product_ref->{images}{$imgid} ($imgid is a number)
			
			# Validated images
			
			# $product_ref->{images}{$id} ($id = front / ingredients / nutrition)
			
			if (defined $product_ref->{images}) {
				foreach my $imgid (sort keys %{$product_ref->{images}}) {
					if ($imgid =~ /^\d/) {
						$current{uploaded_images}{$imgid} = 1;
					}
					else {
						my $language_imgid = $imgid;
						if ($imgid !~ /_\w\w$/) {
							$language_imgid = $imgid . "_" . $product_ref->{lc};
						}
						$current{selected_images}{$language_imgid} = $product_ref->{images}{$imgid}{imgid} . ' ' . $product_ref->{images}{$imgid}{rev} . ' ' . $product_ref->{images}{$imgid}{geometry} ;
					}
				}
			}
			
			# Regular text fields
			
			foreach my $field (@fields) {
				$current{fields}{$field} = $product_ref->{$field};
				if (defined $current{fields}{$field}) {
					$current{fields}{$field} =~ s/^\s+//;
					$current{fields}{$field} =~ s/\s+$//;
				}
			}
			
			# Language specific fields
			if (defined $product_ref->{languages_codes}) {
				$current{languages_codes} = [keys %{$product_ref->{languages_codes}}];
				foreach my $language_code (@{$current{languages_codes}}) {
					foreach my $field (keys %language_fields) {
						next if $field =~ /_image$/;
						next if not exists $product_ref->{$field . '_' . $language_code};
						$current{fields}{$field . '_' . $language_code} = $product_ref->{$field . '_' . $language_code};
						$current{fields}{$field . '_' . $language_code} =~ s/^\s+//;
						$current{fields}{$field . '_' . $language_code} =~ s/\s+$//;						
					}
				}
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
		
		if (((defined $current{checked}) and ($current{checked} eq 'on')) and ((not defined $previous{checked}) or ($previous{checked} ne 'on'))) {
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
				
				# also check language specific fields for language codes of the current and previous product
				my @languages_codes = ();
				my %languages_codes = ();
				foreach my $current_or_previous_ref (\%current, \%previous) {
					if (defined $current_or_previous_ref->{languages_codes}) {
						foreach my $language_code (@{$current_or_previous_ref->{languages_codes}}) {
							next if $language_code eq $current_or_previous_ref->{lc};
							next if defined $languages_codes{$language_code};
							push @languages_codes, $language_code;
							$languages_codes{$language_code} = 1;
						}
					}
				}
				
				foreach my $language_code (sort @languages_codes) {
					foreach my $field (sort keys %language_fields) {
						next if $field =~ /_image$/;
						push @ids, $field . "_" . $language_code;
					}
				}
			}
			elsif ($group eq 'nutriments') {
				@ids = @{$nutriments_lists{europe}};
			}
			else {
				my $uniq = sub { my %seen; grep !$seen{$_}++, @_ };
				@ids = $uniq->( keys %{$current{$group}}, keys %{$previous{$group}});
			}
			
			foreach my $id (@ids) {
			
				my $diff = undef;
				
				if (((not defined $previous{$group}{$id}) or ($previous{$group}{$id} eq ''))
					and ((defined $current{$group}{$id}) and ($current{$group}{$id} ne '')) ) {
					$diff = 'add';
				}
				elsif (((defined $previous{$group}{$id}) and ($previous{$group}{$id} ne ''))
					and ((not defined $current{$group}{$id}) or ($current{$group}{$id} eq '')) ) {
					$diff = 'delete';
				}
				elsif ((defined $previous{$group}{$id}) and (defined $current{$group}{$id}) and ($previous{$group}{$id} ne $current{$group}{$id}) ) {
					$log->info("difference in products detected", { id => $id, previous_rev => $previous{rev}, previous => $previous{$group}{$id}, current_rev => $current{rev}, current => $current{$group}{$id} }) if $log->is_info();
					$diff = 'change';
					
					# identify products where Yuka removed existing countries to put only France
				}
				
				if (defined $diff) {
					defined $diffs{$group} or $diffs{$group} = {};
					defined $diffs{$group}{$diff} or $diffs{$group}{$diff} = [];
					push @{$diffs{$group}{$diff}}, $id;
				
				
					# Attribution and last_image_t
					
					
					if (($diff eq 'add') and ($group eq 'uploaded_images')) {
						# images uploader and uploaded_t where not set before 2015/08/04, set them using the change history
						# ! only update the values if the image still exists in the current version of the product (wasn't moved or deleted)
						if (exists $current_product_ref->{images}{$id}) {
							if (not defined $current_product_ref->{images}{$id}{uploaded_t}) {
								$current_product_ref->{images}{$id}{uploaded_t} = $product_ref->{last_modified_t} + 0;
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
						
						# set last_image_t
						
						if ((not exists $current_product_ref->{last_image_t}) or ( $product_ref->{last_modified_t} > $current_product_ref->{last_image_t}) ) {
							$current_product_ref->{last_image_t} = $product_ref->{last_modified_t};
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
				}
			}
		}
		
		$change_ref->{diffs} = dclone( \%diffs);
		
		$current_product_ref->{last_editor} = $change_ref->{userid};

		compute_completeness_and_missing_tags($product_ref, \%current, \%previous);
		
		%last = %{ dclone(\%previous)};
		%previous = %{ dclone(\%current)};
	}
	
	# Populate the last_image_date_tags field
	
	if ((exists $current_product_ref->{last_image_t}) and ($current_product_ref->{last_image_t} > 0)) {
		$current_product_ref->{last_image_dates_tags} = [];
		my $last_image_t = $current_product_ref->{last_image_t};
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($last_image_t);
		push @{$current_product_ref->{last_image_dates_tags}}, sprintf("%04d-%02d-%02d", $year + 1900, $mon + 1, $mday);
		push @{$current_product_ref->{last_image_dates_tags}}, sprintf("%04d-%02d", $year + 1900, $mon + 1);
		push @{$current_product_ref->{last_image_dates_tags}}, sprintf("%04d", $year + 1900);	
	}
	else {
		delete $current_product_ref->{last_image_dates_tags};
	}	
	
	$current_product_ref->{editors_tags} = [keys %changed_by];
	
	$current_product_ref->{photographers_tags} = [@photographers];
	$current_product_ref->{informers_tags} = [@informers];
	$current_product_ref->{correctors_tags} = [@correctors];
	$current_product_ref->{checkers_tags} = [@checkers];
	
	compute_completeness_and_missing_tags($current_product_ref, \%current, \%last);

}



# traverse the history to see if a particular user has removed values for tag fields
# add back the removed values

sub add_back_field_values_removed_by_user($$$$) {


	my $current_product_ref = shift;
	my $changes_ref = shift;
	my $field = shift;
	my $userid = shift;
	my $code = $current_product_ref->{code};
	my $path = product_path($code);
	
	return if not defined $changes_ref;


	# Read all previous versions to see which fields have been added or edited
	
	my @fields = qw(lang product_name generic_name quantity packaging brands categories origins manufacturing_places labels emb_codes expiration_date purchase_places stores countries ingredients_text traces no_nutrition_data serving_size nutrition_data_per );
	
	my %previous = ();
	my %last = %previous;
	my %current;
	
	my $previous_tags_ref = {};
	my $current_tags_ref;
	
	my %removed_tags = ();
	
	my $revs = 0;
		
	foreach my $change_ref (@$changes_ref) {
		$revs++;
		my $rev = $change_ref->{rev};
		if (not defined $rev) {
			$rev = $revs;	# was not set before June 2012
		}
		my $product_ref = retrieve("$data_root/products/$path/$rev.sto");
		
		# if not found, we may be be updating the product, with the latest rev not set yet
		if ((not defined $product_ref) or ($rev == $current_product_ref->{rev})) {
			$product_ref = $current_product_ref;
			if (not defined $product_ref) {
				$log->warn("specified product revision was not found, using current product ref", { code => $code, revision => $rev }) if $log->is_warn();
			}
		}
		
		if (defined $product_ref->{$field . "_tags"}) {
			
			$current_tags_ref = { map {$_ => 1} @{$product_ref->{$field . "_tags"}} };
		}
		else {
			$current_tags_ref = {  };
		}
	

		if ((defined $change_ref->{userid}) and ($change_ref->{userid} eq $userid)) {
		
			foreach my $tagid (keys %{$previous_tags_ref}) {
				if (not exists $current_tags_ref->{$tagid}) {
					$log->info("user removed value for a field", { user_id => $userid, tagid => $tagid, field => $field, code => $code }) if $log->is_info();
					$removed_tags{$tagid} = 1;
				}
			}		
		}
		
		$previous_tags_ref = $current_tags_ref;

	}
	
	my $added = 0;
	my $added_countries = "";

	foreach my $tagid (sort keys %removed_tags) {
		if (not exists $current_tags_ref->{$tagid}) {
			$log->info("adding back removed tag", { tagid => $tagid, field => $field, code => $code }) if $log->is_info();
			$current_product_ref->{$field} .= ", $tagid";
			
			if ($current_product_ref->{$field} =~ /^, /) {
				$current_product_ref->{$field} = $';
			}			
			
			$lc = $current_product_ref->{lc};
			compute_field_tags($current_product_ref, $field);	
			
			$added++;
			$added_countries .= " $tagid";
		}
	}
		
	if ($added > 0) {
	
		$added . $added_countries;
	}
	else {
		return 0;
	}
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
			$full_name .= lang("title_separator") . $brand;
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
			$full_name .= lang("title_separator") . $quantity;
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
		if (defined $product_ref->{$field}) {
			foreach my $tag (split(/,|'|\s/, $product_ref->{$field} )) {
				if (($field eq 'categories') or ($field eq 'labels') or ($field eq 'origins')) {
					$tag =~ s/^\w\w://;
				}
				if (length(get_fileid($tag)) >= 2) {
					$keywords{normalize_search_terms(get_fileid($tag))} = 1;
				}
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
	my %languages_codes = ();
	
	# check all the fields of the product
	
	foreach my $field (keys %$product_ref) {
	
	
		if (($field =~ /_([a-z]{2})$/) and (defined $language_fields{$`}) and ($product_ref->{$field} ne '')) {
			my $language_code = $1;
			my $language = undef;
			if (defined $language_codes{$language_code}) {
				$language = $language_codes{$language_code};
			}
			else {
				$language = $language_code;
			}
			$languages{$language}++;
			$languages_codes{$language_code}++;
		}
	}
	
	if (defined $product_ref->{images}) {
		foreach my $id (keys %{ $product_ref->{images}}) {
	
			if ($id =~ /_([a-z]{2})$/)  {
				my $language_code = $1;
				my $language = undef;			
				if (defined $language_codes{$language_code}) {
					$language = $language_codes{$language_code};
				}
				else {
					$language = $language_code;
				}
				$languages{$language}++;
				$languages_codes{$language_code}++;
			}
		}
	}

	my @languages = keys %languages;
	my $n = scalar(@languages);
	
	my @languages_hierarchy = @languages; # without multilingual and count
	
	push @languages, "en:$n";
	if ($n > 1) {
		push @languages, "en:multilingual";
	}
	
	$product_ref->{languages} = \%languages;
	$product_ref->{languages_codes} = \%languages_codes;
	$product_ref->{languages_tags} = \@languages;
	$product_ref->{languages_hierarchy} = \@languages_hierarchy;
}




# @edit_rules = (
# 
# {
# 	name => "App XYZ",
# 	conditions => [
# 		["user_id", "xyz"],
# 	],
# 	actions => {
# 		["ignore_if_existing_ingredients_text_fr"],
# 		["ignore_if_0_nutriments_fruits-vegetables-nuts"],
# 		["warn_if_match_nutriments_fruits-vegetables-nuts", 100],
# 		["ignore_if_regexp_match_packaging", "^(artikel|produit|producto|produkt|produkte)$"],
# 	},
# 	notifications => qw (
# 		stephane@openfoodfacts.org
# 		slack_channel_edit-alert
# 		slack_channel_edit-alert-test
# 	),
# },
# 
# );
# 


sub process_product_edit_rules($) {

	my $product_ref = shift;
	my $code = $product_ref->{code};
	
	local $log->context->{user_id} = $User_id;
	local $log->context->{code} = $code;
	
	# return value to indicate if the edit should proceed
	my $proceed_with_edit = 1;
	
	foreach my $rule_ref (@edit_rules) {
	
		local $log->context->{rule} = $rule_ref->{name};
		$log->debug("checking edit rule") if $log->is_debug();
		
		# Check the conditions
		
		my $conditions = 1;		
		
		if (defined $rule_ref->{conditions}) {
			foreach my $condition_ref (@{$rule_ref->{conditions}}) {
				if ($condition_ref->[0] eq 'user_id') {
					if ($condition_ref->[1] ne $User_id) {
						$conditions = 0;
						$log->debug("condition does not match value", { condition => $condition_ref->[0], expected => $condition_ref->[1], actual => $User_id } ) if $log->is_debug();
						last;
					}
				}
				elsif ($condition_ref->[0] eq 'user_id_not') {
					if ($condition_ref->[1] eq $User_id) {
						$conditions = 0;
						$log->debug("condition does not match value", { condition => $condition_ref->[0], expected => $condition_ref->[1], actual => $User_id } ) if $log->is_debug();
						last;
					}
				}
				elsif ($condition_ref->[0] =~ /in_(.*)_tags/) {
					my $tagtype = $1;
					my $condition = 0;
					if (defined $product_ref->{$tagtype . "_tags"}) {
						foreach my $tagid (@{$product_ref->{$tagtype . "_tags"}}) {
							if ($tagid eq $condition_ref->[1]) {
								$condition = 1;
								last;
							}
						}
					}
					if (not $condition) {
						$conditions = 0;
						$log->debug("condition does not match value", { condition => $condition_ref->[0], expected => $condition_ref->[1] } ) if $log->is_debug();
						last;
					}
				}				
				else {
					$log->debug("unrecognized condition", { condition => $condition_ref->[0] } ) if $log->is_debug();
				}
			}
		}
		
		# If conditions match, process actions and notifications
		if ($conditions) {
		
# 	actions => {
# 		["ignore_if_existing_ingredients_texts_fr"],
# 		["ignore_if_0_nutriments_fruits-vegetables-nuts"],
# 		["warn_if_match_nutriments_fruits-vegetables-nuts", 100],
# 		["ignore_if_regexp_match_packaging", "^(artikel|produit|producto|produkt|produkte)$"],
# 	},
			
			if (defined $rule_ref->{actions}) {
				foreach my $action_ref (@{$rule_ref->{actions}}) {
					my $action = $action_ref->[0];
					my $value = $action_ref->[1];
					not defined $value and $value = '';
					
					local $log->context->{action} = $action;
					local $log->context->{value} = $value;
					$log->debug("evaluating actions") if $log->is_debug();

					my $condition_ok = 1;	
					
					my $action_log = "";					
									
						
					if ($action eq "ignore") {
						$log->debug("ignore action => do not proceed with edits") if $log->is_debug();
						$proceed_with_edit = 0;
					}
					elsif ($action =~ /^(ignore|warn)(_if_(existing|0|greater|lesser|equal|match|regexp_match)_)?(.*)$/) {
						my ($type, $condition, $field) = ($1, $3, $4);
						my $default_field = $field;
						
						my $condition_ok = 1;	
						
						my $action_log = "";
						
						local $log->context->{type} = $type;
						local $log->context->{action} = $field;
						local $log->context->{field} = $field;

						if (defined $condition) {
						
							# if field is not passed, skip rule
							if (not defined param($field)) {
								$log->debug("no value passed -> skip edit rule") if $log->is_debug();
								next;
							}
							
							my $param_field = remove_tags_and_quote(decode utf8=>param($field));
							
							my $current_value = $product_ref->{$field};
							if ($field =~ /^nutriment_(.*)/) {
								my $nid = $1;
								$current_value = $product_ref->{nutriments}{$nid . "_100g"};
							}
							
							# language fields?
							if ($field =~ /_(\w\w)$/) {
								$default_field = $`;
								if (not defined $param_field) {
									$param_field = remove_tags_and_quote(decode utf8=>param($default_field));
								}
							}
							
							local $log->context->{current_value} = $current_value;
							local $log->context->{param_field} = $param_field;

							$log->debug("start field comparison") if $log->is_debug();
							
							# if there is an existing value equal to the passed value, just skip the rule
							if  ((defined $current_value) and ($current_value eq $param_field)) {
								$log->debug("current value equals new value -> skip edit rule") if $log->is_debug();
								next;
							}
						
														
							$condition_ok = 0;
							

							if ($condition eq 'existing') {
								if ((defined $current_value) and ($current_value ne '')) {
									$condition_ok = 1;
								}
							}
							elsif ($condition eq '0') {
								if ((defined param($field)) and ($param_field == 0)) {
									$condition_ok = 1;
								}
							}
							elsif ($condition eq 'equal') {
								if ((defined param($field)) and ($param_field == $value)) {
									$condition_ok = 1;
								}
							}		
							elsif ($condition eq 'lesser') {
								if ((defined param($field)) and ($param_field < $value)) {
									$condition_ok = 1;
								}
							}
							elsif ($condition eq 'greater') {
								if ((defined param($field)) and ($param_field > $value)) {
									$condition_ok = 1;
								}
							}							
							elsif ($condition eq 'match') {
								if ((defined param($field)) and ($param_field eq $value)) {
									$condition_ok = 1;
								}
							}							
							elsif ($condition eq 'regexp_match') {
								if ((defined param($field)) and ($param_field  =~ /$value/i)) {
									$condition_ok = 1;
								}
							}
							else {
							}							
							
							if (not $condition_ok) {
								$log->debug("condition does not match") if $log->is_debug();
							}
							else {
								$log->debug("condition matches") if $log->is_debug();
								$action_log = "product code $code - " . format_subdomain($subdomain) . product_url($product_ref) . " - edit rule $rule_ref->{name} - type: $type - condition: $condition - field: $field current(field): " . $current_value . " - param(field): " . $param_field . "\n";
							}
						}
						else {
							$action_log = "product code $code - " . format_subdomain($subdomain) . product_url($product_ref) . " - edit rule $rule_ref->{name} - type: $type - condition: $condition \n";
						}
						
						if ($condition_ok) {
						
							# Process action
							$log->debug("executing edit rule action") if $log->is_debug();							
							
							# Delete the parameters
							
							if ($type eq 'ignore') {
								Delete($field);
								if ($default_field ne $field) {
									Delete($default_field);
								}
							}
						}	
						
						
						
					}
					else {
						$log->debug("unrecognized action", { action => $action }) if $log->is_debug();
					}
					
					if ($condition_ok) {
					
						$log->debug("executing edit rule action") if $log->is_debug();
					
						if (defined $rule_ref->{notifications}) {
							foreach my $notification (@{$rule_ref->{notifications}}) {
							
								$log->info("sending notification", { notification_recipient => $notification }) if $log->is_info();
							
								if ($notification =~ /\@/) {
									# e-mail
									
									my $user_ref = { name => $notification, email => $notification};
									
									send_email($user_ref, "Edit rule " . $rule_ref->{name} , $action_log );
								}
								elsif ($notification =~ /slack_/) {
									# slack
									
									my $channel = $';
									
									# we need a slack bot with the Web api to post to multiple channel
									# use the simpler incoming webhook api, and post only to edit-alerts for now
									
									$channel = "edit-alerts";
									
									my $emoji = ":lemon:";
									if ($action eq 'warn') {
										$emoji = ":pear:";
									}
																			
									use LWP::UserAgent;
									my $ua = LWP::UserAgent->new;
									my $server_endpoint = "https://hooks.slack.com/services/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";

									my $msg = $action_log;
										
									# set custom HTTP request header fields
									my $req = HTTP::Request->new(POST => $server_endpoint);
									$req->header('content-type' => 'application/json');
									 
									# add POST data to HTTP request body
									my $post_data = '{"channel": "#' . $channel . '", "username": "editrules", "text": "' . $msg . '", "icon_emoji": "' . $emoji . '" }';
									$req->content_type("text/plain; charset='utf8'");
									$req->content(Encode::encode_utf8($post_data));
									 
									my $resp = $ua->request($req);
									if ($resp->is_success) {
										my $message = $resp->decoded_content;
										$log->info("Notification sent to Slack successfully", { response => $message }) if $log->is_info();
									}
									else {
										$log->warn("Notification could not be sent to Slack", { code => $resp->code, response => $resp->message }) if $log->is_warn();
									}										
									
								}
							}
						}
					}					
				}
			}		
		
		}
	}
	
	return $proceed_with_edit;
}

sub log_change {

	my ($product_ref, $change_ref) = @_;
	
	my $change_document = {
		code => $product_ref->{code},
		countries_tags => $product_ref->{countries_tags},
		userid => $change_ref->{userid},
		ip => $change_ref->{ip},
		t => $change_ref->{t},
		comment => $change_ref->{comment},
		rev => $change_ref->{rev},
		diffs => $change_ref->{diffs}
	};
	$recent_changes_collection->insert_one($change_document);

}

sub compute_changes_diff_text {

	my $change_ref = shift;
	
	my $diffs = '';
	if (defined $change_ref->{diffs}) {
		my %diffs = %{$change_ref->{diffs}};
		foreach my $group ('uploaded_images', 'selected_images', 'fields', 'nutriments') {
			if (defined $diffs{$group}) {
				$diffs .= lang("change_$group") . " ";
							
				foreach my $diff ('add','change','delete') {
					if (defined $diffs{$group}{$diff}) {
						$diffs .= "(" . lang("diff_$diff") . ' ' ;
						my @diffs = @{$diffs{$group}{$diff}};
						if ($group eq 'fields') {
							# @diffs = map( lang($_), @diffs);
						}
						elsif ($group eq 'nutriments') {
							# @diffs = map( $Nutriments{$_}{$lc}, @diffs);
							# Attempt to access disallowed key 'nutrition-score' in a restricted hash at /home/off-fr/cgi/product.pl line 1039.
							my @lc_diffs = ();
							foreach my $nid (@diffs) {
								if (exists $Nutriments{$nid}) {
									push @lc_diffs, $Nutriments{$nid}{$lc};
								}
							}
						}
						$diffs .= join(", ", @diffs) ;
						$diffs .= ") ";
					}
				}
				
				$diffs .= "-- ";
			}
		}
		$diffs =~  s/-- $//;
	}

	return $diffs;

}

1;

