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

ProductOpener::Users - manage user profiles and sessions

=head1 SYNOPSIS

C<ProductOpener::Users> contains functions to create and edit user profiles
and to manage user sessions.

    use ProductOpener::Users qw/:all/;

	[..]

	init_user();


=head1 DESCRIPTION

[..]

=cut

package ProductOpener::Users;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		%User
		$User_id
		%Org
		$Org_id
		$Owner_id

		$cookie

		&display_user_form
		&check_user_form
		&process_user_form
		&check_edit_owner

		&init_user
		&save_user

		&userpath
		&create_user
		&create_password_hash
		&check_password_hash

		&check_session

		&generate_token

		);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Cache qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Orgs qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use Encode;

use Email::Valid;
use Crypt::PasswdMD5 qw(unix_md5_crypt);
use Math::Random::Secure qw(irand);
use Crypt::ScryptKDF qw(scrypt_hash scrypt_hash_verify);
use Log::Any qw($log);

my @user_groups = qw(producer database app bot moderator pro_moderator);

sub generate_token {
	my $name_length = shift;
	my @chars=('a'..'z', 'A'..'Z', 0..9);
	return join '',map {$chars[irand @chars]} 1..$name_length;
}

sub create_password_hash($) {

	my $password = shift;
	return scrypt_hash($password);
}

sub check_password_hash($$) {

	my $password = shift;
	my $hash = shift;

	if ($hash =~ /^\$1\$(?:.*)/) {
		if ($hash eq unix_md5_crypt($password, $hash)) {
			return 1;
		}
		else {
			return 0;
		}
	}
	else {
		return scrypt_hash_verify($password, $hash);
	}
}

sub userpath($) {

	my $file = shift;
	$file =~ s/^(...)(.)/$1\/$2/;
	return $file;
}


sub create_user($) {

	my $user_ref = shift;
	my $name_id = get_string_id_for_lang("no_language", $user_ref->{name});

	if (length($name_id) > 3) {

		my $i = 1;
		my $name_id2 = $name_id;

		while (-e "$data_root/users/$name_id2.sto") {
			$name_id2 = $name_id . "-" . ++$i;
		}

		$user_ref->{userid} = $name_id2;

		# TODO
		# Assign a random password
		# Send welcome e-mail + password - Might not be ideal, as passwords should not be sent over insecure channels such as e-mail.

		$log->info("creating new user file", { userid => $name_id2 }) if $log->is_info();
		store("$data_root/users/$name_id2.sto", $user_ref);
	}

	return;
}


sub display_user_form($$$) {

	my $type = shift;
	my $user_ref = shift;
	my $scripts_ref = shift;

	my $html = '';

	$html .= "\n<tr><td>$Lang{name}{$lang}</td><td>"
	. textfield(-id=>'name', -name=>'name', -value=>$user_ref->{name}, -size=>80, -autocomplete=>'name', -override=>1) . "</td></tr>"
	. "\n<tr><td>$Lang{email}{$lang}</td><td>"
	. textfield(-name=>'email', -value=>$user_ref->{email}, -size=>80, -autocomplete=>'email', -type=>'email', -override=>1) . "</td></tr>"
	. "\n<tr><td>$Lang{username}{$lang}<br/><span class=\"info\">" . (($type eq 'edit') ? '': $Lang{username_info}{$lang}) . "</span></td><td>"
	. (($type eq 'edit') ? $user_ref->{userid} :
		( textfield(-id=>'userid', -name=>'userid', -value=>$user_ref->{userid}, -size=>40, -onkeyup=>"normalize_string_value(this)", -autocomplete=>'username'))) . "</td></tr>"
	. "\n<tr><td>$Lang{password}{$lang}</td><td>"
	. password_field(-name=>'password', -value=>$user_ref->{password}, -autocomplete=>'new-password', -override=>1) . "</td></tr>"
	. "\n<tr><td>$Lang{password_confirm}{$lang}</td><td>"
	. password_field(-name=>'confirm_password', -value=>$user_ref->{password}, -autocomplete=>'new-password', -override=>1) . "</td></tr>"
	;

	# Professional account

	$html .= "\n<tr><td>" . lang("pro_account") . "</td><td>";

	$html .= "<p>" . lang("if_you_work_for_a_producer") . "</p>"
	. "<p>" . lang("producers_platform_description_long") . "</p>";

	my $teams_display = '';

	if ( ( defined $user_ref->{org} ) and ( $user_ref->{org} ne "" ) ) {

		# Existing user with an accepted organization

		$html .= "<p>"
			. sprintf(
			lang("this_is_a_pro_account_for_org"),
			"<b>" . $user_ref->{org} . "</b>"
			) . "</p>";
	}

	# Pro platform is only for food right now

	elsif ((defined $options{product_type}) and ($options{product_type} eq "food")) {
		# New user or existing user without an accepted organization

		my $pro_checked = '';
		my $pro_org_display = 'style="display:none"';

		# Check the "pro account" checkbox for register screen on the producers platform

		if (((defined $user_ref->{pro}) and ($user_ref->{pro}))
			or ((defined $server_options{producers_platform}) and ($type eq "add"))) {
			$pro_checked = "checked";
			$pro_org_display = "";
			$teams_display = 'style="display:none"';
		}

		$html .= "<input type=\"checkbox\" id=\"pro\" name=\"pro\" $pro_checked>"
		. "<label for=\"pro\">"
		. "<input type=\"hidden\" name=\"pro_checkbox\" value=\"1\"> "
		. lang("this_is_a_pro_account") . "</label>"
		. "<div id=\"pro_org\" $pro_org_display>"
		. "<p id=\"org-field\">" . lang("producer_or_brand") . separator_before_colon($lc) . ": "
		. textfield(-id=>'requested_org', -name=>'requested_org', -value=>$user_ref->{requested_org}, -override=>1)
		. "</p>";

		my $requested_org_ref = retrieve_org($user_ref->{requested_org});

		if ( defined $requested_org_ref ) {

			$html .= "<div id=\"existing_org_warning\">"
			. "<p>" . sprintf(lang("add_user_existing_org"), org_name($requested_org_ref)) . "</p>"
			. "<p>" . lang("add_user_existing_org_pending") . "</p>"
			. "<p>" .lang("please_email_producers") . "</p>"
			. "</div>";
		}
		else {
			$html .= "<p>" . lang("enter_name_of_org") . "</p>";
		}

		$html .= "</div>";

		$html .= "</td></tr>";

		$initjs .= <<JAVASCRIPT
\$('#pro').change(function() {
	if (\$(this).prop('checked')) {
		\$('#pro_org').show();
		\$('#tr_teams').hide();
	} else {
		\$('#pro_org').hide();
		\$('#tr_teams').show();
	}
	\$(document).foundation('equalizer', 'reflow');
});
JAVASCRIPT
;

	}

	# On the public web site, but not on the producers platform, offer to be part of a team

	if (not ((defined $server_options{private_products}) and ($server_options{private_products}))) {
		$html .= "\n<tr id=\"tr_teams\" $teams_display><td>" . lang("teams") . " (" . lang("optional") . ")</td><td><p>"
		. lang("teams_description") . "</p><p>" . lang("teams_names_warning") . "</p>"
		. '<div class="row">';

		for (my $i = 1; $i <= 3; $i++) {
			$html .= "\n<div class=\"small-3 large-2 xlarge-1 columns\">" . sprintf(lang("team_s"), $i) . lang("sep") . ":</div><div class=\"small-9 large-10 xlarge-11 columns\">"
			. textfield(-name=>"team_" . $i, -value=>$user_ref->{"team_" . $i}, -style=>"max-width:20rem", -override=>1, -onkeyup=>"normalize_string_value(this)") . "</div>";
		}

		$html .= "</div></td></tr>";
	}


	${$scripts_ref} .= <<SCRIPT
<script type="text/javascript">

function normalize_string_value(inputfield) {

	var value = inputfield.value.toLowerCase();

	value = value.replace(new RegExp(" ", 'g'),"-");
	value = value.replace(new RegExp("[àáâãäå]", 'g'),"a");
	value = value.replace(new RegExp("æ", 'g'),"ae");
	value = value.replace(new RegExp("ç", 'g'),"c");
	value = value.replace(new RegExp("[èéêë]", 'g'),"e");
	value = value.replace(new RegExp("[ìíîï]", 'g'),"i");
	value = value.replace(new RegExp("ñ", 'g'),"n");
	value = value.replace(new RegExp("[òóôõö]", 'g'),"o");
	value = value.replace(new RegExp("œ", 'g'),"oe");
	value = value.replace(new RegExp("[ùúûü]", 'g'),"u");
	value = value.replace(new RegExp("[ýÿ]", 'g'),"y");
	value = value.replace(new RegExp("[^a-zA-Z0-9-]", 'g'),"-");
	value = value.replace(new RegExp("-+", 'g'),"-");
	value = value.replace(new RegExp("^-"),"");

	inputfield.value = value;
}

</script>
SCRIPT
;

	return $html;
}


sub display_user_form_optional($$) {

	my $type = shift;
	my $user_ref = shift;

	my $html = '';

	# $html .= "\n<tr><td>$Lang{twitter}{$lang}</td><td>"
	# . textfield(-id=>'twitter', -name=>'twitter', -value=>$user_ref->{name}, -size=>80, -override=>1) . "</td></tr>";

	if ($type eq 'add') {

		$html .=
		"\n<tr><td colspan=\"2\">" . checkbox(-name=>'newsletter', -label=>lang("newsletter_description"), -checked=>'on') . "<br />
		$Lang{unsubscribe_info}{$lang}</td></tr>";
	}

	return $html;
}


sub display_user_form_admin_only($$) {

	my $type = shift;
	my $user_ref = shift;

	my $html = '';

	if (not $admin) {
		return '';
	}

	# $html .= "\n<tr><td>$Lang{twitter}{$lang}</td><td>"
	# . textfield(-id=>'twitter', -name=>'twitter', -value=>$user_ref->{name}, -size=>80, -override=>1) . "</td></tr>";

	if (($type eq 'add') or ($type eq 'edit')) {

		$html .= "\n<tr><td colspan=\"2\" style=\"background-color:#ffcccc\">Administrator fields</td></tr>";

		$html .= "\n<tr><td>$Lang{organization}{$lang}</td><td>"
		. textfield(-id=>'org', -name=>'org', -value=>$user_ref->{org}, -size=>80, -autocomplete=>'org', -override=>1) . "</td></tr>";

		$html .= "\n<tr><td colspan=\"2\">" . lang("user_groups") . lang("sep") . ":<ul>";

		foreach my $group (@user_groups) {
			$html .= "<li>"
			. checkbox(-name=>"user_group_$group", -label=>" " . lang("user_group_$group") . separator_before_colon($lc) . " " . lang("user_group_${group}_description")
				, -checked=>$user_ref->{$group}, -override=>1)  . "</li>";
		}

		$html .= "</td></tr>";
	}

	return $html;
}


sub check_user_form($$$) {

	my $type = shift;
	my $user_ref = shift;
	my $errors_ref = shift;

	$user_ref->{userid} = remove_tags_and_quote(param('userid'));
	$user_ref->{name} = remove_tags_and_quote(decode utf8=>param('name'));

	my $email = remove_tags_and_quote(decode utf8=>param('email'));

	$log->debug("check_user_form", { type => $type, user_ref => $user_ref, email => $email }) if $log->is_debug();

	if ($user_ref->{email} ne $email) {

		# check that the email is not already used
		my $emails_ref = retrieve("$data_root/users_emails.sto");
		if ((defined $emails_ref->{$email}) and ($emails_ref->{$email}[0] ne $user_ref->{userid})) {
			$log->debug("check_user_form - email already in use", { type => $type, email => $email, existing_userid => $emails_ref->{$email} }) if $log->is_debug();
			push @{$errors_ref}, $Lang{error_email_already_in_use}{$lang};
		}

		# Keep old email until the user is saved
		$user_ref->{old_email} = $user_ref->{email};
		$user_ref->{email} = $email;
	}

	if (defined param('twitter')) {
		$user_ref->{twitter} = remove_tags_and_quote(decode utf8=>param('twitter'));
		$user_ref->{twitter} =~ s/^http:\/\/twitter.com\///;
		$user_ref->{twitter} =~ s/^\@//;
	}

	# Is there a checkbox to make a professional account
	if (defined param("pro_checkbox")) {

		if (param("pro")) {
			$user_ref->{pro} = 1;

			if (defined param("requested_org")) {
				$user_ref->{requested_org} = remove_tags_and_quote(decode utf8=>param("requested_org"));

				my $requested_org_id = get_string_id_for_lang("no_language", $user_ref->{requested_org});

				if ($requested_org_id ne "") {
					$user_ref->{requested_org_id} = $requested_org_id;
				}
				else {
					push @{$errors_ref}, "error_missing_org";
				}
			}
			else {
				delete $user_ref->{requested_org_id}
			}
		}
		else {
			delete $user_ref->{pro};
			delete $user_ref->{requested_org_id}
		}
	}


	if ($type eq 'add') {
		$user_ref->{newsletter} = remove_tags_and_quote(param('newsletter'));
		$user_ref->{discussion} = remove_tags_and_quote(param('discussion'));
		$user_ref->{ip} = remote_addr();
		$user_ref->{initial_lc} = $lc;
		$user_ref->{initial_cc} = $cc;
		$user_ref->{initial_user_agent} = user_agent();
	}

	if ($admin) {

		# Org

		my $previous_org = $user_ref->{org};
		$user_ref->{org} = remove_tags_and_quote(decode utf8=>param('org'));
		if ($user_ref->{org} ne "") {
			$user_ref->{org_id} = get_string_id_for_lang("no_language", $user_ref->{org});
			# Admin field for org overrides the requested org field
			delete $user_ref->{requested_org};
			delete $user_ref->{requested_org_id};

			my $org_ref = retrieve_or_create_org($User_id, $user_ref->{org});

			add_user_to_org( $org_ref, $user_ref->{userid},
				[ "admins", "members" ] );
		}
		else {
			delete $user_ref->{org};
			delete $user_ref->{org_id};
		}

		if ((defined $previous_org) and ($previous_org ne "") and ($previous_org ne $user_ref->{org})) {
			my $org_ref = retrieve_org($previous_org);
			if (defined $org_ref) {
				remove_user_from_org( $org_ref, $user_ref->{userid},
					[ "admins", "members" ] );
			}
		}

		# Permission groups

		foreach my $group (@user_groups) {
			$user_ref->{$group} = remove_tags_and_quote(param("user_group_$group"));
		}
	}

	defined $user_ref->{registered_t} or $user_ref->{registered_t} = time();

	for (my $i = 1; $i <= 3; $i++) {
		if (defined param('team_' . $i)) {
			$user_ref->{'team_' . $i} = remove_tags_and_quote(decode utf8=>param('team_' . $i));
			$user_ref->{'team_' . $i} =~ s/\&lt;/ /g;
			$user_ref->{'team_' . $i} =~ s/\&gt;/ /g;
			$user_ref->{'team_' . $i} =~ s/\&quot;/"/g;
		}
	}

	# Check input parameters, redisplay if necessary

	if (length($user_ref->{name}) < 2) {
		push @{$errors_ref}, $Lang{error_no_name}{$lang};
	}

	my $address;
	eval {
		$address = Email::Valid->address( -address => $user_ref->{email}, -mxcheck => 1 );
	};
	$address = 0 if $@;
	if (not $address) {
		push @{$errors_ref}, $Lang{error_invalid_email}{$lang};
	}

	if ($type eq 'add') {

		my $userid = get_string_id_for_lang("no_language", $user_ref->{userid});

		if (length($user_ref->{userid}) < 2) {
			push @{$errors_ref}, $Lang{error_no_username}{$lang};
		}
		elsif (-e "$data_root/users/$userid.sto") {
			push @{$errors_ref}, $Lang{error_username_not_available}{$lang};
		}
		elsif ($user_ref->{userid} !~ /^[a-z0-9]+[a-z0-9\-]*[a-z0-9]+$/) {
			push @{$errors_ref}, $Lang{error_invalid_username}{$lang};
		}

		if (length(decode utf8=>param('password')) < 6) {
			push @{$errors_ref}, $Lang{error_invalid_password}{$lang};
		}
	}

	if (param('password') ne param('confirm_password')) {
		push @{$errors_ref}, $Lang{error_different_passwords}{$lang};
	}
	elsif (param('password') ne '') {
		$user_ref->{encrypted_password} = create_password_hash( encode_utf8(decode utf8=>param('password')) );
	}

	return;
}




sub process_user_form($$) {

	my $type = shift;
	my $user_ref = shift;
	my $userid = $user_ref->{userid};
    my $error = 0;

	$log->debug("process_user_form", { type => $type, user_ref => $user_ref }) if $log->is_debug();

    # Professional account with requested org?

    if (defined $user_ref->{requested_org_id}) {

		my $requested_org_ref = retrieve_org($user_ref->{requested_org_id});

		if (defined $requested_org_ref) {
			# The requested org already exists

			my $admin_mail_body = <<EMAIL
requested_org_id: $user_ref->{requested_org_id}
userid: $user_ref->{userid}
name: $user_ref->{name}
email: $user_ref->{email}
lc: $user_ref->{initial_lc}
cc: $user_ref->{initial_cc}
EMAIL
;
			send_email_to_admin("Org request - user: $userid - org: " . $user_ref->{requested_org_id}, $admin_mail_body);
		}
		else {
			# The requested org does not exist, create it

			my $org_ref = create_org($userid, $user_ref->{requested_org});
			add_user_to_org($org_ref, $userid, ["admins", "members"]);

			$user_ref->{org} = $user_ref->{requested_org_id};
			$user_ref->{org_id} = get_string_id_for_lang("no_language", $user_ref->{org});

			my $admin_mail_body = <<EMAIL
requested_org_id: $user_ref->{requested_org_id}
userid: $user_ref->{userid}
name: $user_ref->{name}
email: $user_ref->{email}
lc: $user_ref->{initial_lc}
cc: $user_ref->{initial_cc}
EMAIL
;
			send_email_to_admin(
				"Org created by user: $userid - org: "
					. $user_ref->{requested_org_id},
				$admin_mail_body
			);

			delete $user_ref->{requested_org};
			delete $user_ref->{requested_org_id}
		}
	}

	store("$data_root/users/$userid.sto", $user_ref);

	# Update email
	my $emails_ref = retrieve("$data_root/users_emails.sto");
	my $email = $user_ref->{email};

	if ((defined $email) and ($email =~/\@/)) {
		$emails_ref->{$email} = [$userid];
	}
	if (defined $user_ref->{old_email}) {
		delete $emails_ref->{$user_ref->{old_email}};
		delete $user_ref->{old_email};
	}
	store("$data_root/users_emails.sto", $emails_ref);


	if ($type eq 'add') {

		# Initialize the session to send a session cookie back
		# so that newly created users do not have to login right after

		param("user_id", $userid);
		init_user();


		my $email = lang("add_user_email_body");
		$email =~ s/<USERID>/$userid/g;
		# $email =~ s/<PASSWORD>/$user_ref->{password}/g;
		$error = send_email($user_ref,lang("add_user_email_subject"), $email);

		my $admin_mail_body = <<EMAIL

Bonjour,

Inscription d'un utilisateur :

name: $user_ref->{name}
email: $user_ref->{email}
twitter: https://twitter.com/$user_ref->{twitter}
newsletter: $user_ref->{newsletter}
discussion: $user_ref->{discussion}
lc: $user_ref->{initial_lc}
cc: $user_ref->{initial_cc}

EMAIL
;
		$error += send_email_to_admin("Inscription de $userid", $admin_mail_body);
	}
    return $error;
}


sub check_edit_owner($$) {

	my $user_ref = shift;
	my $errors_ref = shift;

	$user_ref->{pro_moderator_owner} = get_string_id_for_lang("no_language", remove_tags_and_quote(param('pro_moderator_owner')));

	$log->debug("check_edit_owner", { pro_moderator_owner => $User{pro_moderator_owner} }) if $log->is_debug();

	if ((not defined $user_ref->{pro_moderator_owner}) or ($user_ref->{pro_moderator_owner} eq "")) {
		delete $user_ref->{pro_moderator_owner};
		# Also edit the current user object so that we can display the current status directly on the form result page
		delete $User{pro_moderator_owner};
	}
	elsif ($user_ref->{pro_moderator_owner} =~ /^org-/) {
		my $orgid = $';
		$User{pro_moderator_owner} = $user_ref->{pro_moderator_owner};
		$log->debug("set pro_moderator_owner (org)", { orgid => $orgid, pro_moderator_owner => $User{pro_moderator_owner} }) if $log->is_debug();
	}
	elsif ($user_ref->{pro_moderator_owner} =~ /^user-/) {
		my $userid = $';
		# Add check that organization exists when we add org profiles

		if (! -e "$data_root/users/$userid.sto") {
			push @{$errors_ref}, sprintf($Lang{error_user_does_not_exist}{$lang}, $userid);
		}
		else {
			$User{pro_moderator_owner} = $user_ref->{pro_moderator_owner};
			$log->debug("set pro_moderator_owner (user)", { userid => $userid, pro_moderator_owner => $User{pro_moderator_owner} }) if $log->is_debug();
		}
	}
	elsif ($user_ref->{pro_moderator_owner} eq 'all') {
		# Admin mode to see all products from all owners
		$User{pro_moderator_owner} = $user_ref->{pro_moderator_owner};
		$log->debug("set pro_moderator_owner (all) see products from all owners", { pro_moderator_owner => $User{pro_moderator_owner} }) if $log->is_debug();
	}
	else {
		push @{$errors_ref},$Lang{error_malformed_owner}{$lang};
		$log->debug("error - malformed pro_moderator_owner", { pro_moderator_owner => $User{pro_moderator_owner} }) if $log->is_debug();
	}

	return;
}

sub init_user()
{
	my $user_id = undef ;
	my $user_ref = undef;
	my $org_ref = undef;

	my $cookie_name   = 'session';
	my $cookie_domain = "." . $server_domain;    # e.g. fr.openfoodfacts.org sets the domain to .openfoodfacts.org
	if ( defined $server_options{cookie_domain} ) {
		$cookie_domain = "." . $server_options{cookie_domain};    # e.g. fr.import.openfoodfacts.org sets domain to .openfoodfacts.org
	}

	$cookie = undef;

	$User_id = undef;
	$Org_id = undef;
	%User = ();
	%Org = ();

	# Remove persistent cookie if user is logging out
	if ((defined param('length')) and (param('length') eq 'logout')) {
		$log->debug("user logout") if $log->is_debug();
		my $session = {} ;
		$cookie = cookie (-name=>$cookie_name, -expires=>'-1d',-value=>$session, -path=>'/', -domain=>"$cookie_domain") ;
	}

	# Retrieve user_id and password from form parameters
	elsif ( (defined param('user_id')) and (param('user_id') ne '') and
                       ( ( (defined param('password')) and (param('password') ne ''))
                         ) ) {

		# CGI::param called in list context from package ProductOpener::Users line 373, this can lead to vulnerabilities.
		# See the warning in "Fetching the value or values of a single named parameter"
		# -> use a scalar to avoid calling param() in the list of arguments to remove_tags_and_quote
		my $param_user_id = param('user_id');
		$user_id = remove_tags_and_quote($param_user_id) ;

		if ($user_id =~ /\@/) {
			my $emails_ref = retrieve("$data_root/users_emails.sto");
			$log->info("got email while initializing user", { email => $user_id }) if $log->is_info();
			if (not defined $emails_ref->{$user_id}) {
				$user_id = undef;
			}
			else {
				my @userids = @{$emails_ref->{$user_id}};
				$user_id = $userids[0];
			}

			$log->info("corresponding user_id", { userid => $user_id }) if $log->is_info();
		}

		$log->context->{user_id} = $user_id;
		$log->debug("user_id is defined") if $log->is_debug();
		my $session = undef ;

		# If the user exists
		if (defined $user_id) {

           my  $user_file = "$data_root/users/" . get_string_id_for_lang("no_language", $user_id) . ".sto";

			if (-e $user_file) {
				$user_ref = retrieve($user_file) ;
				$user_id = $user_ref->{'userid'} ;
				$log->context->{user_id} = $user_id;

				my $hash_is_correct = check_password_hash(encode_utf8(decode utf8=>param('password')), $user_ref->{'encrypted_password'} );
				# We don't have the right password
				if (not $hash_is_correct) {
					$user_id = undef ;
					$log->info("bad password - input does not match stored hash", { encrypted_password => $user_ref->{'encrypted_password'} }) if $log->is_info();
					# Trigger an error
					return ($Lang{error_bad_login_password}{$lang}) ;
				}
				# We have the right login/password
				elsif (not defined param('no_log'))    # no need to store sessions for internal requests
				{
					$log->info("correct password for user provided") if $log->is_info();

					# Maximum of sessions for a given user
					my $max_session = 10 ;

					# Generate a secure session key, store the cookie
					my $user_session = generate_token(64);
					$log->context->{user_session} = $user_session;

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

					# Upgrade hashed password to scrypt, if it is still in crypt format
					if ($user_ref->{'encrypted_password'} =~ /^\$1\$(?:.*)/) {
						$user_ref->{'encrypted_password'} = create_password_hash(encode_utf8(decode utf8=>param('password')) );
						$log->info("crypt password upgraded to scrypt_hash") if $log->is_info();
					}

					store("$user_file", $user_ref);

					$log->debug("session initialized and user info stored") if $log->is_debug();
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
						$log->debug("setting persistent cookie") if $log->is_debug();
						$cookie = cookie (-name=>$cookie_name, -value=>$session, -path=>'/', -domain=>"$cookie_domain", -samesite=>'Lax',
								-expires=>'+' . $length . 's');
					}
					else
					{
					# Set a session cookie
						$log->debug("setting session cookie") if $log->is_debug();
						$cookie = cookie (-name=>$cookie_name, -value=>$session, -path=>'/', -domain=>"$cookie_domain", -samesite=>'Lax');
					}
				}
		    }
		    else
		    {
				$user_id = undef ;
				$log->info("bad user") if $log->is_info();
				# Trigger an error
				return ($Lang{error_bad_login_password}{$lang}) ;
		    }
		}
	}

	# Retrieve user_id and session from cookie
	elsif ((defined cookie($cookie_name)) or ((defined param('user_session')) and (defined param('user_id')))) {
		my $user_session;
		if (defined param('user_session')) {
			$user_session = param('user_session');
			$user_id = param('user_id');
			$log->debug("user_session parameter found", { user_id => $user_id, user_session => $user_session }) if $log->is_debug();
		}
		else {
			my %session = cookie($cookie_name);
			$user_session = $session{'user_session'} ;
			$user_id = $session{'user_id'};
			$log->debug("session cookie found", { user_id => $user_id, user_session => $user_session }) if $log->is_debug();
		}


	    if (defined $user_id)
	    {
			my $user_file = "$data_root/users/" . get_string_id_for_lang("no_language", $user_id) . ".sto";
			if ($user_id =~/f\/(.*)$/) {
				$user_file = "$data_root/facebook_users/" . get_string_id_for_lang("no_language", $1) . ".sto";
			}

		if (-e $user_file)
		{
		    $user_ref = retrieve($user_file);
			$log->debug("initializing user", {
				user_id => $user_id,
				user_session => $user_session,
				stock_session => $user_ref->{'user_sessions'},
				stock_ip => $user_ref->{'user_last_ip'},
				current_ip => remote_addr()
			}) if $log->is_debug();

			# Try to keep sessions opened for users with dynamic IPs
			my $short_ip = sub ($)
			{
				my $ip = shift;
				# Remove the last two bytes
				$ip =~ s/(\.\d+){2}$//;
				return $ip;
			};

			if ((not defined $user_ref->{'user_sessions'})
				or (not defined $user_session)
				or (not defined $user_ref->{'user_sessions'}{$user_session})
				or (not is_ip_known_or_whitelisted($user_ref, $user_session, remote_addr(), $short_ip)))
		    {
				$log->debug("no matching session for user") if $log->is_debug();
				$user_id = undef;
				$user_ref = undef;
				# Remove the cookie
				my $session = {} ;
				$cookie = cookie (-name=>$cookie_name, -expires=>'-1d',-value=>$session, -path=>'/', -domain=>"$cookie_domain") ;
		    }
		    else
		    {
				$log->debug("user identified", { user_id => $user_id, stocked_user_id => $user_ref->{'userid'} }) if $log->is_debug();
				$user_id = $user_ref->{'userid'} ;
		    }
		}
		else
		{
		    # Remove the cookie
		    my $session = {} ;
		    $cookie = cookie (-name=>$cookie_name, -expires=>'-1d',-value=>$session, -path=>'/', -domain=>"$cookie_domain") ;

		    $user_id = undef ;
		}
	    }
	    else
	    {
			# Remove the cookie
			my $session = {} ;
			$cookie = cookie (-name=>$cookie_name, -expires=>'-1d',-value=>$session, -path=>'/', -domain=>"$cookie_domain") ;

			$user_id = undef ;
	    }
	}
	else
	{
		$log->info("no user found") if $log->is_info();
	}

	$log->debug("cookie", { user_id => $user_id, cookie => $cookie }) if $log->is_debug();

	$User_id = $user_id;
	if (defined $user_ref) {
		%User = %{$user_ref};
	}
	else {
		%User = ();
	}

	# The org and org_id fields are currently properties of the user object (created by administrators through user.pl)
	# Populate $Org_id and %org_ref from the user profile.
	# TODO: create org profiles with customer service info etc.

	if (defined $user_ref->{org_id}) {
		$Org_id = $user_ref->{org_id};
		$org_ref = { org => $user_ref->{org}, org_id => $user_ref->{org_id} };
	}

	if (defined $Org_id) {
		%Org = %{$org_ref};
	}
	else {
		%Org = ();
	}

	# if products are private, select the owner used to restrict the product set with the owners_tags field
	if ((defined $server_options{private_products}) and ($server_options{private_products})) {

		# Producers platform moderators can set the owner to any user or organization
		if (($User{pro_moderator}) and (defined $User{pro_moderator_owner})) {
			$Owner_id = $User{pro_moderator_owner};
			if ($Owner_id =~ /^org-/) {
				$Org_id = $';
				%Org = ( org => $Org_id, org_id => $Org_id );
			}
			elsif ($Owner_id =~ /^user-/) {
				$Org_id = undef;
				%Org = ();
			}
			elsif ($Owner_id eq 'all') {
				$Org_id = undef;
				%Org = ();
			}
			else {
				$Owner_id = undef;
			}
		}
		elsif (defined $Org_id) {
			$Owner_id = "org-" . $Org_id;
		}
		elsif (defined $User_id) {
			$Owner_id = "user-" . $User_id;
		}
		else {
			$Owner_id = undef;
		}
	}
	else {
		$Owner_id = undef;
	}

	return 0;
}

sub is_ip_known_or_whitelisted {
	my ($user_ref, $user_session, $ip, $shorten_ip) = @_;

	my $short_ip = $shorten_ip->($ip);

	if ((defined $user_ref->{'user_sessions'}{$user_session}{'ip'})
	    and ($shorten_ip->($user_ref->{'user_sessions'}{$user_session}{'ip'}) eq $short_ip)) {
			return 1;
	}

	if (defined $server_options{ip_whitelist_session_cookie}) {
		foreach (@{$server_options{ip_whitelist_session_cookie}}) {
			if ($_ eq $ip) {
				return 1;
			}
		}
	}

	return 0;
}

sub check_session($$) {

	my $user_id = shift;
	my $user_session = shift;

	$log->debug("checking session", { user_id => $user_id, users_session => $user_session }) if $log->is_debug();

	my $user_file = "$data_root/users/" . get_string_id_for_lang("no_language", $user_id) . ".sto";

	my $results_ref = {};

	if (-e $user_file) {
		my $user_ref = retrieve($user_file) ;

		if (defined $user_ref) {
			$log->debug("comparing session with stored user", {
				user_id => $user_id,
				user_session => $user_session,
				stock_session => $user_ref->{'user_sessions'},
				stock_ip => $user_ref->{'user_last_ip'},
				current_ip => remote_addr()
			}) if $log->is_debug();

				if ((not defined $user_ref->{'user_sessions'})
					or (not defined $user_session)
					or (not defined $user_ref->{'user_sessions'}{$user_session})
					# or (not defined $user_ref->{'user_sessions'}{$user_session}{'ip'})
					# or (($short_ip->($user_ref->{'user_sessions'}{$user_session}{'ip'}) ne ($short_ip->(remote_addr())))

					) {
			$log->debug("no matching session for user") if $log->is_debug();
			$user_id = undef;

		}
		else {
			# Get actual user_id (i.e. BIZ or biz -> Biz)
			$log->debug("user identified", { user_id => $user_id, stocked_user_id => $user_ref->{'userid'} }) if $log->is_debug();

			$user_id = $user_ref->{'userid'} ;
			$results_ref->{name} = $user_ref->{name};
			$results_ref->{email} = $user_ref->{email};
		}
		}
		else {
			$log->info("could not load user", { user_id => $user_id }) if $log->is_info();
		}

	}
	else
	{
		$log->info("user does not exist", { user_id => $user_id }) if $log->is_info();
		$user_id = undef ;
	}

	$results_ref->{user_id} = $user_id;

	return $results_ref;
}


sub save_user() {

	if (defined $User_id) {
		store("$data_root/users/$User_id.sto", \%User);
	}

	return;
}

1;
