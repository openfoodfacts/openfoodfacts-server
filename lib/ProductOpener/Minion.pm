# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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

ProductOpener::Minion - functions to integrate with minion

=head1 DESCRIPTION

C<ProductOpener::Minion> is handling pushing info to Redis
to communicate updates to all services, including search-a-licious,
as well as receiving updates from other services like Keycloak.

=cut

package ProductOpener::Minion;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&get_minion
		&queue_job
		&write_minion_log

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/%BASE_DIRS/;

use Minion;

# Minion backend
my $minion;

=head2 get_minion()

Function to get the backend minion

=head3 Arguments

None

=head3 Return values

The backend minion $minion

=cut

sub get_minion() {
	if (not defined $minion) {
		if (not defined $server_options{minion_backend}) {
			print STDERR "No Minion backend configured in lib/ProductOpener/Config2.pm\n";
		}
		else {
			print STDERR "Initializing Minion backend configured in lib/ProductOpener/Config2.pm\n";
			$minion = Minion->new(%{$server_options{minion_backend}});
		}
	}
	return $minion;
}

sub queue_job {    ## no critic (Subroutines::RequireArgUnpacking)
	my $create_time = time();
	my $job_id = get_minion()->enqueue(@_);

	# Can uncomment this for debugging during integration testing but need to comment out again for normal use
	# my $job = get_minion()->job($job_id);
	# write_minion_log("Job $job_id for " . $job->task . " created at " . localtime($create_time) . " has created time of " . localtime($job->info->{created}));

	return $job_id;
}

sub write_minion_log($message) {
	open(my $log, ">>", "$BASE_DIRS{LOGS}/minion.log");
	print $log "[" . localtime() . "] $message\n";
	close($log);
	print STDERR "[" . localtime() . "] $message\n";

	return;
}
1;
