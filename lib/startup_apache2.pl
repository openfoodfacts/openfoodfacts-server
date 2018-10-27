#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.



# startup file for preloading modules into Apache/mod_perl when the server starts
# (instead of when each httpd child starts)
# see http://apache.perl.org/docs/1.0/guide/performance.html#Code_Profiling_Techniques
#
use utf8;
use Modern::Perl '2012';

use Carp ();

eval { Carp::confess("init") };

# used for debugging hanging httpd processes
# http://perl.apache.org/docs/1.0/guide/debug.html#Detecting_hanging_processes
$SIG{'USR2'} = sub { 
   Carp::confess("caught SIGUSR2!");
};

use CGI ();
CGI->compile(':all');

use Storable ();
use LWP::Simple ();
use LWP::UserAgent ();
use Image::Magick ();
use File::Copy ();
use XML::Encoding ();
use Encode ();
use Cache::Memcached::Fast ();
use URI::Escape::XS ();

use ProductOpener::Config qw/:all/;

use Log::Any qw($log);
use Log::Log4perl;
Log::Log4perl->init("$data_root/log.conf"); # Init log4perl from a config file.
use Log::Any::Adapter;
Log::Any::Adapter->set('Log4perl'); # Send all logs to Log::Log4perl

use ProductOpener::Lang qw/:all/;

use ProductOpener::Store qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::URL qw/:all/;
use ProductOpener::Version qw/:all/;
use ProductOpener::SiteQuality qw/:all/;

use Apache2::Const -compile => qw(OK);
use Apache2::Connection ();
use Apache2::RequestRec ();
use APR::Table ();


$Apache::Registry::NameWithVirtualHost = 0; 

sub My::ProxyRemoteAddr ($) {
  my $r = shift;

  # we'll only look at the X-Forwarded-For header if the requests
  # comes from our proxy at localhost
  return Apache2::Const::OK
      unless (($r->useragent_ip eq "127.0.0.1") 
	or 1	# all IPs
)
          and $r->headers_in->get('X-Forwarded-For');

  # Select last value in the chain -- original client's ip
  if (my ($ip) = $r->headers_in->get('X-Forwarded-For') =~ /([^,\s]+)$/) {
    $r->useragent_ip($ip);
  }

  return Apache2::Const::OK;
}

$log->info("product opener started", { version => $ProductOpener::Version::version });

open (*STDERR,'>',"/$data_root/logs/modperl_error_log") or die ($!);

print STDERR $log;

1;
