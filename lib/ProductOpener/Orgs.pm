# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

ProductOpener::Orgs - manages organizations

=head1 SYNOPSIS

C<ProductOpener::Orgs> contains functions to create and edit organization profiles.

    use ProductOpener::Orgs qw/:all/;

	[..]

=head1 DESCRIPTION

[..]

=cut

package ProductOpener::Orgs;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
	
					&retrieve_org
					&store_org
					
					&org_name
					&org_url
					&org_link

					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Cache qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Tags qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use Encode;


use Log::Any qw($log);



sub retrieve_org($) {

	my $org_id = shift;

	$log->debug("retrieve_org", { org_id => $org_id } ) if $log->is_debug();
	
	not (defined $org_id) and return;

	my $org_ref = retrieve("$data_root/orgs/$org_id.sto");

	return $org_ref;
}


sub store_org($) {
	
	my $org_ref = shift;

	$log->debug("store_org", { org_ref => $org_ref } ) if $log->is_debug();
	
	defined $org_ref->{org_id} or die("Missing org_id");

	store("$data_root/orgs/" . $org_ref->{org_id} . ".sto", $org_ref);
}

sub org_name($) {
	
	my $org_ref = shift;
	
	if ((defined $org_ref->{name}) and ($org_ref->{name} ne "")) {
		return $org_ref->{name};
	}
	else {
		return $org_ref->{org_id};
	}
}

sub org_url($) {

	my $org_ref = shift;

	return canonicalize_tag_link("orgs", $org_ref->{org_id});
}

sub org_link($) {
	
	my $org_ref = shift;
	
	return "<a href=\"" . org_url($org_ref) . "\">" . org_name($org_ref) . "</a>";
}

1;
