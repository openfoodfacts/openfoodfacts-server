# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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

package ProductOpener::APIv2;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					&display_api_v2
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::APIv2::Products;
use ProductOpener::Store qw/:all/;

use Apache2::RequestRec;
use CGI qw/:cgi/;
use HAL::Tiny;
use HTTP::Accept;
use JSON::PP;
use Log::Any qw($log);

my %dispatch = (
	products => \&ProductOpener::APIv2::Products::display_api_v2
);
my $dispatch_ref = \%dispatch;

sub display_api_v2 {
	my $request_ref = shift;

	my $r = Apache2::RequestUtil->request();
	my $accept_header = HTTP::Accept->new($r->headers_in->{Accept});
	my $use_accept = $accept_header->match( qw(application/hal+json) );
	if ($use_accept eq '') {
		problem('about:blank', 'Not Acceptable', 406);
	}
	elsif (exists $dispatch_ref->{$request_ref->{api_resource}}) {
		my $sub = $dispatch_ref->{$request_ref->{api_resource}};
		my $hal = &$sub($request_ref, $r);
		if (not (defined $hal)) {
			problem('about:blank', 'Not Found', 404);
		}
		elsif ($use_accept eq 'application/hal+json') {
			hal_json($hal);
		}
		else {
			problem('about:blank', 'Not Acceptable', 406);
		}
	}
	else {
		problem('about:blank', 'Not Found', 404);
	}
}

sub problem {
	my $type = shift;
	my $title = shift;
	my $status = shift;
	my $detail = shift;

	my %response = ( type => $type, title => $title, status => $status );
	if (defined $detail) {
		$response{detail} = $detail;
	}

	problem_json(\%response);
}

sub problem_json {
	my $response_ref = shift;

	my $data = encode_json($response_ref);
	print header( -type => 'application/problem+json', -charset => 'utf-8' ) . $data;
}

sub hal_json {
	my $hal = shift;

	print header( -type => 'application/hal+json', -charset => 'utf-8' ) . $hal->as_json;
}

1;
