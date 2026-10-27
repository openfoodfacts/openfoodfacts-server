#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::HTTP qw/ip_is_not_public resolve_host_addresses url_is_fetchable/;

# A url that is fetched by the import feature (see download_image() in Import.pm) must not be able
# to reach the services that are only reachable from inside our network. These tests use addresses
# and host names written literally, so that they do not need a DNS resolution or a network access.

# ip_is_not_public(): addresses that are not globally routable

foreach my $ip_address (
	"0.0.0.0", "10.0.0.1", "10.255.255.254",    # "this" network and RFC1918
	"100.64.0.1",    # carrier grade NAT
	"127.0.0.1", "127.1.2.3",    # loopback
	"169.254.0.1", "169.254.169.254",    # link-local, including the metadata service
	"172.16.0.1", "172.31.255.254",    # RFC1918
	"192.0.0.1", "192.0.2.5",    # IETF protocol assignments and documentation
	"192.88.99.1",    # 6to4 relay anycast
	"192.168.0.1", "192.168.255.254",    # RFC1918
	"198.18.0.1",    # benchmarking
	"198.51.100.5", "203.0.113.9",    # documentation
	"224.0.0.1", "239.255.255.255",    # multicast
	"240.0.0.1", "255.255.255.255",    # reserved
	"::", "::1",    # unspecified and loopback
	"::ffff:127.0.0.1", "::ffff:169.254.169.254",    # IPv4-mapped
	"::7f00:1",    # IPv4-compatible
	"100::",    # discard-only
	"2001:db8::1",    # documentation
	"fc00::1", "fd12:3456::1",    # unique local
	"fe80::1", "fe80::1%eth0",    # link-local, with and without a scope id
	"fec0::1",    # site-local
	"ff02::1",    # multicast
	)
{
	is(ip_is_not_public($ip_address), 1, "$ip_address is not globally routable");
}

# ip_is_not_public(): globally routable addresses, and addresses we cannot parse

foreach my $ip_address (
	"8.8.8.8", "1.1.1.1", "172.32.0.1", "100.128.0.1",
	"223.255.255.255", "2001:4860:4860::8888", "2a00:1450:4001:80f::200e"
	)
{
	is(ip_is_not_public($ip_address), 0, "$ip_address is globally routable");
}

foreach my $not_an_address (undef, "", "localhost", "drive.google.com", "10.0.0", "10.0.0.1.2", "300.1.1.1") {
	is(ip_is_not_public($not_an_address), 1,
		"'" . ($not_an_address // "undef") . "' is not an address we can classify");
}

# resolve_host_addresses(): an address written in the url is not resolved, a host that does not
# resolve gives an empty list

is(resolve_host_addresses("8.8.8.8"), ["8.8.8.8"], "an IPv4 address is returned as it is");
is(resolve_host_addresses("::1"), ["::1"], "an IPv6 address is returned as it is");
is(resolve_host_addresses("host.invalid"), [], "a host that does not resolve gives no address");
is(resolve_host_addresses(""), [], "an empty host gives no address");
is(resolve_host_addresses(undef), [], "an undefined host gives no address");

# localhost is in /etc/hosts, so this does not need a DNS resolution
my $localhost_addresses_ref = resolve_host_addresses("localhost");
ok(scalar @{$localhost_addresses_ref} > 0, "localhost resolves");
foreach my $ip_address (@{$localhost_addresses_ref}) {
	is(ip_is_not_public($ip_address), 1, "localhost resolves to a loopback address ($ip_address)");
}

# url_is_fetchable(): scheme, host and address checks

foreach my $url (
	"http://127.0.0.1/x.png", "http://127.0.0.1:8881/x.png", "https://127.0.0.1/x.png",
	"http://localhost/x.png", "http://[::1]/x.png", "http://[::ffff:127.0.0.1]/x.png",
	"http://169.254.169.254/latest/meta-data/", "http://169.254.169.254:80/latest/meta-data/",
	"http://10.0.0.5/x.png", "http://192.168.1.1/x.png", "http://172.16.0.1/x.png",
	"http://100.64.0.1/x.png", "http://[fe80::1]/x.png", "http://[fd00::1]/x.png",
	# other schemes are not followed
	"file:///etc/passwd", "ftp://8.8.8.8/x.png", "gopher://8.8.8.8/x.png", "dict://8.8.8.8:11211",
	# no host, or a host that does not resolve
	"http://", "https://host.invalid/x.png", "//8.8.8.8/x.png", "", undef,
	)
{
	is(url_is_fetchable($url), 0, "'" . ($url // "undef") . "' cannot be fetched");
}

foreach my $url ("http://8.8.8.8/x.png", "https://8.8.8.8/x.png", "http://[2001:4860:4860::8888]/x.png") {
	is(url_is_fetchable($url), 1, "'$url' can be fetched");
}

# A host that resolves to a non globally routable address can be allowlisted by the operator,
# e.g. a supplier serving images from a private network

is(url_is_fetchable("http://192.168.1.1/x.png", []), 0, "the allowlist is empty by default");
is(url_is_fetchable("http://192.168.1.1/x.png", ["images.example.com"]), 0, "another host is not allowlisted");
is(url_is_fetchable("http://192.168.1.1/x.png", ["images.example.com", "192.168.1.1"]),
	1, "the host is fetched when it is allowlisted");
is(url_is_fetchable("http://192.168.1.1/x.png", ["IMAGES.EXAMPLE.COM", "192.168.1.1"]),
	1, "an allowlisted host is matched without regard to case");
is(url_is_fetchable("http://192.168.1.1/x.png", ["192.168.1.10"]),
	0, "an allowlisted host does not match another address of the same range");
is(url_is_fetchable("file:///etc/passwd", ["192.168.1.1"]),
	0, "an allowlisted host is still not fetched over another scheme");

done_testing();
