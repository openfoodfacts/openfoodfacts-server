# Check for cyclic dependencies in ProductOpener modules
use 5.24.0;
use utf8;
use strict;
use warnings;
use Path::Tiny;

# files to inspect
my @po_modules = glob "../../lib/ProductOpener/*.pm";

# structure for storing direct dependencies ($package => [list of used packages])
my %uses;

# inspect ProductOpener modules, filling the direct dependency structure
foreach my $file (@po_modules) {
	my $source_code = path($file)->slurp;
	my ($package)   = $source_code =~ /^package\h+ProductOpener::([\w:]+)/m;
	my @used        = $source_code =~ /^use\h+ProductOpener::([\w:]+)/mg;
	$uses{$package} = \@used ;
}

# loop over modules to check for cycles
check_cycles($_, {}) foreach sort keys %uses;

# recursive function
sub check_cycles {
	my ($package, $seen, @path) = @_;

	# update the path of traversed modules
	push @path, $package;

	# check for cycles at this level
	if (my @circular_deps = grep {$seen->{$_}} $uses{$package}->@*) {
		warn sprintf "CYCLES IN %s ON %s\n", join(" => ", @path), join(" & ", @circular_deps);
		return 1; # has a cycle
	}

	# otherwise check one level deeper
	else {
		foreach my $used ($uses{$package}->@*) {
			my $has_cycle = check_cycles($used, {$package => 1, %$seen}, @path);
			return 1 if $has_cycle;
		}
		return 0; # does not have a cycle
	}
}

