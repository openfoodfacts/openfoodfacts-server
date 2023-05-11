#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# startup file for preloading modules into Apache/mod_perl when the server starts
# (instead of when each httpd child starts)
# see http://apache.perl.org/docs/1.0/guide/performance.html#Code_Profiling_Techniques
#

use ProductOpener::PerlStandards;

use Carp ();

eval {Carp::confess('init')};    ## no critic (RequireCheckingReturnValueOfEval)

# used for debugging hanging httpd processes
# http://perl.apache.org/docs/1.0/guide/debug.html#Detecting_hanging_processes
local $SIG{'USR2'} = sub {
	Carp::confess('caught SIGUSR2!');
};

use CGI ();
CGI->compile(':all');

use Fcntl qw/:mode/;
use Storable ();
use LWP::Simple ();
use LWP::UserAgent ();
use Image::Magick ();
use File::Copy ();
use XML::Encoding ();
use Encode ();
use Cache::Memcached::Fast ();
use URI::Escape::XS ();
use File::chmod::Recursive;

# The line 'use Minion;', either in this startup script, or in a module
# loaded by it (e.g. Producers.pm) causes Apache+modperl to exit.
# A reason / workaround has not been found yet, so commenting out the preloading
# of Minion and Producers.
# Corresponding issue: https://github.com/openfoodfacts/openfoodfacts-server/issues/7695
#use Minion ();

use ProductOpener::Config qw/:all/;

use Log::Any qw($log);
use Log::Log4perl;
Log::Log4perl->init("$conf_root/log.conf");    # Init log4perl from a config file.
use Log::Any::Adapter;
Log::Any::Adapter->set('Log4perl');    # Send all logs to Log::Log4perl

use ProductOpener::Lang qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Units qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Tags qw/:all/;
use ProductOpener::URL qw/:all/;
use ProductOpener::Version qw/:all/;
use ProductOpener::DataQuality qw/:all/;
use ProductOpener::DataQualityCommon qw/:all/;
use ProductOpener::DataQualityFood qw/:all/;
use ProductOpener::Packaging qw/:all/;
use ProductOpener::ForestFootprint qw/:all/;
use ProductOpener::Nutriscore qw(:all);
use ProductOpener::Ecoscore qw(:all);
use ProductOpener::Attributes qw(:all);
use ProductOpener::KnowledgePanels qw(:all);
use ProductOpener::Orgs qw(:all);
use ProductOpener::Web qw(:all);
use ProductOpener::Recipes qw(:all);
use ProductOpener::MainCountries qw/:all/;
use ProductOpener::PackagerCodes qw/:all/;
use ProductOpener::API qw/:all/;
use ProductOpener::APITest qw/:all/;
use ProductOpener::APIProductRead qw/:all/;
use ProductOpener::APIProductWrite qw/:all/;
use ProductOpener::APITaxonomySuggestions qw/:all/;
use ProductOpener::TaxonomySuggestions qw/:all/;
use ProductOpener::Routing qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Export qw/:all/;
use ProductOpener::Import qw/:all/;
use ProductOpener::ImportConvert qw/:all/;
use ProductOpener::Numbers qw/:all/;
# Following line cause Apache to crash at startup on dev server https://github.com/openfoodfacts/openfoodfacts-server/issues/7695
#use ProductOpener::Producers qw/:all/;
use ProductOpener::ProducersFood qw/:all/;
use ProductOpener::GeoIP qw/:all/;
use ProductOpener::GS1 qw/:all/;
use ProductOpener::Redis qw/:all/;
use ProductOpener::FoodGroups qw/:all/;
use ProductOpener::Events qw/:all/;
use ProductOpener::Data qw/:all/;
use ProductOpener::LoadData qw/:all/;
use ProductOpener::NutritionCiqual qw/:all/;
use ProductOpener::NutritionEstimation qw/:all/;

use Apache2::Const -compile => qw(OK);
use Apache2::Connection ();
use Apache2::RequestRec ();
use APR::Table ();

sub get_remote_proxy_address {
	my $r = shift;

	# we'll only look at the X-Forwarded-For header if the requests
	# comes from our proxy at localhost
	if (
		!(
			(
				($r->useragent_ip eq '127.0.0.1')
				or 1    # all IPs
			)
			and $r->headers_in->get('X-Forwarded-For')
		)
		)
	{
		return Apache2::Const::OK;
	}

	# Select last value in the chain -- original client's ip
	if (my ($ip) = $r->headers_in->get('X-Forwarded-For') =~ /([^,\s]+)$/sxm) {
		$r->useragent_ip($ip);
	}

	return Apache2::Const::OK;
}

# set up error logging
open *STDERR, '>', "/$data_root/logs/modperl_error_log" or Carp::croak('Could not open modperl_error_log');
print {*STDERR} $log or Carp::croak('Unable to write to *STDERR');

# load large data files into mod_perl memory
load_data();

# This startup script is run as root, it will create the $data_root/tmp directory
# if it does not exist, as well as sub-directories for the Template module
# We need to set more permissive permissions so that it can be writable by the Apache user.

chmod_recursive(S_IRWXU | S_IRWXG | S_IRWXO, "$data_root/tmp");

$log->info('product opener started', {version => $version});

1;
