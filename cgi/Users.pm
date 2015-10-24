# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2015 Association Open Food Facts
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


package Blogs::Users;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					%User
					$User_id
					%Visitor
					$Visitor_id
					$Facebook_id
					
					$cookie
					
					&display_user_form
					&check_user_form
					&process_user_form
					
					&display_login_form
										
					&init_user
					&save_user
					
					&userpath
					&create_user
					&gensalt
					
					&check_session

					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;
use strict;
use utf8;

use Blogs::Store qw/:all/;
use Blogs::Config qw/:all/;
use Blogs::Mail qw/:all/;
use Blogs::Lang qw/:all/;
use Blogs::Cache qw/:all/;
use Blogs::Display qw/:all/;


use CGI qw/:cgi :form escapeHTML/;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Encode;

use Crypt::PasswdMD5 qw(unix_md5_crypt);

my @salt = ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' );

# uses global @salt to construct salt string of requested length
sub gensalt {
  my $count = shift;

  my $salt;
  for (1..$count) {
    $salt .= (@salt)[rand @salt];
  }

  return $salt;
}


sub userpath($) {

	my $file = shift;
	$file =~ s/^(...)(.)/$1\/$2/;
	return $file;
}


sub create_user($) {

	my $user_ref = shift;
	my $name_id = get_fileid($user_ref->{name});
	
	if (length($name_id) > 3) {
	
		my $i = 1;
		my $name_id2 = $name_id;
		
		while (-e "$data_root/users/$name_id2.sto") {
			$name_id2 = $name_id . "-" . ++$i;
		}
		
		$user_ref->{userid} = $name_id2;
		
		# TODO
		# Assign a random password
		# Send welcome e-mail + password
	
		print STDERR "Users.pm - create_user - creating user $name_id2\n";
		store("$data_root/users/$name_id2.sto", $user_ref);
	}	
}


sub display_user_form($$) {

	my $user_ref = shift;
	my $scripts_ref = shift;
	
	my $type = param('type');	

	my $html = '';
	
	$html .= "\n<tr><td>$Lang{name}{$lang}</td><td>"	
	. textfield(-id=>'name', -name=>'name', -value=>$user_ref->{name}, -size=>80, -override=>1) . "</td></tr>"
#	. "\n<tr><td>$Lang{sex}{$lang}</td><td>" 
#	. radio_group(-name=>'sex', -values=>['f','m'], -labels=>{'f'=>$Lang{female}{$lang},'m'=>$Lang{male}{$lang}}, -default=>$user_ref->{sex}, -override=>1) . "</td></tr>"
	. "\n<tr><td>$Lang{email}{$lang}</td><td>" 
	. textfield(-name=>'email', -value=>$user_ref->{email}, -size=>80, -override=>1) . "</td></tr>"
	. "\n<tr><td>$Lang{username}{$lang}<br/><span class=\"info\">" . (($type eq 'edit') ? '': $Lang{username_info}{$lang}) . "</span></td><td>"	
	. (($type eq 'edit') ? $user_ref->{userid} : 
		( textfield(-id=>'userid', -name=>'userid', -value=>$user_ref->{userid}, -size=>40, -onkeyup=>"update_userid(this.value)")
			. "<br /><span id=\"useridok\" style=\"font-size:10px;\">&nbsp;</span>")) . "</td></tr>"
	. "\n<tr><td>$Lang{password}{$lang}</td><td>"
	. password_field(-name=>'password', -value=>'', -override=>1) . "</td></tr>"
	. "\n<tr><td>$Lang{password_confirm}{$lang}</td><td>"
	. password_field(-name=>'confirm_password', -value=>'', -override=>1) . "</td></tr>"
	

	;
	
	$$scripts_ref .= <<SCRIPT
<script type="text/javascript">
function update_userid(value) {

var userid = value.toLowerCase();
userid = userid.replace(new RegExp(" ", 'g'),"-");
userid = userid.replace(new RegExp("[àáâãäå]", 'g'),"a");
userid = userid.replace(new RegExp("æ", 'g'),"ae");
userid = userid.replace(new RegExp("ç", 'g'),"c");
userid = userid.replace(new RegExp("[èéêë]", 'g'),"e");
userid = userid.replace(new RegExp("[ìíîï]", 'g'),"i");
userid = userid.replace(new RegExp("ñ", 'g'),"n");                            
userid = userid.replace(new RegExp("[òóôõö]", 'g'),"o");
userid = userid.replace(new RegExp("œ", 'g'),"oe");
userid = userid.replace(new RegExp("[ùúûü]", 'g'),"u");
userid = userid.replace(new RegExp("[ýÿ]", 'g'),"y");
userid = userid.replace(new RegExp("[^a-zA-Z0-9-]", 'g'),"-");
userid = userid.replace(new RegExp("-+", 'g'),"-");
userid = userid.replace(new RegExp("^-"),"");
\$('#userid').val(userid);

\$.get("/cgi/check_id.pl", { id: userid, type: 'user' },
   function(data){
	 \$('#useridok').html(data);
   });
   
}		
</script>
SCRIPT
;
	
	return $html;
}


sub display_user_form_optional($) {

	my $user_ref = shift;
	
	my $type = param('type') || 'add';	

	my $html = '';
	
	# $html .= "\n<tr><td>$Lang{twitter}{$lang}</td><td>"
	# . textfield(-id=>'twitter', -name=>'twitter', -value=>$user_ref->{name}, -size=>80, -override=>1) . "</td></tr>";
	
	if (($type eq 'add') or ($type eq 'suggest')) {
	
		$html .=
		"\n<tr><td colspan=\"2\">" . checkbox(-name=>'newsletter', -label=>lang("newsletter_description"), -checked=>'on') . "<br />
		$Lang{unsubscribe_info}{$lang}</td></tr>";
	}
	
	return $html;
}


sub check_user_form($$) {

	my $user_ref = shift;
	my $errors_ref = shift;
	
	my $type = param('type');
	
	$user_ref->{userid} = remove_tags_and_quote(param('userid'));
	$user_ref->{name} = remove_tags_and_quote(decode utf8=>param('name'));
#	$user_ref->{sex} = param('sex');
	
	if ($user_ref->{email} ne decode utf8=>param('email')) {
		
		# check that the email is not already used
		my $emails_ref = retrieve("$data_root/users_emails.sto");
		if (defined $emails_ref->{decode utf8=>param('email')}) {
			push @$errors_ref, $Lang{error_email_already_in_use}{$lang};
		}
	
		$user_ref->{email} = remove_tags_and_quote(decode utf8=>param('email'));
		
	}
	
	if (defined param('twitter')) {
		$user_ref->{twitter} = remove_tags_and_quote(decode utf8=>param('twitter'));
		$user_ref->{twitter} =~ s/^http:\/\/twitter.com\///;
		$user_ref->{twitter} =~ s/^\@//;
	}
	
	if (($type eq 'add') or ($type eq 'suggest')) {
		$user_ref->{newsletter} = remove_tags_and_quote(param('newsletter'));
		$user_ref->{discussion} = remove_tags_and_quote(param('discussion'));
		$user_ref->{ip} = remote_addr();
		$user_ref->{initial_lc} = $lc;
		$user_ref->{initial_cc} = $cc;
		
	}
	
	defined $user_ref->{registered_t} or $user_ref->{registered_t} = time();
	
	# Check input parameters, redisplay if necessary


	if (length($user_ref->{name}) < 2) {
		push @$errors_ref, $Lang{error_no_name}{$lang};
	}
	
	if ($user_ref->{email} !~ /^[\w.-]+\@([\w.-]+\.)+\w+$/) {
		push @$errors_ref, $Lang{error_invalid_email}{$lang};
	}
	
	if (($type eq 'add') or ($type eq 'suggest')) {
	
		my $userid = get_fileid($user_ref->{userid});
	
		if (length($user_ref->{userid}) < 2) {
			push @$errors_ref, $Lang{error_no_username}{$lang};
		}
		elsif (-e "$data_root/users/$userid.sto") {
			push @$errors_ref, $Lang{error_username_not_available}{$lang};
		}
		elsif ($user_ref->{userid} !~ /^[a-z0-9]+[a-z0-9\-]*[a-z0-9]+$/) {
			push @$errors_ref, $Lang{error_invalid_username}{$lang};
		}
		
		if (length(decode utf8=>param('password')) < 6) {
			push @$errors_ref, $Lang{error_invalid_password}{$lang};
		}
	}
	
	if (param('password') ne param('confirm_password')) {
		push @$errors_ref, $Lang{error_different_passwords}{$lang};
	}
	elsif (param('password') ne '') {
		$user_ref->{encrypted_password} = unix_md5_crypt( encode_utf8(decode utf8=>param('password')), gensalt(8) );
	}
 
}




sub process_user_form($) {

	my $user_ref = shift;
	my $userid = $user_ref->{userid};
    my $error = 0;

	store("$data_root/users/$userid.sto", $user_ref);
	
	# Update email
	my $emails_ref = retrieve("$data_root/users_emails.sto");
	my $email = $user_ref->{email};
	
	if ((defined $email) and ($email =~/\@/)) {
		$emails_ref->{$email} = [$userid];
	}	
	store("$data_root/users_emails.sto", $emails_ref);

	
	if ((param('type') eq 'add') or (param('type') eq 'suggest')) {
		my $email = lang("add_user_email_body");
		$email =~ s/<USERID>/$userid/g;
		# $email =~ s/<PASSWORD>/$user_ref->{password}/g;
		$error = send_email($user_ref,lang("add_user_email_subject"), $email);
		
		my $email = <<EMAIL
		
Bonjour,

Inscription d'un utilisateur :	
		
name: $user_ref->{name}
email: $user_ref->{email}
twitter: http://twitter.com/$user_ref->{twitter}
newsletter: $user_ref->{newsletter}
discussion: $user_ref->{discussion}
lc: $user_ref->{initial_lc}
cc: $user_ref->{initial_cc}

EMAIL
;	
		$error += send_email_to_admin("Inscription de $userid", $email);
	}
    return $error;
}

sub display_login_form() {
}


sub init_user()
{
	my $debug = 1;
	my $user_id = undef ;
	my $user_ref = undef;
	my $cookie_name = 'session';
	
	$cookie = undef;

	$Visitor_id = undef;
	$Facebook_id = undef;
	$User_id = undef;

	# Remove persistent cookie if user is logging out
	if ((defined param('length')) and (param('length') eq 'logout')) {
		$debug and print STDERR "Blogs::Users::init_user - logout\n" ;
		my $session = {} ;
		$cookie = cookie (-name=>$cookie_name, -expires=>'-1d',-value=>$session, -path=>'/', -domain=>".$domain") ;
	}

	# Retrieve user_id and password from form parameters
	elsif ( (defined param('user_id')) and (param('user_id') ne '') and
                       ( ( (defined param('password')) and (param('password') ne ''))
                         ) ) {
		$user_id = remove_tags_and_quote(param('user_id')) ;
		
		if ($user_id =~ /\@/) {
			my $emails_ref = retrieve("$data_root/users_emails.sto");
			print STDERR "Users.pm - init_user - got email: $user_id\n";
			if (not defined $emails_ref->{$user_id}) {
				$user_id = undef;
			}
			else {
				my @userids = @{$emails_ref->{$user_id}};
				$user_id = $userids[0];
			}
			print STDERR "Users.pm - init_user - corresponding user_id: $user_id\n";
			
		}		

		$debug and print STDERR "Blogs::Users::init_user - defined user_id \n" ;
		my $session = undef ;

		# If the user exists
		if (defined $user_id) {
           my  $user_file = "$data_root/users/" . get_fileid($user_id) . ".sto";
		
			if (-e $user_file) {
			$user_ref = retrieve($user_file) ;
			$user_id = $user_ref->{'userid'} ;

			# We don't have the right password
			if ($user_ref->{'encrypted_password'} ne unix_md5_crypt(encode_utf8(decode utf8=>param('password')), $user_ref->{'encrypted_password'} ))
			{
			    $user_id = undef ;
			    $debug and print STDERR "Blogs::Users::init_user - bad password\n" ;
				$debug and print STDERR "Blogs::Users::init_user - bad password - " . $user_ref->{'encrypted_password'} . ' != ' . unix_md5_crypt((decode utf8=>param('password')), $user_ref->{'encrypted_password'} ) . "\n" ;
				$debug and print STDERR "Blogs::Users::init_user - bad password - " . $user_ref->{'encrypted_password'} . ' != ' . unix_md5_crypt((decode utf8=>param('password')), $user_ref->{'encrypted_password'} ) . "\n" ;
				$debug and print STDERR "Blogs::Users::init_user - bad password - " . $user_ref->{'encrypted_password'} . ' != ' . unix_md5_crypt((decode utf8=>param('password')), $user_ref->{'encrypted_password'} ) . "\n" ;


			    # Trigger an error
			    return ($Lang{error_bad_login_password}{$lang}) ;
			}
			# We have the right login/password
			elsif (not defined param('no_log'))    # no need to store sessions for internal requests
			{
				$debug and print STDERR "Blogs::Users::init_user - we have the right password for $user_id\n" ;
			
			    # Maximum of sessions for a given user
			    my $max_session = 10 ;

			    # Generate a session number, store the cookie
			    my $user_session = int(rand() * 10000000000);

			    # Check if we need to delete the oldest session
			    # delete $user_ref->{'user_session'};
			    if ((defined ($user_ref->{'user_sessions'})) and
				((scalar keys %{$user_ref->{'user_sessions'}}) >= $max_session)) {
					my %user_session_stored = %{$user_ref->{'user_sessions'}} ;

					# Find the older session and remove it
					my @session_by_time = sort { $user_session_stored{$a}{'time'} <=>
								 $user_session_stored{$b}{'time'} } (keys %user_session_stored);
								 
			        while (($#session_by_time + 1)> $max_session)
			        {
						my $oldest_session = shift @session_by_time;
						delete $user_ref->{'user_sessions'}{$oldest_session};
			        }
			    }
				
				if (not defined $user_ref->{'user_sessions'}) {
					$user_ref->{'user_sessions'} = {};
				}
				$user_ref->{'user_sessions'}{$user_session} = {};

			    # Store the ip and time corresponding to the given session
			    $user_ref->{'user_sessions'}{$user_session}{'ip'} = remote_addr();
			    $user_ref->{'user_sessions'}{$user_session}{'time'} = time();
			    $session = { 'user_id'=>$user_id, 'user_session'=>$user_session };

			    store("$user_file", $user_ref);


			    $debug and print STDERR "Blogs::Users::init_user - user_id : $session->{'user_id'} ; user_session : $session->{'user_sessions'}\n" ;
			    # Check if the user is logging in

			    my $length = 0;

			    if ((defined param('length')) and (param('length') > 0))
			    {
			    	$length = param('length');
			    }
			    elsif ((defined param('remember_me')) and (param('remember_me') eq 'on'))
			    {
			    	$length = 31536000 * 10;
			    }

			    if ($length > 0)
			    {
				# Set a persistent cookie
				$debug and print STDERR "Blogs::Users::init_user -  persistent cookie\n" ;
				$cookie = cookie (-name=>$cookie_name, -value=>$session, -path=>'/', -domain=>".$domain",
						   -expires=>'+' . $length . 's') ;

			    }
			    else
			    {
				# Set a session cookie
				$debug and print STDERR "Blogs::Users::init_user - session cookie\n" ;

				$cookie = cookie (-name=>$cookie_name, -value=>$session, -path=>'/', -domain=>".$domain") ;
			    }
			}
		    }
		    else
		    {
			$user_id = undef ;
			$debug and print STDERR "Blogs::Users::init_user - bad user\n" ;
			# Trigger an error
			return ($Lang{error_bad_login_password}{$lang}) ;
		    }
		}
	    }

	# Retrieve user_id and password from cookie
	elsif (defined cookie($cookie_name))
	{
	    my %session = cookie($cookie_name) ;
	    $debug and print STDERR "Blogs::Users::init_user - cookie session : $session{'user_sessions'} ; user_id : $session{'user_id'}\n" ;
	    my $user_session = $session{'user_session'} ;
	    $user_id = $session{'user_id'};
	    $debug and print STDERR "Blogs::Users::init_user - cookie found ! user_id: $user_id \n" ;
	    if (defined $user_id)
	    {
			my $user_file = "$data_root/users/" . get_fileid($user_id) . ".sto";
			if ($user_id =~/f\/(.*)$/) {
				$user_file = "$data_root/facebook_users/" . get_fileid($1) . ".sto";
			}
		
		if (-e $user_file)
		{
		    $user_ref = retrieve($user_file) ;
		    $debug and print STDERR "Blogs::Users::init_user - user : " . $user_id . "\n" ;
		    $debug and print STDERR "Blogs::Users::init_user - cookie session : " . $user_session . "\n" ;
		    $debug and print STDERR "Blogs::Users::init_user - stock session : " . $user_ref->{'user_sessions'} . "\n" ;
		    $debug and print STDERR "Blogs::Users::init_user - stock ip : " . $user_ref->{'user_last_ip'} . "\n" ;
		    $debug and print STDERR "Blogs::Users::init_user - current ip : " . remote_addr() . "\n" ;

                       # Try to keep sessions opened for users with dynamic IPs

                       sub short_ip ($)
                       {
                               my $ip = shift;
                               # Remove the last two bytes
                               $ip =~ s/(\.\d+){2}$//;
                               return $ip;
                       }

			if ($debug) {
				#use Data::Dumper;
				#print STDERR Dumper($user_ref->{'user_sessions'}) . "\n";
			}

                    if ((not defined $user_ref->{'user_sessions'})
                        or (not defined $user_session)
                        or (not defined $user_ref->{'user_sessions'}{$user_session})
                        or (not defined $user_ref->{'user_sessions'}{$user_session}{'ip'})
                        or ((short_ip($user_ref->{'user_sessions'}{$user_session}{'ip'}) ne (short_ip(remote_addr()))) ))
		    {
			$debug and print STDERR "Blogs::Users::init_user - no matching session\n";
			$user_id = undef;
			# Remove the cookie
			my $session = {} ;
			$cookie = cookie (-name=>$cookie_name, -expires=>'-1d',-value=>$session, -path=>'/', -domain=>".$domain") ;
		    }
		    else
		    {
			# Get actual user_id (i.e. BIZ or biz -> Biz)
			$debug and print STDERR "Blogs::Users::init_user - user identified: $user_id\n" ;
			$debug and print STDERR "Blogs::Users::init_user - user stocked: $user_ref->{'userid'}\n" ;

			$user_id = $user_ref->{'userid'} ;
			
			# Facebook session?
			if (defined $user_ref->{'user_sessions'}{$user_session}{'facebook'}) {
				print STDERR "Blogs::Users::init_user - session opened through Facebook uid: " . $user_ref->{'user_sessions'}{$user_session}{'facebook'} . "\n";
				$Facebook_id = $user_ref->{'user_sessions'}{$user_session}{'facebook'};
			}
		    }

		}
		else
		{
		    # Remove the cookie
		    my $session = {} ;
		    $cookie = cookie (-name=>$cookie_name, -expires=>'-1d',-value=>$session, -path=>'/', -domain=>".$domain") ;

		    $user_id = undef ;
		}
	    }
	    else
	    {
		# Remove the cookie
		my $session = {} ;
		$cookie = cookie (-name=>$cookie_name, -expires=>'-1d',-value=>$session, -path=>'/', -domain=>".$domain") ;

		$user_id = undef ;
	    }
	}
	else
	{
	    $debug and print STDERR "Blogs::Users::init_user - nothing found!\n";
	}

	$debug and print STDERR "Blogs::Users::init_user - user_id: $user_id\n" ;
	$debug and print STDERR "Blogs::Users::init_user - cookie: $cookie\n" ;

	if (not defined $user_id)
	{
		# If we don't have a user id, check if there is a browser id cookie, or assign one

        if (not ((defined cookie('b')) and (cookie('b') =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)_(\d+)$/)))
        {
			my $b = remote_addr() . '_' . time();
			# $Visitor_id = $b;  # don't set $Visitor_id unless we get the cookie back
			# Set a cookie
			if (not defined $cookie)
			{
			 $cookie = cookie (-name=>'b', -value=>$b, -path=>'/', -expires=>'+86400000s') ;
			 print STDERR "Users.pm - setting b cookie: $cookie\n";
			} 
		}
		else
		{
            $Visitor_id = cookie('b');
			$user_ref = retrieve("$data_root/virtual_users/$Visitor_id.sto");
			print STDERR "Users.pm - got b cookie: $Visitor_id\n";
        }
                
	}
	
	$debug and print STDERR "User_id: $User_id - Visitor_id: $Visitor_id - set-cookie: $cookie\n";
	
	$User_id = $user_id;
	if (defined $user_ref) {
		%User = %$user_ref;
	}
	else {
		%User = undef;
	}
	
	return 0;
}


sub check_session($$) {

	my $user_id = shift;
	my $user_session = shift;

	$debug and print STDERR "Blogs::Users::check_session - user_id : " . $user_id . "\n" ;
	$debug and print STDERR "Blogs::Users::check_session - user_session : " . $user_session . "\n" ;
	
	
	my $user_file = "$data_root/users/" . get_fileid($user_id) . ".sto";
	
	my $results_ref = {};

	if (-e $user_file) {
		my $user_ref = retrieve($user_file) ;
		
		if (defined $user_ref) {
		
			$debug and print STDERR "Blogs::Users::check_session - stock session : " . $user_ref->{'user_sessions'} . "\n" ;
			$debug and print STDERR "Blogs::Users::check_session - stock ip : " . $user_ref->{'user_last_ip'} . "\n" ;
			$debug and print STDERR "Blogs::Users::check_session - current ip : " . remote_addr() . "\n" ;



				if ((not defined $user_ref->{'user_sessions'})
					or (not defined $user_session)
					or (not defined $user_ref->{'user_sessions'}{$user_session})
					# or (not defined $user_ref->{'user_sessions'}{$user_session}{'ip'})
					# or ((short_ip($user_ref->{'user_sessions'}{$user_session}{'ip'}) ne (short_ip(remote_addr()))) 
					
					) {
			$debug and print STDERR "Blogs::Users::check_session - no matching session\n";
			$user_id = undef;

		}
		else {
			# Get actual user_id (i.e. BIZ or biz -> Biz)
			$debug and print STDERR "Blogs::Users::check_session - user identified: $user_id\n" ;
			$debug and print STDERR "Blogs::Users::check_session - user stocked: $user_ref->{'userid'}\n" ;

			$user_id = $user_ref->{'userid'} ;
			$results_ref->{name} = $user_ref->{name};
			$results_ref->{email} = $user_ref->{email};
		}
		}
		else {
			$debug and print STDERR "Blogs::Users::check_session - could not load user: $user_id\n" ;
		}

	}
	else
	{
		$debug and print STDERR "Blogs::Users::check_session - user does not exist: $user_id\n" ;
		$user_id = undef ;
	}
	

	$results_ref->{user_id} = $user_id;

	return $results_ref;
}


sub save_user() {

	if (defined $Facebook_id) {
		store("$data_root/facebook_users/" . get_fileid($Facebook_id) . ".sto", \%User);
	}
	elsif (defined $User_id) {
		store("$data_root/users/$User_id.sto", \%User);
	}	
	elsif (defined $Visitor_id) {
		store("$data_root/virtual_users/$Visitor_id.sto", \%User);
	}
}

1;
