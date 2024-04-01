#!/usr/bin/perl -w

use strict;

use Storable;

use ProductOpener::PerlStandards;

my $blocked_ips_file = "/srv/off/logs/blocked_ips.txt";

my %blocked_ips = ();

my $in;

if (open($in, "<", $blocked_ips_file)) {

	while (<$in>) {
		my $ip = $_;
		chomp($ip);
		print STDERR "loaded ip: $ip\n";
		$blocked_ips{$ip} = 1;
	}
}
close($in);

my %ip = ();

while (<STDIN>) {
	if ($_ =~ /(^\S+) /) {
		my $ip = $1;
		next if $ip !~ /^[0-9\.]+$/;
		$ip{$ip}++;
	}
}

foreach my $ip (sort {$ip{$a} <=> $ip{$b}} keys %ip) {
	next if exists $blocked_ips{$ip};
	if ($ip{$ip} > 100) {
		print STDERR "detected abusive $ip : $ip{$ip}\n";
		my $command1 = "iptables -A INPUT -s $ip -p tcp -m state --state NEW -m tcp --dport 80 -j DROP";
		my $command2 = "iptables -A INPUT -s $ip -p tcp -m state --state NEW -m tcp --dport 443 -j DROP";
		print STDERR $command1 . "\n";
		print STDERR $command2 . "\n";
		system($command1);
		system($command2);
		my $out;
		open($out, ">>", $blocked_ips_file);
		print $out $ip . "\n";
		close $out;
	}
}

