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

package ProductOpener::Mail;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&send_email
		&send_email_to_admin
		&send_email_to_producers_admin

		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Lang qw/:all/;
use Email::Stuffer;
use Log::Any qw($log);

sub send_email($$$)
{
	my $user_ref = shift;
	my $subject = shift;
	my $text = shift;
	
	my $email = $user_ref->{email};
	my $name = $user_ref->{name};
	
	$text =~ s/<NAME>/$name/g;
 
	eval {
		Email::Stuffer
			->from( lang("site_name") . " <$contact_email>" )
			->to( $name . " <$email>" )
			->subject($subject)
			->text_body($text)
			->send;
	};

    return $@ ? 1 : 0;
    
}

sub send_email_to_admin($$)
{
	my $subject = shift;
	my $text = shift;

	eval {
		Email::Stuffer
			->from( lang("site_name") . " <$contact_email>" )
			->to( lang("site_name") . " <$admin_email>" )
			->subject($subject)
			->text_body($text)
			->send;
	};

    return $@ ? 1 : 0;
}

sub send_email_to_producers_admin($$)
{
	my $subject = shift;
	my $text = shift;

	eval {
		Email::Stuffer
			->from( lang("site_name") . " <$contact_email>" )
			->to( lang("site_name") . " <$producers_email>" )
			->subject($subject)
			->text_body($text)
			->send;
	};

    return $@ ? 1 : 0;
}




1;
