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

ProductOpener::Request - abstraction over the Request object from the underlying Web framework

=cut

package ProductOpener::Request;
use ProductOpener::PerlStandards;


use ProductOpener::Utils ();


use CGI qw(referer user_agent param); # qw(:cgi :cgi-lib :form escapeHTML');
use Apache2::RequestUtil ();
use Apache2::RequestRec ();
use Apache2::Const qw(:http :common);



sub new ($class, $initial_request_ref, $log) {

	# shallow-copy the supplied hashref into a fresh object
	my $self = bless {%$initial_request_ref}, $class;


	# Initialize the request object
	$self->{referer} = referer();
	$self->{original_query_string} = $ENV{QUERY_STRING};
	# Get the cgi script path if the URL was to a /cgi/ script
	# unset it if it is /cgi/display.pl (default route for non /cgi/ scripts)
	$self->{script_name} = $ENV{SCRIPT_NAME};
	if ($self->{script_name} eq "/cgi/display.pl") {
		delete $self->{script_name};
	}

	# Depending on web server configuration, we may get or not get a / at the start of the QUERY_STRING environment variable
	# remove the / to normalize the query string, as we use it to build some redirect urls
	$self->{original_query_string} =~ s/^\///;

	# Set $self->{is_crawl_bot}
	$self->set_user_agent_request_ref_attributes();

	# `no_index` specifies whether we send an empty HTML page with a <meta name="robots" content="noindex">
	# in the HTML headers. This is only done for known web crawlers (Google, Bing, Yandex,...) on webpages that
	# trigger heavy DB aggregation queries and overload our server.
	$self->{no_index} = 0;
	# If deny_all_robots_txt=1, serve a version of robots.txt where all agents are denied access (Disallow: /)
	$self->{deny_all_robots_txt} = 0;


	my $r = Apache2::RequestUtil->request();
	$self->{method} = $r->method();


	$self->{hostname} = $r->hostname;

	return $self;
}

	


=head2 set_user_agent_request_ref_attributes

Set two attributes to `request_ref`:

- `user_agent`: the request User-Agent
- `is_crawl_bot`: a flag (0 or 1) that indicates whether the request comes
  from a known web crawler (Google, Bing,...). We only use User-Agent value
  to set this flag.
- `is_denied_crawl_bot`: a flag (0 or 1) that indicates whether the request
  comes from a web crawler we want to deny access to.

=cut

sub set_user_agent_request_ref_attributes ($self) {
	my $user_agent_str = user_agent();
	$self->{user_agent} = $user_agent_str;

	my $is_crawl_bot = 0;
	my $is_denied_crawl_bot = 0;
	if ($user_agent_str
		=~ /\b(Googlebot|Googlebot-Image|Google-InspectionTool|bingbot|Applebot|Yandex|DuckDuck|DotBot|Seekport|Ahrefs|DataForSeo|Seznam|ZoomBot|Mojeek|QRbot|Qwant|facebookexternalhit|Bytespider|GPTBot|SEOkicks|Searchmetrics|MJ12|SurveyBot|SEOdiver|wotbox|Cliqz|Paracrawl|Scrapy|VelenPublicWebCrawler|Semrush|MegaIndex\.ru|Amazon|aiohttp|python-request)/i
		)
	{
		$is_crawl_bot = 1;
		if ($user_agent_str
			=~ /\b(bingbot|Seekport|Ahrefs|DataForSeo|Seznam|ZoomBot|Mojeek|QRbot|Bytespider|SEOkicks|Searchmetrics|MJ12|SurveyBot|SEOdiver|wotbox|Cliqz|Paracrawl|Scrapy|VelenPublicWebCrawler|Semrush|MegaIndex\.ru|YandexMarket|Amazon)/
			)
		{
			$is_denied_crawl_bot = 1;
		}
	}
	$self->{is_crawl_bot} = $is_crawl_bot;
	$self->{is_denied_crawl_bot} = $is_denied_crawl_bot;
	return;
}


=head2 request_param ($request_ref, $param_name)

Return a request parameter. The parameter can be passed in the query string,
as a POST multipart form data parameter, or in a POST JSON body

=head3 Arguments

=head4 Parameter name $param_name

=head3 Return value

A scalar value for the parameter, or undef if the parameter is not defined.

=cut

sub request_param ($request_ref, $param_name) {
	my $cgi_param = scalar param($param_name);
	if (defined $cgi_param) {
		return decode utf8 => $cgi_param;
	}
	else {
		return deep_get($request_ref, "body_json", $param_name);
	}
}



#======================================================================
# backcompat functions
#======================================================================

=head2 single_param ($param_name)

CGI.pm param() function returns a list when called in a list context
(e.g. when param() is an argument of a function, or the value of a field in a hash).
This causes issues for function signatures that expect a scalar, and that may get passed an empty list
if the parameter is not set.

So instead of calling CGI.pm param() directly, we call single_param() to prefix it with scalar.

=head3 Arguments

=head4 CGI parameter name $param_name

=head3 Return value

A scalar value for the parameter, or undef if the parameter is not defined.

=cut

sub single_param ($param_name) {
	return scalar param($param_name);
}





# Parameters that can be query filters passed as parameters
# (GET query parameters, POST JSON body or from url facets),
# in addition to tags fields.
# It is safer to use a positive list, instead of just the %ignore_params list

my %valid_params = (code => 1, creator => 1);

sub TODO_add_params_to_query ($request_ref, $query_ref) {

	$log->debug("add_params_to_query", {params => {CGI::Vars()}}) if $log->is_debug();

	# nocache was renamed to no_cache
	if (defined single_param('nocache')) {
		param('no_cache', single_param('nocache'));
	}

	my $and = $query_ref->{"\$and"};

	foreach my $field (list_all_request_params($request_ref)) {

		$log->debug("add_params_to_query - field", {field => $field}) if $log->is_debug();

		# skip params that are not query filters
		next if (defined $ignore_params{$field});

		if (($field eq "page") or ($field eq "page_size")) {
			$request_ref->{$field} = single_param($field) + 0;    # Make sure we have a number
		}

		elsif ($field eq "sort_by") {
			$request_ref->{$field} = single_param($field);
		}

		# Tags fields can be passed with taxonomy ids as values (e.g labels_tags=en:organic)
		# or with values in a given language (e.g. labels_tags_fr=bio)

		elsif ($field =~ /^(.*)_tags(_(\w\w))?/) {
			my $tagtype = $1;
			my $tag_lc = $lc;
			if (defined $3) {
				$tag_lc = $3;
			}

			# Possible values:
			# xyz_tags=a
			# xyz_tags=a,b	products with tag a and b
			# xyz_tags=a|b	products with either tag a or tag b
			# xyz_tags=-c	products without the c tag
			# xyz_tags=a,b,-c,-d

			my $values = remove_tags_and_quote(request_param($request_ref, $field));

			$log->debug("add_params_to_query - tags param",
				{field => $field, lc => $lc, tag_lc => $tag_lc, values => $values})
				if $log->is_debug();

			foreach my $tag (split(/,/, $values)) {

				my $suffix = "_tags";

				# If there is more than one criteria on the same field, we need to use a $and query
				my $remove = 0;
				if (defined $query_ref->{$tagtype . $suffix}) {
					$remove = 1;
					if (not defined $and) {
						$and = [];
					}
					push @$and, {$tagtype . $suffix => $query_ref->{$tagtype . $suffix}};
				}

				my $not;
				if ($tag =~ /^-/) {
					$not = 1;
					$tag = $';
				}

				# Multiple values separated by |
				if ($tag =~ /\|/) {
					my @tagids = ();
					foreach my $tag2 (split(/\|/, $tag)) {
						my $tagid2;
						if (defined $taxonomy_fields{$tagtype}) {
							$tagid2 = get_taxonomyid($tag_lc, canonicalize_taxonomy_tag($tag_lc, $tagtype, $tag2));
							if ($tagtype eq 'additives') {
								$tagid2 =~ s/-.*//;
							}
						}
						else {
							$tagid2 = get_string_id_for_lang("no_language", canonicalize_tag2($tagtype, $tag2));
							# EU packager codes are normalized to have -ec at the end
							if ($tagtype eq 'emb_codes') {
								$tagid2 =~ s/-($ec_code_regexp)$/-ec/ie;
							}
						}
						push @tagids, $tagid2;
					}

					$log->debug(
						"add_params_to_query - tags param - multiple values (OR) separated by | ",
						{field => $field, lc => $lc, tag_lc => $tag_lc, tag => $tag, tagids => \@tagids}
					) if $log->is_debug();

					if ($not) {
						$query_ref->{$tagtype . $suffix} = {'$nin' => \@tagids};
					}
					else {
						$query_ref->{$tagtype . $suffix} = {'$in' => \@tagids};
					}
				}
				# Single value
				else {
					my $tagid;
					if (defined $taxonomy_fields{$tagtype}) {
						$tagid = get_taxonomyid($tag_lc, canonicalize_taxonomy_tag($tag_lc, $tagtype, $tag));
						if ($tagtype eq 'additives') {
							$tagid =~ s/-.*//;
						}
					}
					else {
						$tagid = get_string_id_for_lang("no_language", canonicalize_tag2($tagtype, $tag));
						# EU packager codes are normalized to have -ec at the end
						if ($tagtype eq 'emb_codes') {
							$tagid =~ s/-($ec_code_regexp)$/-ec/ie;
						}
					}
					$log->debug("add_params_to_query - tags param - single value",
						{field => $field, lc => $lc, tag_lc => $tag_lc, tag => $tag, tagid => $tagid})
						if $log->is_debug();

					# if the value is "unknown", we need to add a condition on the field being empty
					# warning: unknown is a value for pnns_groups_1 and 2
					if (
						(
							($tagid eq get_string_id_for_lang($tag_lc, lang("unknown")))
							or (
								$tagid eq (
									$tag_lc . ":"
										. get_string_id_for_lang($tag_lc, lang_in_other_lc($tag_lc, "unknown"))
								)
							)
						)
						and ($tagtype !~ /^pnns_groups_/)
						and ($tagtype ne "creator")
						)
					{
						if ($not) {
							$query_ref->{$tagtype . $suffix} = {'$nin' => [undef, []]};
						}
						else {
							$query_ref->{$tagtype . $suffix} = {'$in' => [undef, []]};
						}

					}
					# Normal single value (not unknown)
					else {
						if ($not) {
							$query_ref->{$tagtype . $suffix} = {'$ne' => $tagid};
						}
						else {
							$query_ref->{$tagtype . $suffix} = $tagid;
						}
					}
				}

				if ($remove) {
					push @$and, {$tagtype . $suffix => $query_ref->{$tagtype . $suffix}};
					delete $query_ref->{$tagtype . $suffix};
					$query_ref->{"\$and"} = $and;
				}
			}
		}

		# Conditions on nutrients

		# e.g. saturated-fat_prepared_serving=<3=0
		# the parameter name is exactly the same as the key in the nutriments hash of the product

		elsif ($field =~ /^(.*?)_(100g|serving)$/) {

			# We can have multiple conditions, separated with a comma
			# e.g. sugars_100g=>10,<=20

			my $conditions = request_param($request_ref, $field);

			$log->debug("add_params_to_query - nutrient conditions", {field => $field, conditions => $conditions})
				if $log->is_debug();

			foreach my $condition (split(/,/, $conditions)) {

				# the field value is a number, possibly preceded by <, >, <= or >=

				my $operator;
				my $value;

				if ($condition =~ /^(<|>|<=|>=)(\d.*)$/) {
					$operator = $1;
					$value = $2;
				}
				else {
					$operator = '=';
					$value = request_param($request_ref, $field);
				}

				$log->debug("add_params_to_query - nutrient condition",
					{field => $field, condition => $condition, operator => $operator, value => $value})
					if $log->is_debug();

				my %mongo_operators = (
					'<' => 'lt',
					'<=' => 'lte',
					'>' => 'gt',
					'>=' => 'gte',
				);

				if ($operator eq '=') {
					$query_ref->{"nutriments." . $field}
						= $value + 0.0;    # + 0.0 to force scalar to be treated as a number
				}
				else {
					if (not defined $query_ref->{$field}) {
						$query_ref->{"nutriments." . $field} = {};
					}
					$query_ref->{"nutriments." . $field}{'$' . $mongo_operators{$operator}} = $value + 0.0;
				}
			}
		}

		# Exact match on a specific field (e.g. "code")
		elsif (defined $valid_params{$field}) {

			my $values = remove_tags_and_quote(request_param($request_ref, $field));

			# Possible values:
			# xyz=a
			# xyz=a|b xyz=a,b xyz=a+b	products with either xyz a or xyz b

			if ($values =~ /\||\+|,/) {
				# Multiple values: construct a MongoDB $in query
				my @values = split(/\||\+|,/, $values);
				if ($field eq "code") {
					# normalize barcodes: add missing leading 0s
					$query_ref->{$field} = {'$in' => [map {normalize_code($_)} @values]};
				}
				else {
					$query_ref->{$field} = {'$in' => \@values};
				}
			}
			else {
				# Single value
				if ($field eq "code") {
					$query_ref->{$field} = normalize_code($values);
				}
				else {
					$query_ref->{$field} = $values;
				}
			}
		}
	}
	return;
}






1;

