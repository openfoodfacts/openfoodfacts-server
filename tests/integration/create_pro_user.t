#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test::More;
use ProductOpener::APITest qw/:all/;
use ProductOpener::Test qw/:all/;
use ProductOpener::TestDefaults qw/:all/;

use Clone qw/clone/;

=head1 Test creation of a producer user

=cut

# clean
remove_all_users();
wait_dynamic_front();

my $admin_ua = new_client();
create_user($admin_ua, \%admin_user_form);
# create a pro moderator
my $moderator_ua = new_client();
create_user($moderator_ua, \%pro_moderator_user_form);
# admin pass him moderator
my %moderator_edit_form = (
	%pro_moderator_user_form,
	user_group_pro_moderator => "1",
	type => "edit",
);
edit_user($admin_ua, \%moderator_edit_form);

# A user come along an create it's profile and request to be part of an org
my $user_ua = new_client();
my %user_form = (
	%{clone(\%default_user_form)},
	pro => "1",
	requested_org => "Acme Inc."
);
create_user($user_ua, \%user_form);
# A mail was sent
FIXME

	done_testing();
