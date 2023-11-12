# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&send_email
		&send_html_email
		&send_email_to_admin
		&send_email_to_producers_admin
		&get_html_email_content

		$LOG_EMAIL_START
		$LOG_EMAIL_END

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Lang qw/:all/;
use Email::Stuffer;
use Log::Any qw($log);

=head1 CONSTANTS

=head2 LOG_EMAIL_START
Text used before logging an email
=cut

$LOG_EMAIL_START = "---- EMAIL START ----\n";

=head2 LOG_EMAIL_END
Text used after logging an email
=cut

$LOG_EMAIL_END = "\n---- EMAIL END ----\n";

=head1 FUNCTIONS

=head2 _send_email($mail)

Secure way to send an email (private method)

Depending on $log_emails configuration it might just log the email instead of sending it.

Errors are logged.

=head3 Arguments

=head4 Email::Stuffer object $mail

The email should be ready to be send

=cut

sub _send_email ($mail) {
	my $error;
	if (!$log_emails) {
		# really send email
		local $@;
		eval {$mail->send;};
		$error = $@;
	}
	else {
		# just log mail
		my $text = $mail->as_string();
		# replace \r\n by \n
		$text =~ s/\r\n/\n/g;
		$log->info("Email that would have been sent:\n\n$LOG_EMAIL_START$text$LOG_EMAIL_END");
	}
	if ($error) {
		# log error, do not reveal email content
		# /s is to threat \n as normal chars, and we evaluate in list context to get matched group
		# not that mail use \r\n as line ending
		my ($summary,) = ($mail->as_string() =~ /(From:.*\nSubject:[^\r\n]+)\r\n/s);
		$summary =~ s/\r\n/ - /g;
		$log->error("Error sending mail $summary: $error");
	}

	return $error ? 1 : 0;
}

=head2 send_email( USER_REF, SUBJECT, TEXT )

C<send_email()> sends a plain text email from the contact email of Open Food Facts to the email passed as an argument.

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

sub send_email ($user_ref, $subject, $text) {

	my $email = $user_ref->{email};
	my $name = $user_ref->{name};

	$text =~ s/<NAME>/$name/g;
	my $mail = Email::Stuffer->from(lang("site_name") . " <$contact_email>")->to($name . " <$email>")->subject($subject)
		->text_body($text);
	return _send_email($mail);
}

=head2 send_html_email( USER_REF, SUBJECT, HTML_CONTENT )

C<send_html_email()> sends an HTML email from the contact email of Open Food Facts to the email passed as an argument.

=head3 Arguments

The first argument is a hash reference. The other two arguments are scalar variables that consist of email subject and HTML content.

=head4 Input keys: user data

The hash must contain values for the following keys:

- email -> user email
- name -> user name

=head3 Return Values

The function returns a 1 or 0 depending on the evaluation of the email sent or not.

If the function catches any error during evaluation it returns 1 indicating an error.
On the other hand, if there was no error, it returns 0 indicating that the email has been sent successfully.

=cut

sub send_html_email ($user_ref, $subject, $html_content) {
	my $email = $user_ref->{email};
	my $name = $user_ref->{name};

	my $mail = Email::Stuffer->from(lang("site_name") . " <$contact_email>")->to($name . " <$email>")->subject($subject)
		->html_body($html_content);
	return _send_email($mail);
}

=head2 get_html_email_content ($filename, $lang )

Fetch the HTML email content in $DATA_ROOT/lang/emails. If a translation is available
for the requested language, we provide the translated version otherwise English is the default.


=head3 Arguments

=head4 $filename

The HTML file name (ex: user_welcome.html)

=head4 $lang

The 2-letter language code

=head3 Return Values

The HTML string or undef if the file does not exists or is not readable.

=cut

sub get_html_email_content ($filename, $lang) {
	# if an email does not exist in the local language, use the English version
	my $file = "$data_root/lang/$lang/emails/$filename";

	if (!-e $file) {
		$file = "$data_root/lang/en/emails/$filename";
	}

	open(my $IN, "<:encoding(UTF-8)", $file) or $log->error("Can't open $file for reading");
	return unless $IN;
	my $html = join('', (<$IN>));
	close($IN);
	return $html;
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

sub send_email_to_admin ($subject, $text) {
	my $mail = Email::Stuffer->from(lang("site_name") . " <$contact_email>")->to(lang("site_name") . " <$admin_email>")
		->subject($subject)->text_body($text);

	return _send_email($mail);
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

sub send_email_to_producers_admin ($subject, $text) {
	my $mail
		= Email::Stuffer->from(lang("site_name") . " <$contact_email>")->to(lang("site_name") . " <$producers_email>")
		->subject($subject)->text_body($text)->html_body($text);

	return _send_email($mail);
}

1;
