#!/usr/bin/perl -w

# Moving or trashing an uploaded image is a moderator action (or an org member action on the
# producers platform), so process_image_move() refuses to run for anyone else even if a caller
# forgot to check the permission itself
# (cgi/product_image_move.pl does check it, this is the second line of defence).

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';

use ProductOpener::Config qw/%server_options/;
use ProductOpener::Images qw/process_image_move/;
use ProductOpener::Users qw/%User/;

# Use an invalid move_to target so that a caller which passed the permission check
# stops at the validation right below it: no product or image file is touched.
my $invalid_move_to = 'not-a-barcode';

%User = ();
is(
	process_image_move('some-user', '0900000000139', '1', $invalid_move_to, ''),
	"error - no permission",
	'a plain user cannot move images'
);

%User = (moderator => 0);
is(
	process_image_move('some-user', '0900000000139', '1', $invalid_move_to, ''),
	"error - no permission",
	'a user with moderator set to 0 cannot move images'
);

%User = (moderator => 1);
is(
	process_image_move('some-user', '0900000000139', '1', $invalid_move_to, ''),
	"invalid barcode number: $invalid_move_to",
	'a moderator passes the permission check'
);

# Admins are allowed too (%admins is defined in Config.pm)
%User = ();
like(
	process_image_move('hangy', '0900000000139', '1', $invalid_move_to, ''),
	qr/^invalid barcode number: /,
	'an admin passes the permission check'
);

# On the producers platform, members of an organization can move images of their products
{
	local $server_options{private_products} = 1;

	%User = (org_id => 'acme');
	is(
		process_image_move('acme-member', '0900000000139', '1', $invalid_move_to, 'org-acme'),
		"invalid barcode number: $invalid_move_to",
		'an org member on the producers platform passes the permission check'
	);

	%User = ();
	is(
		process_image_move('some-user', '0900000000139', '1', $invalid_move_to, 'user-some-user'),
		"error - no permission",
		'a user without an org on the producers platform cannot move images'
	);
}

%User = ();
done_testing();
