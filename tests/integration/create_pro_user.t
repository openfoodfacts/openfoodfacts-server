#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use Clone qw/clone/;
use List::Util qw/first/;

=head1 Test creation of a producer user

=cut

# clean
remove_all_users();
wait_dynamic_front();

my $admin_ua = new_client();
my $resp = create_user($admin_ua, \%admin_user_form);
ok(!html_displays_error($resp));
# create a pro moderator
my $moderator_ua = new_client();
$resp = create_user($moderator_ua, \%pro_moderator_user_form);
ok(!html_displays_error($resp));
# admin pass him moderator
my %moderator_edit_form = (
	%pro_moderator_user_form,
	user_group_pro_moderator => "1",
	type => "edit",
);
$resp = edit_user($admin_ua, \%moderator_edit_form);
ok(!html_displays_error($resp));

# A user come along an create it's profile and request to be part of an org
my $user_ua = new_client();
my %user_form = (
	%{clone(\%default_user_form)},
	pro => "1",
	requested_org => "Acme Inc."
);
my $tail = tail_log_start();
$resp = create_user($user_ua, \%user_form);
ok(!html_displays_error($resp));
my $logs = tail_log_read($tail);

# As it's the first, user is already part of the org
# FIXME: my $user = retrieve("$data_root/users/" . get_string_id_for_lang("no_language", $user_id) . ".sto";")

# Get mails from log
my @mails = mails_from_log($logs);
# we got three
is(scalar @mails, 3);
# we are interested in the one directed to pro admins
my $moderators_mail = first {$_ =~ /^To:.*producers\@openfoodfacts.org/im} @mails;
# go it
ok(defined $moderators_mail);
# got a link to … FIXME to continue

# the pro moderator validates the user org

done_testing();
