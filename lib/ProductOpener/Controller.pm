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

ProductOpener::Controller - manage a request lifecycle

=head1 DESCRIPTION

This module is an intermediary step for refactoring ProductOpener towards a modern
MVC architecture.
At this point no firm decision has been made about which Web framework will be used, so 
this temporary module is a bare object managing a request lifecycle
(previously it was mixed up with request/response information in the old huge 'Display.pm').

=cut

package ProductOpener::Controller;
use ProductOpener::PerlStandards;




sub new ($class, $request_ref, $log) {

	$log->debug("controller - start", {request_ref => $request_ref}) if $log->is_debug();

	my $self = bless {}, $class;


	# Clear the log context
	delete $log->context->{user_id};
	delete $log->context->{user_session};
	$log->context->{request} = ProductOpener::Utils->generate_token(16);


	# former global vars
	$self->{cc} = 'world';
	$self->{lc} = 'en';
	$self->{lcs} = [];
	$self->{country} = 'en:world';


	$self->{request} = ProductOpener::Request->new($request_ref, $log);
	$self->{response} = ProductOpener::Response->new();





	# sub-domain format:
	#
	# [2 letters country code or "world"] -> set cc + default language for the country
	# [2 letters country code or "world"]-[2 letters language code] -> set cc + lc
	#
	# Note: cc and lc can be overridden by query parameters
	# (especially for the API so that we can use only one subdomain : api.openfoodfacts.org)

	my $hostname = $r->hostname;
	$subdomain = lc($hostname);

	local $log->context->{hostname} = $hostname;
	local $log->context->{ip} = remote_addr();
	local $log->context->{query_string} = $self->req->{original_query_string};

	$subdomain =~ s/\..*//;

	$original_subdomain = $subdomain;    # $subdomain can be changed if there are cc and/or lc overrides

	$log->debug("initializing request", {subdomain => $subdomain}) if $log->is_debug();

	if ($subdomain eq 'world') {
		($cc, $country, $lc) = ('world', 'en:world', 'en');
	}
	elsif (defined $country_codes{$subdomain}) {
		# subdomain is the country code: fr.openfoodfacts.org, uk.openfoodfacts.org,...
		local $log->context->{subdomain_format} = 1;

		$cc = $subdomain;
		$country = $country_codes{$cc};
		$lc = $country_languages{$cc}[0];    # first official language

		$log->debug("subdomain matches known country code",
			{subdomain => $subdomain, lc => $lc, cc => $cc, country => $country})
			if $log->is_debug();

		if (not exists $Langs{$lc}) {
			$log->debug("current lc does not exist, falling back to lc = en",
				{subdomain => $subdomain, lc => $lc, cc => $cc, country => $country})
				if $log->is_debug();
			$lc = 'en';
		}

	}
	elsif ($subdomain =~ /(.*?)-(.*)/) {
		# subdomain contains the country code and the language code: world-fr.openfoodfacts.org, ch-it.openfoodfacts.org,...
		local $log->context->{subdomain_format} = 2;
		$log->debug("subdomain in cc-lc format - checking values",
			{subdomain => $subdomain, lc => $lc, cc => $cc, country => $country})
			if $log->is_debug();

		if (defined $country_codes{$1}) {
			$cc = $1;
			$country = $country_codes{$cc};
			$lc = $country_languages{$cc}[0];    # first official language
			if (defined $language_codes{$2}) {
				$lc = $2;
				$lc =~ s/-/_/;    # pt-pt -> pt_pt
			}

			$log->debug("subdomain matches known country code",
				{subdomain => $subdomain, lc => $lc, cc => $cc, country => $country})
				if $log->is_debug();
		}
	}
	elsif (defined $country_names{$subdomain}) {
		local $log->context->{subdomain_format} = 3;
		($cc, $country, $lc) = @{$country_names{$subdomain}};

		$log->debug("subdomain matches known country name",
			{subdomain => $subdomain, lc => $lc, cc => $cc, country => $country})
			if $log->is_debug();
	}
	elsif ($self->req->{original_query_string} !~ /^api\//) {
		# redirect
		my $redirect_url
			= get_world_subdomain()
			. ($self->req->{script_name} ? $self->req->{script_name} . "?" : '/')
			. $self->req->{original_query_string};
		$log->info("request could not be matched to a known country, redirecting to world",
			{subdomain => $subdomain, lc => $lc, cc => $cc, country => $country, redirect => $redirect_url})
			if $log->is_info();
		redirect_to_url($self, 302, $redirect_url);
	}

	$lc =~ s/_.*//;    # PT_PT doest not work yet: categories

	if ((not defined $lc) or (($lc !~ /^\w\w(_|-)\w\w$/) and (length($lc) != 2))) {
		$log->debug("replacing unknown lc with en", {lc => $lc}) if $log->debug();
		$lc = 'en';
	}

	# If the language is equal to the first language of the country, but we are on a different subdomain, redirect to the main country subdomain. (fr-fr => fr)
	if (    (defined $lc)
		and (defined $cc)
		and (defined $country_languages{$cc}[0])
		and ($country_languages{$cc}[0] eq $lc)
		and ($subdomain ne $cc)
		and ($subdomain !~ /^(ssl-)?api/)
		and ($r->method() eq 'GET')
		and ($self->req->{original_query_string} !~ /^api\//))
	{
		# redirect
		my $ccdom = format_subdomain($cc);
		my $redirect_url
			= $ccdom
			. ($self->req->{script_name} ? $self->req->{script_name} . "?" : '/')
			. $self->req->{original_query_string};
		$log->info(
			"lc is equal to first lc of the country, redirecting to countries main domain",
			{subdomain => $subdomain, lc => $lc, cc => $cc, country => $country, redirect => $redirect_url}
		) if $log->is_info();
		redirect_to_url($self, 302, $redirect_url);
	}

	# Allow cc and lc overrides as query parameters
	# do not redirect to the corresponding subdomain
	my $cc_lc_overrides = 0;
	my $param_cc = single_param('cc');
	if ((defined $param_cc) and ((defined $country_codes{lc($param_cc)}) or (lc($param_cc) eq 'world'))) {
		$cc = lc($param_cc);
		$country = $country_codes{$cc};
		$cc_lc_overrides = 1;
		$log->debug("cc override from request parameter", {cc => $cc}) if $log->is_debug();
	}
	my $param_lc = single_param('lc');
	if (defined $param_lc) {
		# allow multiple languages in an ordered list
		@lcs = split(/,/, lc($param_lc));
		if (defined $language_codes{$lcs[0]}) {
			$lc = $lcs[0];
			$cc_lc_overrides = 1;
			$log->debug("lc override from request parameter", {lc => $lc, lcs => \@lcs}) if $log->is_debug();
		}
		else {
			@lcs = ($lc);
		}
	}
	else {
		@lcs = ($lc);
	}
	# change the subdomain if we have overrides so that links to product pages are properly constructed
	if ($cc_lc_overrides) {
		$subdomain = $cc;
		if (not((defined $country_languages{$cc}[0]) and ($lc eq $country_languages{$cc}[0]))) {
			$subdomain .= "-" . $lc;
		}
	}

	# If lc is not one of the official languages of the country and if the request comes from
	# a bot crawler, don't index the webpage (return an empty noindex HTML page)
	# We also disable indexing for all subdomains that don't have the format world, cc or cc-lc
	if ((!($lc ~~ $country_languages{$cc})) or $subdomain =~ /^(ssl-)?api/) {
		# Use robots.txt with disallow: / for all agents
		$self->{deny_all_robots_txt} = 1;

		if ($self->{is_crawl_bot} eq 1) {
			$self->{no_index} = 1;
		}
	}

	# select the nutriment table format according to the country
	$nutriment_table = $cc_nutriment_table{default};
	if (exists $cc_nutriment_table{$cc}) {
		$nutriment_table = $cc_nutriment_table{$cc};
	}

	if ($test) {
		$subdomain =~ s/\.openfoodfacts/.test.openfoodfacts/;
	}

	$log->debug(
		"URI parsed for additional information",
		{
			subdomain => $subdomain,
			original_subdomain => $original_subdomain,
			lc => $lc,
			cc => $cc,
			country => $country
		}
	) if $log->is_debug();




	return $self;
}



sub req($self) {
	return $self->{request};
}



1;

