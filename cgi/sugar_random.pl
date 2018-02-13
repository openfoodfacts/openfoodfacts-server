#!/usr/bin/perl

use Modern::Perl '2012';
use utf8;

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:cgi :form escapeHTML/;
use Encode;
use JSON::PP;
use Storable qw(lock_store lock_nstore lock_retrieve);
use Apache2::RequestRec ();
use Apache2::Const ();

use List::Util qw(shuffle);
use Log::Any qw($log);

my $ids_ref = lock_retrieve("/home/sugar/data/products_ids.sto");
my @ids = @$ids_ref;

srand();

my @shuffle = shuffle(@ids);

my $id = pop(@shuffle);

$log->info("random ids sampled", { ids => scalar(@ids), id => $id }) if $log->is_info();
		my $r = shift;

		$r->headers_out->set(Location =>"/$id");
		$r->headers_out->set(Pragma => "no-cache");
		$r->headers_out->set("Cache-control" => "no-cache");
		$r->status(302);  
		return 302;

