package Blogs::Products;

######################################################################
#
#	Package	Products
#
#	Author:	Stephane Gigandet
#	Date:	22/12/11
#
######################################################################

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_Images);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					&product_path
					&product_exists
					&init_product
					&retrieve_product
					&retrieve_product_rev
					&store_product
					&product_url
					&normalize_search_terms
					&index_product
					
					&compute_product_history_and_completeness
					
	
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

sub product_path($) {

	my $code = shift;
	$code !~ /^\d+$/ and return "invalid";
	
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
	my $product_ref = {
		id=>$code . '',	# treat code as string
		_id=>$code . '',
		code=>$code . '',	# treat code as string
		created_t=>time(),
		creator=>$User_id,
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
		# Create the directories for the product
		foreach my $current_dir  ($data_root . "/products", $data_root . "/html/images/products") {
			(-e "$current_dir") or mkdir($current_dir, 0755);
			foreach my $component (split("/", $prefix_path)) {
				$current_dir .= "/$component";
				(-e "$current_dir") or mkdir($current_dir, 0755);
			}
		}
		
		if (! -e "$data_root/products/$path") {
			use File::Copy;
			print STDERR "Products::store_product - move from $data_root/products/$old_path to $data_root/products/$path (new)\n";
			move("$data_root/products/$old_path", "$data_root/products/$path");
			move("$www_root/images/products/$old_path", "$www_root/images/products/$path");
			
			delete $product_ref->{old_code};
			
			$products_collection->remove({"_id" => $product_ref->{_id}});
			$product_ref->{_id} = $product_ref->{code};

		}
		else {
			print STDERR "Products::store_product - cannot move from $data_root/products/$old_path to $data_root/products/$path (already exists)\n";		
		}
	}
	
	
	if ($rev < 1) {
		# Create the directories for the product
		foreach my $current_dir  ($data_root . "/products", $data_root . "/html/images/products") {
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
	$product_ref->{last_modified_t} = time();
	if (not exists $product_ref->{creator}) {
		$product_ref->{creator} = $User_id;
	}
	
	push @$changes_ref, {
		userid=>$User_id,
		ip=>remote_addr(),		
		t=>$product_ref->{last_modified_t},
		comment=>$comment,
		rev=>$rev,
	};	
	
	my %changed_by = ();
	foreach my $change_ref (@$changes_ref) {
		$changed_by{$change_ref->{userid}} = 1;
	}
	$product_ref->{editors} = [keys %changed_by];
	
	compute_product_history_and_completeness($product_ref, $changes_ref);

	# sort_key
	
	$product_ref->{sortkey} = $product_ref->{last_modified_t} - ((1 - $product_ref->{complete}) * 1000000000);
	
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
			$current_ref->{completed_t} = $product_ref->{last_modified_t};
		}
		else {
			$product_ref->{completed_t} = $previous_ref->{completed_t} + 0;
			$current_ref->{completed_t} = $previous_ref->{completed_t};
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

	# Read all previous versions to see which fields have been added or edited
	
	my @fields = qw(lang product_name generic_name quantity packaging brands categories origins manufacturing_places labels emb_codes expiration_date purchase_places stores countries ingredient_text traces no_nutrition_data serving_size nutrition_data_per );
	
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
				@ids = @nutriments;
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
	if ((defined $ref) and (defined $ref->{product_name}) and ($ref->{product_name} ne '')) {
		$titleid = get_fileid($ref->{product_name});
		if (defined $ref->{brands}) {
			my $brandid = $ref->{brands};
			$brandid =~ s/,.*//;	# take the first brand
			$brandid = get_fileid($brandid);
			if ($titleid !~ /$brandid/) {
				if ($titleid ne '') {
					$titleid .= '-' . $brandid;
				}
				else {
					$titleid = $brandid;
				}
			}
		}
		if ($titleid ne '') {
			$titleid = '/' . $titleid;
		}
	}
	
	
	#if ($product_lc eq $lc) {
		return "/$path/$code" . $titleid;
	#}
	#else {
	#	my $test = '';
	#	if ($data_root =~ /-test/) {
	#		$test = "-test";
	#	}
	#	return "http://" . $product_lc . $test . "." . $domain . "/$path/$code" . $titleid;
	#}
}


sub index_product($)
{
	my $product_ref = shift;
	
	my @string_fields = qw(product_name generic_name);
	my @tag_fields = qw(brands categories origins labels);
		
	my %keywords;
	
	foreach my $field (@string_fields, @tag_fields) {
		foreach my $tag (split(/,|'|\s/, $product_ref->{$field} )) {
			if (length(get_fileid($tag)) >= 2) {
				$keywords{normalize_search_terms(get_fileid($tag))} = 1;
			}
		}
	}
	
	$product_ref->{_keywords} = [keys %keywords];	
}

1;

