# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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

=head1 NAME

ProductOpener::Controller::Product - handling HTTP requests related to products

=cut

package ProductOpener::Controller::Product;
use ProductOpener::PerlStandards;







=head2 search_and_display_products ($request_ref, $query_ref, $sort_by, $limit, $page)

Search products and return an HTML snippet that should be included in the webpage.

=head3 Parameters

=head4 $request_ref

Reference to the internal request object.

=head4 $query_ref

Reference to the MongoDB query object.

=head4 $sort_by

A string indicating how to sort results (created_t, popularity,...), or a sorting subroutine.

=head4 $limit

Limit of the number of products to return.

=head4 $page

Requested page (first page starts at 1).

=cut

sub search_and_display_products ($request_ref, $query_ref, $sort_by, $limit, $page) {

	$request_ref->{page_type} = "products";

	# Flag that indicates whether we cache MongoDB results in Memcached
	# Caching is disabled for crawling bots, as they tend to explore
	# all pages (and make caching inefficient)
	my $cache_results_flag = scalar(not $request_ref->{is_crawl_bot});
	my $template_data_ref = {};

	add_params_to_query($request_ref, $query_ref);

	$log->debug("search_and_display_products",
		{request_ref => $request_ref, query_ref => $query_ref, sort_by => $sort_by})
		if $log->is_debug();

	add_country_and_owner_filters_to_query($request_ref, $query_ref);

	if (defined $limit) {
	}
	elsif (defined $request_ref->{page_size}) {
		$limit = $request_ref->{page_size};
	}
	# If user preferences are turned on, return 100 products per page
	elsif ((not defined $request_ref->{api}) and ($request_ref->{user_preferences})) {
		$limit = 100;
	}
	else {
		$limit = $page_size;
	}

	my $skip = 0;
	if (defined $page) {
		$skip = ($page - 1) * $limit;
	}
	elsif (defined $request_ref->{page}) {
		$page = $request_ref->{page};
		$skip = ($page - 1) * $limit;
	}
	else {
		$page = 1;
	}

	# support for returning structured results in json / xml etc.

	my $sort_ref = Tie::IxHash->new();

	# Use the sort order provided by the query if it is defined (overrides default sort order)
	# e.g. ?sort_by=popularity
	if (defined $request_ref->{sort_by}) {
		$sort_by = $request_ref->{sort_by};
		$log->debug("sort_by was passed through request_ref", {sort_by => $sort_by}) if $log->is_debug();
	}
	# otherwise use the sort order from the last_sort_by cookie
	elsif (defined cookie('last_sort_by')) {
		$sort_by = cookie('last_sort_by');
		$log->debug("sort_by was passed through last_sort_by cookie", {sort_by => $sort_by}) if $log->is_debug();
	}
	elsif (defined $sort_by) {
		$log->debug("sort_by was passed as a function parameter", {sort_by => $sort_by}) if $log->is_debug();
	}

	if (
		(not defined $sort_by)
		or (    ($sort_by ne 'created_t')
			and ($sort_by ne 'last_modified_t')
			and ($sort_by ne 'last_modified_t_complete_first')
			and ($sort_by ne 'scans_n')
			and ($sort_by ne 'unique_scans_n')
			and ($sort_by ne 'product_name')
			and ($sort_by ne 'completeness')
			and ($sort_by ne 'popularity_key')
			and ($sort_by ne 'popularity')
			and ($sort_by ne 'nutriscore_score')
			and ($sort_by ne 'nova_score')
			and ($sort_by ne 'ecoscore_score')
			and ($sort_by ne 'nothing'))
		)
	{

		if ((defined $options{product_type}) and ($options{product_type} eq "food")) {
			$sort_by = 'popularity_key';
		}
		else {
			$sort_by = 'last_modified_t';
		}
	}

	if ((defined $sort_by) and ($sort_by ne "nothing")) {
		my $order = 1;
		my $sort_by_key = $sort_by;

		if ($sort_by eq 'last_modified_t_complete_first') {
			# replace last_modified_t_complete_first (used on front page of a country) by popularity
			$sort_by = 'popularity';
			$sort_by_key = "popularity_key";
			$order = -1;
		}
		elsif ($sort_by eq "popularity") {
			$sort_by_key = "popularity_key";
			$order = -1;
		}
		elsif ($sort_by eq "popularity_key") {
			$order = -1;
		}
		elsif ($sort_by eq "ecoscore_score") {
			$order = -1;
		}
		elsif ($sort_by eq "nutriscore_score") {
			$sort_by_key = "nutriscore_score_opposite";
			$order = -1;
		}
		elsif ($sort_by eq "nova_score") {
			$sort_by_key = "nova_score_opposite";
			$order = -1;
		}
		elsif ($sort_by =~ /^((.*)_t)_complete_first/) {
			$order = -1;
		}
		elsif ($sort_by =~ /_t/) {
			$order = -1;
		}
		elsif ($sort_by =~ /scans_n/) {
			$order = -1;
		}

		$sort_ref->Push($sort_by_key => $order);
	}

	# Sort options

	$template_data_ref->{sort_options} = [];

	# Nutri-Score and Eco-Score are only for food products
	# and currently scan data is only loaded for Open Food Facts
	if ((defined $options{product_type}) and ($options{product_type} eq "food")) {

		push @{$template_data_ref->{sort_options}},
			{
			value => "popularity",
			link => $request_ref->{current_link} . "?sort_by=popularity",
			name => lang("sort_by_popularity")
			};
		push @{$template_data_ref->{sort_options}},
			{
			value => "nutriscore_score",
			link => $request_ref->{current_link} . "?sort_by=nutriscore_score",
			name => lang("sort_by_nutriscore_score")
			};

		# Show Eco-score sort only for some countries, or for moderators
		if ($show_ecoscore) {
			push @{$template_data_ref->{sort_options}},
				{
				value => "ecoscore_score",
				link => $request_ref->{current_link} . "?sort_by=ecoscore_score",
				name => lang("sort_by_ecoscore_score")
				};
		}
	}

	push @{$template_data_ref->{sort_options}},
		{
		value => "created_t",
		link => $request_ref->{current_link} . "?sort_by=created_t",
		name => lang("sort_by_created_t")
		};
	push @{$template_data_ref->{sort_options}},
		{
		value => "last_modified_t",
		link => $request_ref->{current_link} . "?sort_by=last_modified_t",
		name => lang("sort_by_last_modified_t")
		};

	my $count;
	my $page_count = 0;

	my $fields_ref;

	# - for API (json, xml, rss,...), display all fields
	if (   single_param("json")
		or single_param("jsonp")
		or single_param("xml")
		or single_param("jqm")
		or $request_ref->{rss})
	{
		$fields_ref = {};
	}
	# - if we use user preferences, we need a lot of fields to compute product attributes: load them all
	elsif ($request_ref->{user_preferences}) {
		# we restrict the fields that are queried to MongoDB, and use the basic ones and those necessary
		# by Attributes.pm to compute attributes.
		# This list should be updated if new attributes are added.
		$fields_ref = {
			# generic fields
			"owner" => 1,    # needed on pro platform to generate the images urls
			"lc" => 1,
			"code" => 1,
			"product_name" => 1,
			"product_name_$lc" => 1,
			"generic_name" => 1,
			"generic_name_$lc" => 1,
			"abbreviated_product_name" => 1,
			"abbreviated_product_name_$lc" => 1,
			"brands" => 1,
			"images" => 1,
			"quantity" => 1,
			# fields necessary for personal search
			"additives_n" => 1,
			"allergens_tags" => 1,
			"categories_tags" => 1,
			"ecoscore_data" => 1,
			"ecoscore_grade" => 1,
			"ecoscore_score" => 1,
			"forest_footprint_data" => 1,
			"ingredients_analysis_tags" => 1,
			"ingredients_n" => 1,
			"labels_tags" => 1,
			"nova_group" => 1,
			"nutrient_levels" => 1,
			"nutriments" => 1,
			"nutriscore_data" => 1,
			"nutriscore_grade" => 1,
			"nutrition_grades" => 1,
			"traces_tags" => 1,
			"unknown_ingredients_n" => 1
		};
	}
	else {
		#for HTML, limit the fields we retrieve from MongoDB
		$fields_ref = {
			"lc" => 1,
			"code" => 1,
			"product_name" => 1,
			"product_name_$lc" => 1,
			"generic_name" => 1,
			"generic_name_$lc" => 1,
			"abbreviated_product_name" => 1,
			"abbreviated_product_name_$lc" => 1,
			"brands" => 1,
			"images" => 1,
			"quantity" => 1
		};

		# For the producer platform, we also need the owner
		if ((defined $server_options{private_products}) and ($server_options{private_products})) {
			$fields_ref->{owner} = 1;
		}
	}

	# tied hashes can't be encoded directly by JSON::PP, freeze the sort tied hash
	my $mongodb_query_ref = [
		lc => $lc,
		query => $query_ref,
		fields => $fields_ref,
		sort => freeze($sort_ref),
		limit => $limit,
		skip => $skip
	];

	my $key = generate_query_cache_key("search_products", $mongodb_query_ref, $request_ref);

	$log->debug("MongoDB query key - search_products", {key => $key}) if $log->is_debug();

	$request_ref->{structured_response} = get_cache_results($key, $request_ref);

	if (not defined $request_ref->{structured_response}) {

		$request_ref->{structured_response} = {
			page => $page,
			page_size => 0 + $limit,
			skip => $skip,
			products => [],
		};

		my $cursor;
		eval {
			$count = estimate_result_count($request_ref, $query_ref, $cache_results_flag);

			$log->debug("Executing MongoDB query",
				{query => $query_ref, fields => $fields_ref, sort => $sort_ref, limit => $limit, skip => $skip})
				if $log->is_debug();
			$cursor = execute_query(
				sub {
					return get_products_collection(get_products_collection_request_parameters($request_ref))
						->query($query_ref)->fields($fields_ref)->sort($sort_ref)->limit($limit)->skip($skip);
				}
			);
			$log->info("MongoDB query ok", {error => $@}) if $log->is_info();
		};
		if ($@) {
			$log->warn("MongoDB error", {error => $@}) if $log->is_warn();
		}
		else {
			$log->info("MongoDB query ok", {error => $@}) if $log->is_info();

			while (my $product_ref = $cursor->next) {
				push @{$request_ref->{structured_response}{products}}, $product_ref;
				$page_count++;
			}

			$request_ref->{structured_response}{page_count} = $page_count;

			# The page count may be higher than the count from the query service which is updated every night
			# in that case, set $count to $page_count
			# It's also possible that the count query had a timeout and that $count is 0 even though we have results
			if ($page_count > $count) {
				$count = $page_count;
			}

			$request_ref->{structured_response}{count} = $count;

			# Don't set the cache if no_count was set
			if (not single_param('no_count') and $cache_results_flag) {
				set_cache_results($key, $request_ref->{structured_response});
			}
		}
	}

	$count = $request_ref->{structured_response}{count};
	$page_count = $request_ref->{structured_response}{page_count};

	if (defined $request_ref->{description}) {
		$request_ref->{description} =~ s/<nb_products>/$count/g;
	}

	my $html = '';
	my $html_count = '';
	my $error = '';

	my $decf = get_decimal_formatter($lc);

	if (not defined $request_ref->{jqm_loadmore}) {
		if ($count < 0) {
			$error = lang("error_database");
		}
		elsif ($count == 0) {
			$error = lang("no_products");
		}
		elsif ($count == 1) {
			$html_count .= lang("1_product");
		}
		elsif ($count > 1) {
			$html_count .= sprintf(lang("n_products"), $decf->format($count));
		}
		$template_data_ref->{error} = $error;
		$template_data_ref->{html_count} = $html_count;
	}

	$template_data_ref->{jqm} = single_param("jqm");
	$template_data_ref->{country} = $country;
	$template_data_ref->{world_subdomain} = get_world_subdomain();
	$template_data_ref->{current_link} = $request_ref->{current_link};
	$template_data_ref->{sort_by} = $sort_by;

	# Query from search form: display a link back to the search form
	if (defined($request_ref->{current_link}) && $request_ref->{current_link} =~ /action=process/) {
		$template_data_ref->{current_link_query_edit} = $request_ref->{current_link};
		$template_data_ref->{current_link_query_edit} =~ s/action=process/action=display/;
	}

	$template_data_ref->{count} = $count;

	if ($count > 0) {

		# Show a download link only for search queries (and not for the home page of facets)

		if ($request_ref->{search}) {
			$request_ref->{current_link_query_download} = $request_ref->{current_link};
			if ($request_ref->{current_link} =~ /\?/) {
				$request_ref->{current_link_query_download} .= "&download=on";
			}
			else {
				$request_ref->{current_link_query_download} .= "?download=on";
			}
		}

		$template_data_ref->{current_link_query_download} = $request_ref->{current_link_query_download};
		$template_data_ref->{export_limit} = $export_limit;

		if ($log->is_debug()) {
			my $debug_log = "search - count: $count";
			defined $request_ref->{search} and $debug_log .= " - request_ref->{search}: " . $request_ref->{search};
			defined $request_ref->{tagid2} and $debug_log .= " - tagid2 " . $request_ref->{tagid2};
			$log->debug($debug_log);
		}

		if (    (not defined $request_ref->{search})
			and ($count >= 5)
			and (not defined $request_ref->{tagid2})
			and (not defined $request_ref->{product_changes_saved}))
		{
			$template_data_ref->{explore_products} = 'true';
			my $nofollow = '';
			if (defined $request_ref->{tagid}) {
				# Prevent crawlers from going too deep in facets #938:
				# Make the 2nd facet level "nofollow"
				$nofollow = ' rel="nofollow"';
			}

			my @current_drilldown_fields = @ProductOpener::Config::drilldown_fields;
			if ($country eq 'en:world') {
				unshift(@current_drilldown_fields, "countries");
			}

			foreach my $newtagtype (@current_drilldown_fields) {

				# Eco-score: currently only for moderators

				if ($newtagtype eq 'ecoscore') {
					next if not($show_ecoscore);
				}

				push @{$template_data_ref->{current_drilldown_fields}},
					{
					current_link => $request_ref->{current_link},
					tag_type_plural => $tag_type_plural{$newtagtype}{$lc},
					nofollow => $nofollow,
					tagtype => $newtagtype,
					};
			}
		}

		$template_data_ref->{separator_before_colon} = separator_before_colon($lc);
		$template_data_ref->{jqm_loadmore} = $request_ref->{jqm_loadmore};

		for my $product_ref (@{$request_ref->{structured_response}{products}}) {
			my $img_url;

			my $code = $product_ref->{code};
			my $img = display_image_thumb($product_ref, 'front');

			my $product_name = remove_tags_and_quote(product_name_brand_quantity($product_ref));

			# Prevent the quantity "750 g" to be split on two lines
			$product_name =~ s/(.*) (.*?)/$1\&nbsp;$2/;

			my $url = product_url($product_ref);
			$product_ref->{url} = $formatted_subdomain . $url;

			add_images_urls_to_product($product_ref, $lc);

			my $jqm = single_param("jqm");    # Assigning to a scalar to make sure we get a scalar

			push @{$template_data_ref->{structured_response_products}},
				{
				code => $code,
				product_name => $product_name,
				img => $img,
				jqm => $jqm,
				url => $url,
				};

			# remove some debug info
			delete $product_ref->{additives};
			delete $product_ref->{additives_prev};
			delete $product_ref->{additives_next};
		}

		# For API queries, if the request specified a value for the fields parameter, return only the fields listed
		# For non API queries with user preferences, we need to add attributes
		# For non API queries, we need to compute attributes for personal search
		my $fields;
		if ((not defined $request_ref->{api}) and ($request_ref->{user_preferences})) {
			$fields = "code,product_display_name,url,image_front_small_url,attribute_groups";
		}
		else {
			$fields = single_param('fields') || 'all';
		}

		my $customized_products_ref = [];

		for my $product_ref (@{$request_ref->{structured_response}{products}}) {

			my $customized_product_ref = customize_response_for_product($request_ref, $product_ref, $fields);

			push @{$customized_products_ref}, $customized_product_ref;
		}

		$request_ref->{structured_response}{products} = $customized_products_ref;

		# Disable nested ingredients in ingredients field (bug #2883)

		# 2021-02-25: we now store only nested ingredients, flatten them if the API is <= 1

		if ($request_ref->{api_version} <= 1) {

			for my $product_ref (@{$request_ref->{structured_response}{products}}) {
				if (defined $product_ref->{ingredients}) {

					flatten_sub_ingredients($product_ref);

					foreach my $ingredient_ref (@{$product_ref->{ingredients}}) {
						# Delete sub-ingredients, keep only flattened ingredients
						exists $ingredient_ref->{ingredients} and delete $ingredient_ref->{ingredients};
					}
				}
			}
		}

		$template_data_ref->{request} = $request_ref;
		$template_data_ref->{page_count} = $page_count;
		$template_data_ref->{page_limit} = $limit;
		$template_data_ref->{page} = $page;
		$template_data_ref->{current_link} = $request_ref->{current_link};
		$template_data_ref->{pagination} = display_pagination($request_ref, $count, $limit, $page);
	}

	# if cc and/or lc have been overridden, change the relative paths to absolute paths using the new subdomain

	if ($subdomain ne $original_subdomain) {
		$log->debug("subdomain not equal to original_subdomain, converting relative paths to absolute paths",
			{subdomain => $subdomain, original_subdomain => $original_subdomain})
			if $log->is_debug();
		$html =~ s/(href|src)=("\/)/$1="$formatted_subdomain\//g;
	}

	if ($request_ref->{user_preferences}) {

		my $preferences_text
			= sprintf(lang("classify_the_d_products_below_according_to_your_preferences"), $page_count);

		my $products_json = '[]';

		if (defined $request_ref->{structured_response}{products}) {
			$products_json = decode_utf8(encode_json($request_ref->{structured_response}{products}));
		}

		my $contributor_prefs_json = decode_utf8(
			encode_json(
				{
					display_barcode => $User{display_barcode},
					edit_link => $User{edit_link},
				}
			)
		);

		$scripts .= <<JS
<script type="text/javascript">
var page_type = "products";
var preferences_text = "$preferences_text";
var contributor_prefs = $contributor_prefs_json;
var products = $products_json;
</script>
JS
			;

		$scripts .= <<JS
<script src="$static_subdomain/js/product-preferences.js"></script>
<script src="$static_subdomain/js/product-search.js"></script>
JS
			;

		$initjs .= <<JS
display_user_product_preferences("#preferences_selected", "#preferences_selection_form", function () {
	rank_and_display_products("#search_results", products, contributor_prefs);
});
rank_and_display_products("#search_results", products, contributor_prefs);
JS
			;

	}

	process_template('web/common/includes/list_of_products.tt.html', $template_data_ref, \$html)
		|| return "template error: " . $tt->error();
	return $html;
}


sub search_and_export_products ($request_ref, $query_ref, $sort_by) {

	my $format = "csv";
	if ((defined $request_ref->{format}) and ($request_ref->{format} eq "xlsx")) {
		$format = $request_ref->{format};
	}

	add_params_to_query($request_ref, $query_ref);

	add_country_and_owner_filters_to_query($request_ref, $query_ref);

	$log->debug("search_and_export_products - MongoDB query", {format => $format, query => $query_ref})
		if $log->is_debug();

	my $max_count = $export_limit;

	# Allow admins to change the export limit
	if (($admin) and (defined single_param("export_limit"))) {
		$max_count = single_param("export_limit");
	}

	my $args_ref = {
		cc => $cc,    # used to localize Eco-Score fields
		format => $format,
		filehandle => \*STDOUT,
		filename => "openfoodfacts_export." . $format,
		send_http_headers => 1,
		query => $query_ref,
		max_count => $max_count,
		export_computed_fields => 1,
		export_canonicalized_tags_fields => 1,
	};

	# Extra parameters
	foreach my $parameter (qw(fields extra_fields separator)) {
		if (defined $request_ref->{$parameter}) {
			$args_ref->{$parameter} = $request_ref->{$parameter};
		}
	}

	my $count = export_csv($args_ref);

	my $html = '';

	if ((not defined $count) or ($count < 0)) {
		$html .= "<p>" . lang("error_database") . "</p>";
	}
	elsif ($count == 0) {
		$html .= "<p>" . lang("no_products") . "</p>";
	}
	elsif ($count > $max_count) {
		$html .= "<p>" . sprintf(lang("error_too_many_products_to_export"), $count, $export_limit) . "</p>";
	}
	else {
		# export_csv has already output HTTP headers and the export file, we can return
		return;
	}

	# Display an error message

	$html .= search_permalink($request_ref);

	$request_ref->{title} = lang("search_results");
	$request_ref->{content_ref} = \$html;
	display_page($request_ref);
	return;
}


=head2 map_of_products($products_iter, $request_ref, $graph_ref)

Build the HTML to display a map of products

=head3 parameters

=head4 $products_iter - iterator

Must return a reference to a function that on each call return a product, or undef to end iteration


=head4 $request_ref - hashmap ref

=head4 $graph_ref - hashmap ref

Specifications for the graph

=cut

sub map_of_products ($products_iter, $request_ref, $graph_ref) {

	my $html = '';

	# be sure to have packager codes loaded
	init_emb_codes();
	init_packager_codes();
	init_geocode_addresses();

	$graph_ref->{graph_title} = escape_single_quote_and_newlines($graph_ref->{graph_title});

	my $matching_products = 0;
	my $places = 0;
	my $emb_codes = 0;
	my $seen_products = 0;

	my %seen = ();
	my @pointers = ();

	while (my $product_ref = $products_iter->()) {
		my $url = $formatted_subdomain . product_url($product_ref->{code});

		my $manufacturing_places = escape_single_quote_and_newlines($product_ref->{"manufacturing_places"});
		$manufacturing_places =~ s/,( )?/, /g;
		if ($manufacturing_places ne '') {
			$manufacturing_places
				= ucfirst(lang("manufacturing_places_p"))
				. separator_before_colon($lc) . ": "
				. $manufacturing_places . "<br>";
		}

		my $origins = escape_single_quote_and_newlines($product_ref->{origins});
		$origins =~ s/,( )?/, /g;
		if ($origins ne '') {
			$origins = ucfirst(lang("origins_p")) . separator_before_colon($lc) . ": " . $origins . "<br>";
		}

		$origins = $manufacturing_places . $origins;

		my $pointer = {
			product_name => $product_ref->{product_name},
			brands => $product_ref->{brands},
			url => $url,
			origins => $origins,
			img => display_image_thumb($product_ref, 'front')
		};

		# Loop on cities: multiple emb codes can be on one product

		my $field = 'emb_codes';
		if (defined $product_ref->{"emb_codes_tags"}) {

			my %current_seen = ();    # only one product when there are multiple city codes for the same city

			foreach my $emb_code (@{$product_ref->{"emb_codes_tags"}}) {

				my ($lat, $lng) = get_packager_code_coordinates($emb_code);

				if ((defined $lat) and ($lat ne '') and (defined $lng) and ($lng ne '')) {
					my $geo = "$lat,$lng";
					if (not defined $current_seen{$geo}) {

						$current_seen{$geo} = 1;
						my @geo = ($lat + 0.0, $lng + 0.0);
						$pointer->{geo} = \@geo;
						push @pointers, $pointer;
						$emb_codes++;
						if (not defined $seen{$geo}) {
							$seen{$geo} = 1;
							$places++;
						}
					}
				}
			}

			if (scalar keys %current_seen > 0) {
				$seen_products++;
			}
		}

		$matching_products++;
	}

	# no products --> no map
	if ($matching_products <= 0) {
		if ($matching_products == 0) {
			$html .= "<p>" . lang("no_products") . "</p>";
		}
		$log->warn("could not retrieve enough products for a map", {count => $matching_products}) if $log->is_warn();
		return $html;
	}

	$log->info(
		"rendering map for matching products",
		{
			count => $matching_products,
			matching_products => $matching_products,
			products => $seen_products,
			emb_codes => $emb_codes
		}
	) if $log->is_debug();

	# Points to display?
	my $count_string = q{};
	if ($emb_codes > 0) {
		$count_string = sprintf(lang("map_count"), $matching_products, $seen_products);
	}

	if (defined $request_ref->{current_link}) {
		$request_ref->{current_link_query_display} = $request_ref->{current_link};
		$request_ref->{current_link_query_display} =~ s/\?action=process/\?action=display/;
	}

	my $json = JSON::PP->new->utf8(0);
	my $map_template_data_ref = {
		lang => \&lang,
		encode_json => sub ($obj_ref) {
			return $json->encode($obj_ref);
		},
		title => $count_string,
		pointers => \@pointers,
		current_link => $request_ref->{current_link},
	};
	process_template('web/pages/products_map/map_of_products.tt.html', $map_template_data_ref, \$html)
		|| ($html .= 'template error: ' . $tt->error());

	return $html;
}

=head2 search_products_for_map($request_ref, $query_ref)

Build the MongoDB query corresponding to a search to display a map

=head3 parameters

=head4 $request_ref - hashmap

=head4 $query_ref - hashmap

Base query that will be modified to be able to build the map

=head3 returns - MongoDB::Cursor instance

=cut

sub search_products_for_map ($request_ref, $query_ref) {

	add_params_to_query($request_ref, $query_ref);

	add_country_and_owner_filters_to_query($request_ref, $query_ref);

	my $cursor;

	$log->info("retrieving products from MongoDB to display them in a map") if $log->is_info();

	eval {
		$cursor = execute_query(
			sub {
				return get_products_collection(get_products_collection_request_parameters($request_ref))
					->query($query_ref)->fields(
					{
						code => 1,
						lc => 1,
						product_name => 1,
						"product_name_$lc" => 1,
						brands => 1,
						images => 1,
						manufacturing_places => 1,
						origins => 1,
						emb_codes_tags => 1,
					}
					);
			}
		);
	};
	if ($@) {
		$log->warn("MongoDB error", {error => $@}) if $log->is_warn();
	}
	else {
		$log->info("MongoDB query ok", {error => $@}) if $log->is_info();
	}

	$log->info("retrieved products from MongoDB to display them in a map") if $log->is_info();
	$cursor->immortal(1);
	return $cursor;
}

=head2 search_and_map_products ($request_ref, $query_ref, $graph_ref)

Trigger a search and build a map

=head3 parameters

=head4 $request_ref - hashmap ref

=head4 $query_ref - hashmap ref

Base query for this search

=head4 $graph_ref

Specification of the graph

=cut

sub search_and_map_products ($request_ref, $query_ref, $graph_ref) {

	my $cursor = search_products_for_map($request_ref, $query_ref);

	# add search link
	my $html = '';

	$html .= search_permalink($request_ref);

	eval {$html .= map_of_products(cursor_iter($cursor), $request_ref, $graph_ref);} or do {
		$html .= "<p>" . lang("error_database") . "</p>";
	};
	return $html;
}



sub display_product ($request_ref) {

	my $request_lc = $request_ref->{lc};
	my $request_code = $request_ref->{code};
	my $code = normalize_code($request_code);
	local $log->context->{code} = $code;

	if (not is_valid_code($code)) {
		display_error_and_exit(lang_in_other_lc($request_lc, "invalid_barcode"), 403);
	}

	my $product_id = product_id_for_owner($Owner_id, $code);

	my $html = '';
	my $title = undef;
	my $description = "";

	my $template_data_ref = {request_ref => $request_ref,};

	$scripts .= <<SCRIPTS
<script src="$static_subdomain/js/dist/webcomponentsjs/webcomponents-loader.js"></script>
<script src="$static_subdomain/js/dist/display-product.js"></script>
<script src="$static_subdomain/js/dist/product-history.js"></script>
SCRIPTS
		;

	# call equalizer when dropdown content is shown
	$initjs .= <<JS
\$('.f-dropdown').on('opened.fndtn.dropdown', function() {
   \$(document).foundation('equalizer', 'reflow');
});
\$('.f-dropdown').on('closed.fndtn.dropdown', function() {
   \$(document).foundation('equalizer', 'reflow');
});
JS
		;

	# Check that the product exist, is published, is not deleted, and has not moved to a new url

	$log->info("displaying product", {request_code => $request_code, product_id => $product_id}) if $log->is_info();

	$title = $code;

	my $product_ref;

	my $rev = single_param("rev");
	local $log->context->{rev} = $rev;
	if (defined $rev) {
		$log->info("displaying product revision") if $log->is_info();
		$product_ref = retrieve_product_rev($product_id, $rev);
		$header .= '<meta name="robots" content="noindex,follow">';
	}
	else {
		$product_ref = retrieve_product($product_id);
	}

	if (not defined $product_ref) {
		display_error_and_exit(sprintf(lang("no_product_for_barcode"), $code), 404);
	}

	$title = product_name_brand_quantity($product_ref);
	my $titleid = get_string_id_for_lang($lc, product_name_brand($product_ref));

	if (not $title) {
		$title = $code;
	}

	if (defined $rev) {
		$title .= " version $rev";
	}

	$description = sprintf(lang("product_description"), $title);

	$request_ref->{canon_url} = product_url($product_ref);

	if ($lc eq 'en') {
		$request_ref->{canon_url} = get_world_subdomain() . product_url($product_ref);
	}

	# Old UPC-12 in url? Redirect to EAN-13 url
	if ($request_code ne $code) {
		$request_ref->{redirect} = $request_ref->{canon_url};
		$log->info(
			"302 redirecting user because request_code does not match code",
			{redirect => $request_ref->{redirect}, lc => $lc, request_code => $code}
		) if $log->is_info();
		redirect_to_url($request_ref, 302, $request_ref->{redirect});
	}

	# Check that the titleid is the right one

	if (
		(not defined $rev)
		and (  (($titleid ne '') and ((not defined $request_ref->{titleid}) or ($request_ref->{titleid} ne $titleid)))
			or (($titleid eq '') and ((defined $request_ref->{titleid}) and ($request_ref->{titleid} ne ''))))
		)
	{
		$request_ref->{redirect} = $request_ref->{canon_url};
		$log->info(
			"302 redirecting user because titleid is incorrect",
			{
				redirect => $request_ref->{redirect},
				lc => $lc,
				product_lc => $product_ref->{lc},
				titleid => $titleid,
				request_titleid => $request_ref->{titleid}
			}
		) if $log->is_info();
		redirect_to_url($request_ref, 302, $request_ref->{redirect});
	}

	# Note: the product_url function is automatically added to all templates
	# so we need to use a different field name for the displayed product url

	my $product_url = product_url($product_ref);
	$template_data_ref->{this_product_url} = $product_url;

	# Environmental impact and Eco-Score
	# Limit to the countries for which we have computed the Eco-Score
	# for alpha test to moderators, display eco-score for all countries

	# Note: the Eco-Score data needs to be localized before we create the knowledge panels.

	if (($show_ecoscore) and (defined $product_ref->{ecoscore_data})) {

		localize_ecoscore($cc, $product_ref);

		$template_data_ref->{ecoscore_grade} = uc($product_ref->{ecoscore_data}{"grade"});
		$template_data_ref->{ecoscore_grade_lc} = $product_ref->{ecoscore_data}{"grade"};
		$template_data_ref->{ecoscore_score} = $product_ref->{ecoscore_data}{"score"};
		$template_data_ref->{ecoscore_data} = $product_ref->{ecoscore_data};
		$template_data_ref->{ecoscore_calculation_details}
			= display_ecoscore_calculation_details($cc, $product_ref->{ecoscore_data});
	}

	# Activate knowledge panels for all users

	initialize_knowledge_panels_options($knowledge_panels_options_ref, $request_ref);
	create_knowledge_panels($product_ref, $lc, $cc, $knowledge_panels_options_ref);
	$template_data_ref->{environment_card_panel}
		= display_knowledge_panel($product_ref, $product_ref->{"knowledge_panels_" . $lc}, "environment_card");
	$template_data_ref->{health_card_panel}
		= display_knowledge_panel($product_ref, $product_ref->{"knowledge_panels_" . $lc}, "health_card");
	if ($product_ref->{"knowledge_panels_" . $lc}{"contribution_card"}) {
		$template_data_ref->{contribution_card_panel}
			= display_knowledge_panel($product_ref, $product_ref->{"knowledge_panels_" . $lc}, "contribution_card");
	}

	# The front product image is rendered with the same template as the ingredients, nutrition and packaging images
	# that are displayed directly through the knowledge panels
	$template_data_ref->{front_image} = data_to_display_image($product_ref, "front", $lc);

	# On the producers platform, show a link to the public platform

	if ($server_options{producers_platform}) {
		my $public_product_url = $formatted_subdomain . $product_url;
		$public_product_url =~ s/\.pro\./\./;
		$template_data_ref->{public_product_url} = $public_product_url;
	}

	$template_data_ref->{product_changes_saved} = $request_ref->{product_changes_saved};
	$template_data_ref->{structured_response_count} = $request_ref->{structured_response}{count};

	if ($request_ref->{product_changes_saved}) {
		my $query_ref = {};
		$query_ref->{("states_tags")} = "en:to-be-completed";

		my $search_result = search_and_display_products($request_ref, $query_ref, undef, undef, undef);
		$template_data_ref->{search_result} = $search_result;
	}

	$template_data_ref->{title} = $title;
	$template_data_ref->{code} = $code;
	$template_data_ref->{user_moderator} = $User{moderator};

	# my @fields = qw(generic_name quantity packaging br brands br categories br labels origins br manufacturing_places br emb_codes link purchase_places stores countries);
	my @fields = @ProductOpener::Config::display_fields;

	$bodyabout = " about=\"" . product_url($product_ref) . "\" typeof=\"food:foodProduct\"";

	$template_data_ref->{user_id} = $User_id;
	$template_data_ref->{robotoff_url} = $robotoff_url;
	$template_data_ref->{lc} = $lc;

	my $itemtype = 'https://schema.org/Product';
	if (has_tag($product_ref, 'categories', 'en:dietary-supplements')) {
		$itemtype = 'https://schema.org/DietarySupplement';
	}

	$template_data_ref->{itemtype} = $itemtype;

	if ($code =~ /^2000/) {    # internal code
	}
	else {
		$template_data_ref->{upc_code} = 'defined';
		# Also display UPC code if the EAN starts with 0
		my $upc = "";
		if (length($code) == 13) {
			$upc .= "(EAN / EAN-13)";
			if ($code =~ /^0/) {
				$upc .= " " . $' . " (UPC / UPC-A)";
			}
		}
		$template_data_ref->{upc} = $upc;
	}

	# obsolete product

	if ((defined $product_ref->{obsolete}) and ($product_ref->{obsolete})) {
		$template_data_ref->{product_is_obsolete} = $product_ref->{obsolete};
		my $warning = $Lang{obsolete_warning}{$lc};
		if ((defined $product_ref->{obsolete_since_date}) and ($product_ref->{obsolete_since_date} ne '')) {
			$warning
				.= " ("
				. $Lang{obsolete_since_date}{$lc}
				. $Lang{sep}{$lc} . ": "
				. $product_ref->{obsolete_since_date} . ")";
		}
		$template_data_ref->{warning} = $warning;
	}

	# GS1-Prefixes for restricted circulation numbers within a company - warn for possible conflicts
	if ($code =~ /^(?:(?:0{7}[0-9]{5,6})|(?:04[0-9]{10,11})|(?:[02][0-9]{2}[0-9]{5}))$/) {
		$template_data_ref->{gs1_prefixes} = 'defined';
	}

	$template_data_ref->{rev} = $rev;
	if (defined $rev) {
		$template_data_ref->{display_rev_info} = display_rev_info($product_ref, $rev);
	}
	elsif (not has_tag($product_ref, "states", "en:complete")) {
		$template_data_ref->{not_has_tag} = "states-en:complete";
	}

	# photos and data sources

	if (defined $product_ref->{sources}) {

		$template_data_ref->{unique_sources} = [];

		my %unique_sources = ();

		foreach my $source_ref (@{$product_ref->{sources}}) {
			$unique_sources{$source_ref->{id}} = $source_ref;
		}
		foreach my $source_id (sort keys %unique_sources) {
			my $source_ref = $unique_sources{$source_id};

			if (not defined $source_ref->{name}) {
				$source_ref->{name} = $source_id;
			}

			push @{$template_data_ref->{unique_sources}}, $source_ref;
		}
	}

	# If the product has an owner, identify it as the source
	if (    (not $server_options{producers_platform})
		and (defined $product_ref->{owner})
		and ($product_ref->{owner} =~ /^org-/))
	{

		# Organization
		my $orgid = $';
		my $org_ref = retrieve_org($orgid);
		if (defined $org_ref) {
			$template_data_ref->{owner} = $product_ref->{owner};
			$template_data_ref->{owner_org} = $org_ref;
		}

		# Indicate data sources

		if (defined $product_ref->{data_sources_tags}) {
			foreach my $data_source_tagid (@{$product_ref->{data_sources_tags}}) {
				if ($data_source_tagid =~ /^database-/) {
					my $database_id = $';
					my $database_name = deep_get(\%options, "import_sources", $database_id);

					# Data sources like Agena3000, CodeOnline, Equadis
					if (defined $database_name) {
						$template_data_ref->{"data_source_database_provider"} = f_lang(
							"f_data_source_database_provider",
							{
								manufacturer => '<a href="/editor/'
									. $product_ref->{owner} . '">'
									. $org_ref->{name} . '</a>',
								provider => '<a href="/data-source/'
									. $data_source_tagid . '">'
									. $database_name . '</a>',
							}
						);
					}

					# For CodeOnline, display an extra note about the producers platform
					if ($database_id eq "codeonline") {
						$template_data_ref->{"data_source_database_note_about_the_producers_platform"}
							= lang("data_source_database_note_about_the_producers_platform");
						$template_data_ref->{"data_source_database_note_about_the_producers_platform"}
							=~ s/<producers_platform_url>/$producers_platform_url/g;
					}
				}
			}
		}
	}

	my $minheight = 0;
	my $front_image = display_image_box($product_ref, 'front', \$minheight);
	$front_image =~ s/ width="/ itemprop="image" width="/;

	# Take the last (biggest) image
	my $product_image_url;
	if ($front_image =~ /.*src="([^"]*\/products\/[^"]+)"/is) {
		$product_image_url = $1;
	}

	my $product_fields = '';
	foreach my $field (@fields) {
		# print STDERR "display_product() - field: $field - value: $product_ref->{$field}\n";
		$product_fields .= display_field($product_ref, $field);
	}

	$template_data_ref->{front_image_html} = $front_image;
	$template_data_ref->{product_fields} = $product_fields;

	# try to display ingredients in the local language if available

	my $ingredients_text = $product_ref->{ingredients_text};
	my $ingredients_text_lang = $product_ref->{ingredients_lc};

	if (defined $product_ref->{ingredients_text_with_allergens}) {
		$ingredients_text = $product_ref->{ingredients_text_with_allergens};
	}

	if (    (defined $product_ref->{"ingredients_text" . "_" . $lc})
		and ($product_ref->{"ingredients_text" . "_" . $lc} ne ''))
	{
		$ingredients_text = $product_ref->{"ingredients_text" . "_" . $lc};
		$ingredients_text_lang = $lc;
	}

	if (    (defined $product_ref->{"ingredients_text_with_allergens" . "_" . $lc})
		and ($product_ref->{"ingredients_text_with_allergens" . "_" . $lc} ne ''))
	{
		$ingredients_text = $product_ref->{"ingredients_text_with_allergens" . "_" . $lc};
		$ingredients_text_lang = $lc;
	}

	if (not defined $ingredients_text) {
		$ingredients_text = "";
	}

	$ingredients_text =~ s/\n/<br>/g;

	# Indicate if we are displaying ingredients in another language than the language of the interface

	my $ingredients_text_lang_html = "";

	if (($ingredients_text ne "") and ($ingredients_text_lang ne $lc)) {
		$ingredients_text_lang_html
			= " (" . display_taxonomy_tag($lc, 'languages', $language_codes{$ingredients_text_lang}) . ")";
	}

	$template_data_ref->{ingredients_image} = display_image_box($product_ref, 'ingredients', \$minheight);
	$template_data_ref->{ingredients_text_lang} = $ingredients_text_lang;
	$template_data_ref->{ingredients_text} = $ingredients_text;

	if ($User{moderator} and ($ingredients_text !~ /^\s*$/)) {
		$template_data_ref->{User_moderator} = 'defined';

		my $ilc = $ingredients_text_lang;
		$template_data_ref->{ilc} = $ingredients_text_lang;

		$initjs .= <<JS

	var editableText;

	\$("#editingredients").click({},function(event) {
		event.stopPropagation();
		event.preventDefault();

		var divHtml = \$("#ingredients_list").html();
		var allergens = /(<span class="allergen">|<\\/span>)/g;
		divHtml = divHtml.replace(allergens, '_');

		var editableText = \$('<textarea id="ingredients_list" style="height:8rem" lang="$ilc" />');
		editableText.val(divHtml);
		\$("#ingredients_list").replaceWith(editableText);
		editableText.focus();

		\$("#editingredientsbuttondiv").hide();
		\$("#saveingredientsbuttondiv").show();

		\$(document).foundation('equalizer', 'reflow');

	});


	\$("#saveingredients").click({},function(event) {
		event.stopPropagation();
		event.preventDefault();

		\$('div[id="saveingredientsbuttondiv"]').hide();
		\$('div[id="saveingredientsbuttondiv_status"]').html('<img src="/images/misc/loading2.gif"> Saving ingredients_texts_$ilc');
		\$('div[id="saveingredientsbuttondiv_status"]').show();

		\$.post('/cgi/product_jqm_multilingual.pl',
			{code: "$code", ingredients_text_$ilc :  \$("#ingredients_list").val(), comment: "Updated ingredients_texts_$ilc" },
			function(data) {

				\$('div[id="saveingredientsbuttondiv_status"]').html('Saved ingredients_texts_$ilc');
				\$('div[id="saveingredientsbuttondiv"]').show();

				\$(document).foundation('equalizer', 'reflow');
			},
			'json'
		);

		\$(document).foundation('equalizer', 'reflow');

	});



	\$("#wipeingredients").click({},function(event) {
		event.stopPropagation();
		event.preventDefault();
		// alert(event.data.imagefield);
		\$('div[id="wipeingredientsbuttondiv"]').html('<img src="/images/misc/loading2.gif"> Erasing ingredients_texts_$ilc');
		\$.post('/cgi/product_jqm_multilingual.pl',
			{code: "$code", ingredients_text_$ilc : "", comment: "Erased ingredients_texts_$ilc: too much bad data" },
			function(data) {

				\$('div[id="wipeingredientsbuttondiv"]').html("Erased ingredients_texts_$ilc");
				\$('div[id="ingredients_list"]').html("");

				\$(document).foundation('equalizer', 'reflow');
			},
			'json'
		);

		\$(document).foundation('equalizer', 'reflow');

	});
JS
			;

	}

	$template_data_ref->{display_ingredients_in_lang} = sprintf(
		lang("add_ingredients_in_language"),
		display_taxonomy_tag($lc, 'languages', $language_codes{$request_lc})
	);

	$template_data_ref->{display_field_allergens} = display_field($product_ref, 'allergens');

	$template_data_ref->{display_field_traces} = display_field($product_ref, 'traces');

	$template_data_ref->{display_ingredients_analysis} = display_ingredients_analysis($product_ref);

	$template_data_ref->{display_ingredients_analysis_details} = display_ingredients_analysis_details($product_ref);

	# special ingredients tags

	if ((defined $ingredients_text) and ($ingredients_text !~ /^\s*$/s) and (defined $special_tags{ingredients})) {
		$template_data_ref->{special_ingredients_tags} = 'defined';

		my $special_html = "";

		foreach my $special_tag_ref (@{$special_tags{ingredients}}) {

			my $tagid = $special_tag_ref->{tagid};
			my $type = $special_tag_ref->{type};

			if (   (($type eq 'without') and (not has_tag($product_ref, "ingredients", $tagid)))
				or (($type eq 'with') and (has_tag($product_ref, "ingredients", $tagid))))
			{

				$special_html
					.= "<li class=\"${type}_${tagid}_$lc\">"
					. lang("search_" . $type) . " "
					. display_taxonomy_tag_link($lc, "ingredients", $tagid)
					. "</li>\n";
			}

		}

		$template_data_ref->{special_html} = $special_html;
	}

	# NOVA groups

	if (    (defined $options{product_type})
		and ($options{product_type} eq "food")
		and (exists $product_ref->{nova_group}))
	{
		$template_data_ref->{product_nova_group} = 'exists';
		my $group = $product_ref->{nova_group};

		my $display = display_taxonomy_tag($lc, "nova_groups", $product_ref->{nova_groups_tags}[0]);
		my $a_title = lang('nova_groups_info');

		$template_data_ref->{a_title} = $a_title;
		$template_data_ref->{group} = $group;
		$template_data_ref->{display} = $display;
	}

	# Do not display nutrition table for Open Beauty Facts

	if (not((defined $options{no_nutrition_table}) and ($options{no_nutrition_table}))) {

		$template_data_ref->{nutrition_table} = 'defined';

		# Display Nutri-Score and nutrient levels

		my $template_data_nutriscore_ref = data_to_display_nutriscore($product_ref);
		my $template_data_nutrient_levels_ref = data_to_display_nutrient_levels($product_ref);

		my $nutriscore_html = '';
		my $nutrient_levels_html = '';

		if (not $template_data_nutrient_levels_ref->{do_not_display}) {

			process_template('web/pages/product/includes/nutriscore.tt.html',
				$template_data_nutriscore_ref, \$nutriscore_html)
				|| return "template error: " . $tt->error();
			process_template(
				'web/pages/product/includes/nutrient_levels.tt.html',
				$template_data_nutrient_levels_ref,
				\$nutrient_levels_html
			) || return "template error: " . $tt->error();
		}

		$template_data_ref->{display_nutriscore} = $nutriscore_html;
		$template_data_ref->{display_nutrient_levels} = $nutrient_levels_html;

		$template_data_ref->{display_serving_size}
			= display_field($product_ref, "serving_size") . display_field($product_ref, "br");

		# Compare nutrition data with stats of the categories and display the nutrition table

		if ((defined $product_ref->{no_nutrition_data}) and ($product_ref->{no_nutrition_data} eq 'on')) {
			$template_data_ref->{no_nutrition_data} = 'on';
		}

		my $comparisons_ref = compare_product_nutrition_facts_to_categories($product_ref, $cc, undef);

		$template_data_ref->{display_nutrition_table} = display_nutrition_table($product_ref, $comparisons_ref);
		$template_data_ref->{nutrition_image} = display_image_box($product_ref, 'nutrition', \$minheight);

		if (has_tag($product_ref, "categories", "en:alcoholic-beverages")) {
			$template_data_ref->{has_tag} = 'categories-en:alcoholic-beverages';
		}
	}

	# Packaging

	$template_data_ref->{packaging_image} = display_image_box($product_ref, 'packaging', \$minheight);

	# try to display packaging in the local language if available

	my $packaging_text = $product_ref->{packaging_text};

	my $packaging_text_lang = $product_ref->{lc};

	if ((defined $product_ref->{"packaging_text" . "_" . $lc}) and ($product_ref->{"packaging_text" . "_" . $lc} ne ''))
	{
		$packaging_text = $product_ref->{"packaging_text" . "_" . $lc};
		$packaging_text_lang = $lc;
	}

	if (not defined $packaging_text) {
		$packaging_text = "";
	}

	$packaging_text =~ s/\n/<br>/g;

	$template_data_ref->{packaging_text} = $packaging_text;
	$template_data_ref->{packaging_text_lang} = $packaging_text_lang;

	# packagings data structure
	$template_data_ref->{packagings} = $product_ref->{packagings};

	# Forest footprint
	# 2020-12-07 - We currently display the forest footprint in France
	# and for moderators so that we can extend it to other countries
	if (($cc eq "fr") or ($User{moderator})) {
		# Forest footprint data structure
		$template_data_ref->{forest_footprint_data} = $product_ref->{forest_footprint_data};
	}

	# other fields

	my $other_fields = "";
	foreach my $field (@ProductOpener::Config::display_other_fields) {
		# print STDERR "display_product() - field: $field - value: $product_ref->{$field}\n";
		$other_fields .= display_field($product_ref, $field);
	}

	if ($other_fields ne "") {
		$template_data_ref->{other_fields} = $other_fields;
	}

	$template_data_ref->{admin} = $admin;

	# Platform for producers: data quality issues and improvements opportunities

	if ($server_options{producers_platform}) {

		$template_data_ref->{display_data_quality_issues_and_improvement_opportunities}
			= display_data_quality_issues_and_improvement_opportunities($product_ref);

	}

	# photos and data sources

	my @other_editors = ();

	foreach my $editor (@{$product_ref->{editors_tags}}) {
		next if ((defined $product_ref->{creator}) and ($editor eq $product_ref->{creator}));
		next if ((defined $product_ref->{last_editor}) and ($editor eq $product_ref->{last_editor}));
		push @other_editors, $editor;
	}

	my $other_editors = "";

	foreach my $editor (sort @other_editors) {
		$other_editors
			.= "<a href=\""
			. canonicalize_tag_link("editors", get_string_id_for_lang("no_language", $editor)) . "\">"
			. $editor
			. "</a>, ";
	}
	$other_editors =~ s/, $//;

	my $creator
		= "<a href=\""
		. canonicalize_tag_link("editors", get_string_id_for_lang("no_language", $product_ref->{creator})) . "\">"
		. $product_ref->{creator} . "</a>";
	my $last_editor
		= "<a href=\""
		. canonicalize_tag_link("editors", get_string_id_for_lang("no_language", $product_ref->{last_editor})) . "\">"
		. $product_ref->{last_editor} . "</a>";

	if ($other_editors ne "") {
		$other_editors = "<br>\n" . lang_in_other_lc($request_lc, "also_edited_by") . " ${other_editors}.";
	}

	my $checked = "";
	if ((defined $product_ref->{checked}) and ($product_ref->{checked} eq 'on')) {
		my $last_checked_date = display_date_tag($product_ref->{last_checked_t});
		my $last_checker
			= "<a href=\""
			. canonicalize_tag_link("editors", get_string_id_for_lang("no_language", $product_ref->{last_checker}))
			. "\">"
			. $product_ref->{last_checker} . "</a>";
		$checked
			= "<br/>\n"
			. lang_in_other_lc($request_lc, "product_last_checked")
			. " $last_checked_date "
			. lang_in_other_lc($request_lc, "by")
			. " $last_checker.";
	}

	$template_data_ref->{created_date} = display_date_tag($product_ref->{created_t});
	$template_data_ref->{creator} = $creator;
	$template_data_ref->{last_modified_date} = display_date_tag($product_ref->{last_modified_t});
	$template_data_ref->{last_editor} = $last_editor;
	$template_data_ref->{other_editors} = $other_editors;
	$template_data_ref->{checked} = $checked;

	if (defined $User_id) {
		$template_data_ref->{display_field_states} = display_field($product_ref, 'states');
	}

	$template_data_ref->{display_product_history} = display_product_history($request_ref, $code, $product_ref)
		if $User{moderator};

	# Twitter card

	# example:

	#<meta name="twitter:card" content="product">
	#<meta name="twitter:site" content="@iHeartRadio">
	#<meta name="twitter:creator" content="@iHeartRadio">
	#<meta name="twitter:title" content="24/7 Beatles — Celebrating 50 years of Beatlemania">
	#<meta name="twitter:image" content="http://radioedit.iheart.com/service/img/nop()/assets/images/05fbb21d-e5c6-4dfc-af2b-b1056e82a745.png">
	#<meta name="twitter:label1" content="Genre">
	#<meta name="twitter:data1" content="Classic Rock">
	#<meta name="twitter:label2" content="Location">
	#<meta name="twitter:data2" content="National">

	my $meta_product_image_url = "";
	if (defined $product_image_url) {
		$meta_product_image_url = <<HTML
<meta name="twitter:image" content="$product_image_url">
<meta property="og:image" content="$product_image_url">
HTML
			;
	}

	$header .= <<HTML
<meta name="twitter:card" content="product">
<meta name="twitter:site" content="@<twitter_account>">
<meta name="twitter:creator" content="@<twitter_account>">
<meta name="twitter:title" content="$title">
<meta name="twitter:description" content="$description">
HTML
		;

	if (defined $product_ref->{brands}) {
		# print only first brand if multiple exist.
		my @brands = split(',', $product_ref->{brands});
		$header .= <<HTML
<meta name="twitter:label1" content="$Lang{brands_s}{$lc}">
<meta name="twitter:data1" content="$brands[0]">
HTML
			;
	}

	# get most specific category (the last one)
	my $data2 = display_taxonomy_tag($lc, "categories", $product_ref->{categories_tags}[-1]);
	if ($data2) {
		$header .= <<HTML
<meta name="twitter:label2" content="$Lang{categories_s}{$lc}">
<meta name="twitter:data2" content="$data2">
HTML
			;
	}

	$header .= <<HTML
$meta_product_image_url

HTML
		;

	# Compute attributes and embed them as JSON
	# enable feature for moderators

	if ($request_ref->{user_preferences}) {

		# A result summary will be computed according to user preferences on the client side

		compute_attributes($product_ref, $lc, $cc, $attributes_options_ref);

		my $product_attribute_groups_json
			= decode_utf8(encode_json({"attribute_groups" => $product_ref->{"attribute_groups_" . $lc}}));
		my $preferences_text = lang("classify_products_according_to_your_preferences");

		$scripts .= <<JS
<script type="text/javascript">
var page_type = "product";
var preferences_text = "$preferences_text";
var product = $product_attribute_groups_json;
</script>

<script src="$static_subdomain/js/product-preferences.js"></script>
<script src="$static_subdomain/js/product-search.js"></script>
JS
			;

		$initjs .= <<JS
display_user_product_preferences("#preferences_selected", "#preferences_selection_form", function () { display_product_summary("#product_summary", product); });
display_product_summary("#product_summary", product);
JS
			;
	}

	my $html_display_product;
	process_template('web/pages/product/product_page.tt.html', $template_data_ref, \$html_display_product)
		|| ($html_display_product = "template error: " . $tt->error());
	$html .= $html_display_product;

	$request_ref->{content_ref} = \$html;
	$request_ref->{title} = $title;
	$request_ref->{description} = $description;
	$request_ref->{page_type} = "product";
	$request_ref->{page_format} = "banner";

	$log->trace("displayed product") if $log->is_trace();

	display_page($request_ref);

	return;
}

# Note: this function is needed for the API called by the old PhoneGap / Cordova app
# This app has been replaced for the last 5 years by the new iOS + Android apps and
# now by the Flutter app. But the current OBF app still uses it (as of 2024/04/24).

sub display_product_jqm ($request_ref) {    # jquerymobile

	my $request_lc = $request_ref->{lc};
	my $code = normalize_code($request_ref->{code});
	my $product_id = product_id_for_owner($Owner_id, $code);
	local $log->context->{code} = $code;
	local $log->context->{product_id} = $product_id;

	my $html = '';
	my $title = undef;
	my $description = undef;

	# Check that the product exist, is published, is not deleted, and has not moved to a new url

	$log->info("displaying product jquery mobile") if $log->is_info();

	$title = $code;

	my $product_ref;

	my $rev = single_param("rev");
	local $log->context->{rev} = $rev;
	if (defined $rev) {
		$log->info("displaying product revision on jquery mobile") if $log->is_info();
		$product_ref = retrieve_product_rev($product_id, $rev);
	}
	else {
		$product_ref = retrieve_product($product_id);
	}

	if (not defined $product_ref) {
		return;
	}

	$title = $product_ref->{product_name};

	if (not $title) {
		$title = $code;
	}

	if (defined $rev) {
		$title .= " version $rev";
	}

	$description = $title . ' - ' . $product_ref->{brands} . ' - ' . $product_ref->{generic_name};
	$description =~ s/ - $//;
	$request_ref->{canon_url} = product_url($product_ref);

	my @fields
		= qw(generic_name quantity packaging br brands br categories br labels br origins br manufacturing_places br emb_codes purchase_places stores);

	if ($code =~ /^2000/) {    # internal code
	}
	else {
		$html .= "<p>" . lang("barcode") . separator_before_colon($lc) . ": $code</p>\n";
	}

	# Generate HTML for Nutri-Score and nutrient levels
	my $template_data_nutriscore_and_nutrient_levels_ref = data_to_display_nutriscore_and_nutrient_levels($product_ref);

	my $nutriscore_html = '';
	my $nutrient_levels_html = '';

	if (not $template_data_nutriscore_and_nutrient_levels_ref->{do_not_display}) {

		process_template(
			'web/pages/product/includes/nutriscore.tt.html',
			$template_data_nutriscore_and_nutrient_levels_ref,
			\$nutriscore_html
		) || return "template error: " . $tt->error();
		process_template(
			'web/pages/product/includes/nutrient_levels.tt.html',
			$template_data_nutriscore_and_nutrient_levels_ref,
			\$nutrient_levels_html
		) || return "template error: " . $tt->error();
	}

	if (
			($lc eq 'fr')
		and
		(has_tag($product_ref, "labels", "fr:produits-retires-du-marche-lors-du-scandale-lactalis-de-decembre-2017"))
		)
	{

		$html .= <<HTML
<div id="warning_lactalis_201712" style="display: block; background:#ffaa33;color:black;padding:1em;text-decoration:none;">
Ce produit fait partie d'une liste de produits retirés du marché, et a été étiqueté comme tel par un bénévole d'Open Food Facts.
<br><br>
&rarr; <a href="http://www.lactalis.fr/wp-content/uploads/2017/12/ici-1.pdf">Liste des lots concernés</a> sur le site de <a href="http://www.lactalis.fr/information-consommateur/">Lactalis</a>.
</div>
HTML
			;

	}
	elsif (
			($lc eq 'fr')
		and (has_tag($product_ref, "categories", "en:baby-milks"))
		and (
			has_one_of_the_tags_from_the_list(
				$product_ref,
				"brands",
				[
					"amilk", "babycare", "celia-ad", "celia-develop",
					"celia-expert", "celia-nutrition", "enfastar", "fbb",
					"fl", "frezylac", "gromore", "malyatko",
					"mamy", "milumel", "milumel", "neoangelac",
					"nophenyl", "novil", "ostricare", "pc",
					"picot", "sanutri"
				]
			)
		)
		)
	{

		$html .= <<HTML
<div id="warning_lactalis_201712" style="display: block; background:#ffcc33;color:black;padding:1em;text-decoration:none;">
Certains produits de cette marque font partie d'une liste de produits retirés du marché.
<br><br>
&rarr; <a href="http://www.lactalis.fr/wp-content/uploads/2017/12/ici-1.pdf">Liste des produits et lots concernés</a> sur le site de <a href="http://www.lactalis.fr/information-consommateur/">Lactalis</a>.
</div>
HTML
			;

	}

	# Nutri-Score and nutrient levels

	$html .= $nutriscore_html;

	$html .= $nutrient_levels_html;

	# NOVA groups

	if ((exists $product_ref->{nova_group})) {
		my $group = $product_ref->{nova_group};

		my $display = display_taxonomy_tag($lc, "nova_groups", $product_ref->{nova_groups_tags}[0]);
		my $a_title = lang('nova_groups_info');

		$html .= <<HTML
<h4>$Lang{nova_groups_s}{$lc}
<a href="https://world.openfoodfacts.org/nova" title="${$a_title}">
@{[ display_icon('info') ]}</a>
</h4>


<a href="https://world.openfoodfacts.org/nova" title="${$a_title}"><img src="/images/misc/nova-group-$group.svg" alt="$display" style="margin-bottom:1rem;max-width:100%"></a><br>
$display
HTML
			;
	}

	my $minheight = 0;
	$product_ref->{jqm} = 1;
	my $html_image = display_image_box($product_ref, 'front', \$minheight);
	$html .= <<HTML
        <div data-role="deactivated-collapsible-set" data-theme="" data-content-theme="">
            <div data-role="deactivated-collapsible">
HTML
		;
	$html .= "<h2>" . lang("product_characteristics") . "</h2>
	<div style=\"min-height:${minheight}px;\">"
		. $html_image;

	foreach my $field (@fields) {
		# print STDERR "display_product() - field: $field - value: $product_ref->{$field}\n";
		$html .= display_field($product_ref, $field);
	}

	$html_image = display_image_box($product_ref, 'ingredients', \$minheight);

	# try to display ingredients in the local language

	my $ingredients_text = $product_ref->{ingredients_text};

	if (defined $product_ref->{ingredients_text_with_allergens}) {
		$ingredients_text = $product_ref->{ingredients_text_with_allergens};
	}

	if (    (defined $product_ref->{"ingredients_text" . "_" . $lc})
		and ($product_ref->{"ingredients_text" . "_" . $lc} ne ''))
	{
		$ingredients_text = $product_ref->{"ingredients_text" . "_" . $lc};
	}

	if (    (defined $product_ref->{"ingredients_text_with_allergens" . "_" . $lc})
		and ($product_ref->{"ingredients_text_with_allergens" . "_" . $lc} ne ''))
	{
		$ingredients_text = $product_ref->{"ingredients_text_with_allergens" . "_" . $lc};
	}

	$ingredients_text =~ s/<span class="allergen">(.*?)<\/span>/<b>$1<\/b>/isg;

	$html .= "</div>";

	$html .= <<HTML
			</div>
		</div>
        <div data-role="deactivated-collapsible-set" data-theme="" data-content-theme="">
            <div data-role="deactivated-collapsible" data-collapsed="true">
HTML
		;

	$html .= "<h2>" . lang("ingredients") . "</h2>
	<div style=\"min-height:${minheight}px\">"
		. $html_image;

	$html .= "<p class=\"note\">&rarr; " . lang("ingredients_text_display_note") . "</p>";
	$html
		.= "<div id=\"ingredients_list\" ><span class=\"field\">"
		. lang("ingredients_text")
		. separator_before_colon($lc)
		. ":</span> $ingredients_text</div>";

	$html .= display_field($product_ref, 'allergens');

	$html .= display_field($product_ref, 'traces');

	my $class = 'additives';

	if ((defined $product_ref->{$class . '_tags'}) and (scalar @{$product_ref->{$class . '_tags'}} > 0)) {

		$html
			.= "<br><hr class=\"floatleft\"><div><b>" . lang("additives_p") . separator_before_colon($lc) . ":</b><br>";

		$html .= "<ul>";
		foreach my $tagid (@{$product_ref->{$class . '_tags'}}) {

			my $tag;
			my $link;

			# taxonomy field?
			if (defined $taxonomy_fields{$class}) {
				$tag = display_taxonomy_tag($lc, $class, $tagid);
				$link = canonicalize_taxonomy_tag_link($lc, $class, $tagid);
			}
			else {
				$tag = canonicalize_tag2($class, $tagid);
				$link = canonicalize_tag_link($class, $tagid);
			}

			my $info = '';

			$html .= "<li><a href=\"" . $link . "\"$info>" . $tag . "</a></li>\n";
		}
		$html .= "</ul></div>";

	}

	# special ingredients tags

	if ((defined $ingredients_text) and ($ingredients_text !~ /^\s*$/s) and (defined $special_tags{ingredients})) {

		my $special_html = "";

		foreach my $special_tag_ref (@{$special_tags{ingredients}}) {

			my $tagid = $special_tag_ref->{tagid};
			my $type = $special_tag_ref->{type};

			if (   (($type eq 'without') and (not has_tag($product_ref, "ingredients", $tagid)))
				or (($type eq 'with') and (has_tag($product_ref, "ingredients", $tagid))))
			{

				$special_html
					.= "<li class=\"${type}_${tagid}_$lc\">"
					. lang("search_" . $type) . " "
					. display_taxonomy_tag_link($lc, "ingredients", $tagid)
					. "</li>\n";
			}

		}

		if ($special_html ne "") {

			$html
				.= "<br><hr class=\"floatleft\"><div><b>"
				. ucfirst(lang("ingredients_analysis") . separator_before_colon($lc))
				. ":</b><br>"
				. "<ul id=\"special_ingredients\">\n"
				. $special_html
				. "</ul>\n" . "<p>"
				. lang("ingredients_analysis_note")
				. "</p></div>\n";
		}

	}

	$html_image = display_image_box($product_ref, 'nutrition', \$minheight);

	$html .= "</div>";

	$html .= <<HTML
			</div>
		</div>
HTML
		;

	if (not((defined $options{no_nutrition_table}) and ($options{no_nutrition_table}))) {

		$html .= <<HTML
        <div data-role="deactivated-collapsible-set" data-theme="" data-content-theme="">
            <div data-role="deactivated-collapsible" data-collapsed="true">
HTML
			;

		$html .= "<h2>" . lang("nutrition_data") . "</h2>";

		# Nutri-Score and nutrient levels

		$html .= $nutriscore_html;

		$html .= $nutrient_levels_html;

		$html .= "<div style=\"min-height:${minheight}px\">" . $html_image;

		$html .= display_field($product_ref, "serving_size") . display_field($product_ref, "br");

		# Compare nutrition data with categories

		my @comparisons = ();

		if ($product_ref->{no_nutrition_data} eq 'on') {
			$html .= "<div class='panel callout'>" . lang_in_other_lc($request_lc, "no_nutrition_data") . "</div>";
		}

		$html .= display_nutrition_table($product_ref, \@comparisons);

		$html .= <<HTML
			</div>
		</div>
HTML
			;
	}

	my $created_date = display_date_tag($product_ref->{created_t});

	# Ask for photos if we do not have any, or if they are too old

	my $last_image = "";
	my $image_warning = "";

	if ((not defined($product_ref->{images})) or ((scalar keys %{$product_ref->{images}}) < 1)) {

		$image_warning = lang_in_other_lc($request_lc, "product_has_no_photos");

	}
	elsif ((defined $product_ref->{last_image_t}) and ($product_ref->{last_image_t} > 0)) {

		my $last_image_date = display_date($product_ref->{last_image_t});
		my $last_image_date_without_time = display_date_without_time($product_ref->{last_image_t});

		$last_image = "<br>" . lang_in_other_lc($request_lc, "last_image_added") . " $last_image_date";

		# Was the last photo uploaded more than 6 months ago?

		if (($product_ref->{last_image_t} + 86400 * 30 * 6) < time()) {

			$image_warning
				= sprintf(lang_in_other_lc($request_lc, "product_has_old_photos"), $last_image_date_without_time);
		}
	}

	if ($image_warning ne "") {

		$image_warning = <<HTML
<div id="image_warning" style="display: block; background:#ffcc33;color:black;padding:1em;text-decoration:none;">
$image_warning
</div>
HTML
			;

	}

	my $creator = $product_ref->{creator};

	# Remove links for iOS (issues with twitter / facebook badges loading in separate windows..)
	$html =~ s/<a ([^>]*)href="([^"]+)"([^>]*)>/<span $1$3>/g
		;    # replace with a span to keep class for color of additives etc.
	$html =~ s/<\/a>/<\/span>/g;
	$html =~ s/<span >/<span>/g;
	$html =~ s/<span  /<span /g;

	$html .= <<HTML

<p>
$Lang{product_added}{$lc} $created_date $Lang{by}{$lc} $creator
$last_image
</p>


<div style="margin-bottom:20px;">

<p>$Lang{fixme_product}{$request_lc}</p>

$image_warning

<p>$Lang{app_you_can_add_pictures}{$request_lc}</p>

<button onclick="captureImage();" data-icon="off-camera">$Lang{image_front}{$request_lc}</button>
<div id="upload_image_result_front"></div>
<button onclick="captureImage();" data-icon="off-camera">$Lang{image_ingredients}{$request_lc}</button>
<div id="upload_image_result_ingredients"></div>
<button onclick="captureImage();" data-icon="off-camera">$Lang{image_nutrition}{$request_lc}</button>
<div id="upload_image_result_nutrition"></div>
<button onclick="captureImage();" data-icon="off-camera">$Lang{app_take_a_picture}{$request_lc}</button>
<div id="upload_image_result"></div>
<p>$Lang{app_take_a_picture_note}{$request_lc}</p>

</div>
HTML
		;

	$request_ref->{jqm_content} = $html;
	$request_ref->{title} = $title;
	$request_ref->{description} = $description;

	$log->trace("displayed product on jquery mobile") if $log->is_trace();

	return;
}




1;

