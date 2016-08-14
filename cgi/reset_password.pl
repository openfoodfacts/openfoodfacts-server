#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use strict;
use utf8;

use Blogs::Config qw/:all/;
use Blogs::Store qw/:all/;
use Blogs::Index qw/:all/;
use Blogs::Display qw/:all/;
use Blogs::Images qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Mail qw/:all/;
use Blogs::Lang qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Encode;

Blogs::Display::init();

my $type = param('type') || 'send_email';
my $action = param('action') || 'display';

my $id = param('userid_or_email');

print STDERR "password.pl - type: $type - action: $action - userid_or_email: $id\n";

my @errors = ();

my $email_ref = undef;
my $userid = undef;

my $html = '';

if (defined $User_id) {
	display_error($Lang{error_reset_already_connected}{$lang}, undef);
}

if ($action eq 'process') {

	if ($type eq 'send_email') {

	# Is it an email?
	
		if ($id =~ /\@/) {
			my $emails_ref = retrieve("$data_root/users_emails.sto");
			if (not defined $emails_ref->{$id}) {
				push @errors, $Lang{error_reset_unknown_email}{$lang};
			}
			else {
				$email_ref = $emails_ref->{$id};
			}
		}
		else {
			$id = get_fileid($id);
			if (! -e "$data_root/users/$id.sto") {
				push @errors, $Lang{error_reset_unknown_id}{$lang};
			}
			else {
				$userid = $id;
			}
		}
	
	}
	elsif (($type eq 'reset') and (defined param('resetid'))) {
	
		if (length(param('password')) < 6) {
			push @errors, $Lang{error_invalid_password}{$lang};
		}
		
		if (param('password') ne param('confirm_password')) {
			push @errors, $Lang{error_different_passwords}{$lang};
		}	
	
	}
	else {
		display_error("Adresse invalide", 404);
	}

	
	if ($#errors >= 0) {
		$action = 'display';
	}	
}


if ($action eq 'display') {


	$html .= $Lang{"reset_password_${type}_msg"}{$lang};
	
	if ($#errors >= 0) {
		$html .= "<p><b>$Lang{correct_the_following_errors}{$lang}</b></p><ul>\n";
		foreach my $error (@errors) {
			$html .= "<li class=\"error\">$error</li>\n";
		}
		$html .= "</ul>\n";
	}
	
	$html .= start_form();
	
	if ($type eq 'send_email') {
	
		$html .= "\n$Lang{userid_or_email}{$lang}"
		. textfield(-name=>'userid_or_email', -value=>'', -size=>40, -override=>1) . "<br>";
	}
	elsif ($type eq 'reset') {
		$html .= "<table>"
		. "\n<tr><td>$Lang{password}{$lang}</td><td>"
		. password_field(-name=>'password', -value=>'', -override=>1) . "</td></tr>"
		. "\n<tr><td>$Lang{password_confirm}{$lang}</td><td>"
		. password_field(-name=>'confirm_password', -value=>'', -override=>1) . "</td></tr>"
		. "</table>"
		. hidden(-name=>'resetid', -value=>param('resetid'), -override=>1)
		. hidden(-name=>'token', -value=>param('token'), -override=>1)
	}
	

	$html .= "\n"
	. hidden(-name=>'action', -value=>'process', -override=>1)
	. hidden(-name=>'type', -value=>$type, -override=>1)
	. submit()
	. end_form();

}
elsif ($action eq 'process') {

if ($type eq 'send_email') {

	my @userids = ();
	if (defined $email_ref) {
		@userids = @{$email_ref};
	}
	elsif (defined $userid) {
		@userids = ($userid);
	}
	
	my $i = 0;
	
	foreach my $userid (@userids) {
	
		my $user_ref = retrieve("$data_root/users/$userid.sto");
		if (defined $user_ref) {
		
			$user_ref->{token_t} = time();
			$user_ref->{token} = generate_token(64);
			$user_ref->{token_ip} = remote_addr();
			
			store("$data_root/users/$userid.sto", $user_ref);
			
			my $url = "http://$subdomain.$server_domain/cgi/reset_password.pl?type=reset&resetid=$userid&token=" . $user_ref->{token};
	
			my $email = lang("reset_password_email_body");
			$email =~ s/<USERID>/$userid/g;
			$email =~ s/<RESET_URL>/$url/g;
			send_email($user_ref, lang("reset_password_email_subject"), $email);
			
			$i++;
		}
	}
	
	if ($i > 0) {
		$html .= $Lang{reset_password_send_email}{$lang};
	}

}
elsif ($type eq 'reset') {
	
	my $userid = get_fileid(param('resetid'));
	my $user_ref = retrieve("$data_root/users/$userid.sto");
	if (defined $user_ref) {
	
		if ((param('token') eq $user_ref->{token}) and (time() < ($user_ref->{token_t} + 86400*3))) {
	
			$user_ref->{encrypted_password} = unix_md5_crypt( encode_utf8 (decode utf8=>param('password')), gensalt(8) );
			
			delete $user_ref->{token};
			
			store("$data_root/users/$userid.sto", $user_ref);

			$html .= $Lang{reset_password_reset}{$lang};
		}
		else {
			display_error($Lang{error_reset_invalid_token}{$lang}, undef);
		}
	}
}


}


display_new( {

	title=> $Lang{'reset_password'}{$lang},
	content_ref=>\$html,
#	full_width=>1,
});

