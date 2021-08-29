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

ProductOpener::Mail - sends emails to admin and producers. Moreover, replies to user queries.

=head1 SYNOPSIS

C<ProductOpener::Mail> is used to send emails from the contact address of the Open Food Facts to users, admin, and producers.

    use ProductOpener::Mail qw/:all/;

	$contact_email = 'contact@openbeautyfacts.org';
	$admin_email = 'stephane@openfoodfacts.org';
	$producers_email = 'producers@openfoodfacts.org';

=head1 DESCRIPTION

The module implements the sending of emails from the Open Food Facts contact email address to users, admin, and producers.
These emails can be used to reply to user queries, submit feedback, or to request access from admin and producers.

=cut

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

=head1 FUNCTIONS

=head2 send_email( USER_REF, SUBJECT, TEXT )

C<send_email()> sends email from the contact email of Open Food Facts to the email passed as an argument.

=head3 Arguments

The first argument is a hash reference. The other two arguments are scalar variables that consist of email subject and body.

=head4 Input keys: user data

The hash must contain values for the following keys:

- email -> user email
- name -> user name

=head3 Return Values

The function returns a 1 or 0 depending on the evaluation of the email sent or not.

If the function catches any error during evaluation it returns 1 indicating an error.
On the other hand, if there was no error, it returns 0 indicating that the email has been sent successfully.

=cut

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

=head1 FUNCTIONS

=head2 send_email_to_admin( SUBJECT, TEXT )

C<send_email_to_admin()> sends email from the contact email of Open Food Facts to the admin.

=head3 Arguments

Two scalar variables that contain the email subject and body are passed as an argument.

=head3 Return Values

The function returns a 1 or 0 depending on the evaluation of the email sent or not.

If the function catches any error during evaluation it returns 1 indicating an error.
On the other hand, if there was no error, it returns 0 indicating that the email has been sent successfully.

=cut

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

=head1 FUNCTIONS

=head2 send_email_to_producers_admin( SUBJECT, TEXT )

C<send_email_to_producers_admin()> sends email from the contact email of Open Food Facts to producers admin.

=head3 Arguments

Two scalar variables that contain the email subject and body are passed as an argument.

=head3 Return Values

The function returns a 1 or 0 depending on the evaluation of email sent or not.

If the function catches any error during evaluation it returns 1 indicating an error.
On the other hand, if there was no error, it returns 1 indicating that email has sent successfully.

=cut

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
			->html_body($text)
			->send;
	};

    return $@ ? 1 : 0;
}




1;
