package Blogs::Mail;

######################################################################
#
#	Package	Mail
#
#	Author:	Stephane Gigandet
#	Date:	06/08/10
#
######################################################################

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					&send_email
					&send_email_to_admin
					&send_email_to_admin_from_user

					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;
use strict;
use utf8;

use Blogs::Store qw/:all/;
use Blogs::Config qw/:all/;
use Blogs::Lang qw/:all/;
use MIME::Lite;
use Encode;

sub send_email($$$)
{
	my $user_ref = shift;
	my $subject = shift;
	my $text = shift;
	
	my $email = $user_ref->{email};
	my $name = $user_ref->{name};
	
	$text =~ s/<NAME>/$name/g;

	my %msg = (
		'From' => encode("MIME-B", "\"" . lang("site_name") . "\" <$contact_email>"),
		'To' => encode("MIME-B", "\"$name\" <$email>"),
		'Encoding' => 'quoted-printable',
		'Subject' => encode("MIME-B", $subject),
		'Data' => encode("utf8", $text),
	);
	
	#$msg->attach(
	#Type => 'text/plain; charset=UTF-8',
	#Data => encode("utf8", $text),
	#);

		
	my $mime_email = MIME::Lite->new(%msg);
	$mime_email->attr('content-type.charset' => 'UTF-8');
	$mime_email->send;
}

sub send_email_to_admin($$)
{
	my $subject = shift;
	my $text = shift;

	my %msg = (
		'From' => encode("MIME-B","\"" . lang("site_name") . "\" <$contact_email>"),
		'To' => encode("MIME-B","\"" . lang("site_name") . "\" <$admin_email>"),
		'Encoding' => 'quoted-printable',
		'Subject' => encode("MIME-B",$subject),
		'Data' =>  encode("utf8", $text),
	);
		
	my $mime_email = MIME::Lite->new(%msg);
	$mime_email->attr('content-type.charset' => 'UTF-8');
	$mime_email->send;
	
	print STDERR "sent email to admin: \n" . $mime_email->as_string . "\n";
}

sub send_email_to_admin_from_user($$$) # useful so that the admin can do a reply to
{
	my $user_ref = shift;
	my $subject = shift;
	my $text = shift;
	
	my $email = $user_ref->{email};
	my $name = $user_ref->{name};
	
	$text =~ s/<NAME>/$name/g;

	my %msg = (
		'To' => encode("MIME-B","\"" . lang("site_name") . "\" <$contact_email>"),
		'From' => encode("MIME-B","\"$name\" <$email>"),
		'Reply-to' => encode("MIME-B","\"$name\" <$email>"),
		'Encoding' => 'quoted-printable',
		'Subject' => encode("MIME-B",$subject),
		'Data' => encode("utf8", $text),
	);
		
	my $mime_email = MIME::Lite->new(%msg);
	$mime_email->attr('content-type.charset' => 'UTF-8');
	$mime_email->send;
}



1;
