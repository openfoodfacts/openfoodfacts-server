#!/usr/bin/perl -w

use strict;

use JSON::MaybeXS;

my $json = JSON->new->allow_nonref->canonical;

my $i = 0;
my $j = 0;

my %durations = (
	product_opener => {values=>[]}
);

while (<STDIN>) {
	my $l = $_;
	$i++;
	my $json_ref;
        eval {
	       $json_ref = decode_json($l);
	       1;
       }
       or do {
       print $@ . "\n";
       	next;
       };
	$j++;

	my $po_duration = $json_ref->{request_duration};

	foreach my $key (keys %$json_ref) {
		if ($key =~ /_duration$/) {
			my $duration = $`;
		if (not defined $durations{$duration}) {
			       $durations{$duration} = { values => [] };
		       }
			push @{$durations{$duration}{values}}, $json_ref->{$key};
			if ($duration ne "request") {
				$po_duration -= $json_ref->{$key};
			}
		}
	}
	push @{$durations{product_opener}{values}}, $po_duration;
}

print "$i lines\n";
print "$j parsed JSON\n";

foreach my $key (sort keys %durations) {
	my $sum = 0;
	my $n = 0;
	foreach my $value (@{$durations{$key}{values}}) {
		$sum += $value;
		$n++;
	}
	$durations{$key}{sum} = $sum;
	$durations{$key}{n} = $n;
	print "$key\t$n requests\taverage time: " . ($sum / $n) . "\ttotal time: $sum\n";
}

