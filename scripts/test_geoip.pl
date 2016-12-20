#!/usr/bin/perl -w

use CGI qw/:all/;

use Modern::Perl '2015';

my $ip = remote_addr();

if (defined $ARGV[0]) {
	$ip = $ARGV[0];
}

        use Geo::IP;
        my $gi = Geo::IP->new(GEOIP_MEMORY_CACHE);
        # look up IP address '24.24.24.24'
        # returns undef if country is unallocated, or not defined in our database
        my $country = $gi->country_code_by_addr($ip);

print header();

print "IP: $ip - Country: $country\n";
