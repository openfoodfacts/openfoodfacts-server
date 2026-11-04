#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# Tests for can_delete_product() and can_delete_image(), which share the same rules:
# admins and moderators can always delete, and on the producers platform, pro moderators
# and members of the organization that owns the product can delete too.

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::Config qw/%server_options %admins/;
use ProductOpener::Users qw/%User $User_id $Org_id $Owner_id can_delete_product can_delete_image/;
use ProductOpener::Display qw/process_template/;

my $prev_producers_platform = $server_options{producers_platform};
my $prev_private_products = $server_options{private_products};

sub set_user ($user_ref, $user_id, $org_id, $owner_id) {
	%User = %$user_ref;
	$User_id = $user_id;
	$Org_id = $org_id;
	$Owner_id = $owner_id;
	return;
}

my $acme_product_ref = {code => '123456', owner => 'org-acme'};
my $other_product_ref = {code => '123456', owner => 'org-other'};

foreach my $function (\&can_delete_product, \&can_delete_image) {

	my $name = ($function == \&can_delete_product) ? 'can_delete_product' : 'can_delete_image';

	subtest "$name - public platform" => sub {
		$server_options{producers_platform} = 0;
		$server_options{private_products} = 0;

		set_user({}, undef, undef, undef);
		is($function->(), 0, 'anonymous user cannot delete');

		set_user({}, 'regular_user', undef, undef);
		is($function->(), 0, 'plain user cannot delete');

		set_user({org_id => 'acme'}, 'org_user', 'acme', undef);
		is($function->($acme_product_ref), 0, 'user with an org cannot delete');

		set_user({pro_moderator => 1}, 'promod', undef, undef);
		is($function->(), 0, 'pro moderator cannot delete');

		set_user({moderator => 0}, 'not_mod', undef, undef);
		is($function->(), 0, 'user with moderator set to 0 cannot delete');

		set_user({moderator => 1}, 'mod', undef, undef);
		is($function->(), 1, 'moderator can delete');

		set_user({}, 'stephane', undef, undef);
		local $admins{'stephane'} = 1;
		is($function->(), 1, 'admin can delete');
		set_user({}, 'regular_user', undef, undef);
		is($function->(undef, 'stephane'), 1, 'admin passed as user id can delete');
	};

	subtest "$name - producers platform" => sub {
		$server_options{producers_platform} = 1;
		$server_options{private_products} = 1;

		set_user({}, undef, undef, undef);
		is($function->(), 0, 'anonymous user cannot delete');

		set_user({}, 'new_user', undef, 'user-new_user');
		is($function->(), 0, 'user without org cannot delete');
		is($function->({code => '123456', owner => 'user-new_user'}),
			0, 'user without org cannot delete their own product');

		set_user({org_id => 'acme'}, 'acme_member', 'acme', 'org-acme');
		is($function->(), 1, 'org member can delete');
		is($function->($acme_product_ref), 1, 'org member can delete product of their org');
		is($function->({code => '123456'}), 1, 'org member can delete product without owner field');
		is($function->($other_product_ref), 0, 'org member cannot delete product of another org');
		is($function->($acme_product_ref, 'acme_member', 'org-other'),
			0, 'explicit owner id is used instead of $Owner_id');
		is($function->($other_product_ref, 'acme_member', 'org-other'),
			1, 'explicit owner id matching the product owner');

		set_user({pro_moderator => 1}, 'promod', undef, undef);
		is($function->(), 1, 'pro moderator can delete');
		is($function->($other_product_ref), 1, 'pro moderator can delete product of any org');

		set_user({moderator => 1}, 'mod', undef, undef);
		is($function->($other_product_ref), 1, 'moderator can delete');

		set_user({}, 'stephane', undef, undef);
		local $admins{'stephane'} = 1;
		is($function->($other_product_ref), 1, 'admin can delete');
	};
}

# Render a template, and check that it rendered without error,
# so that a failed rendering does not make the unlike() tests below pass for the wrong reason
sub render ($template, $template_data_ref) {
	my $html = '';
	ok(process_template($template, $template_data_ref, \$html, {lc => 'en'}), "render $template")
		or diag($ProductOpener::Display::tt->error());
	return $html;
}

subtest "Template rendering of delete and manage images controls" => sub {

	# display_icon() reads SVG files that are built with npm, and not available in unit tests
	my $mock_display = mock 'ProductOpener::Display' => (override => [display_icon => sub ($icon) {"[icon:$icon]"}]);

	my $edit_form = 'web/pages/product_edit/product_edit_form_display.tt.html';
	my %edit_form_data = (
		type => 'edit',
		code => '123456',
		errors_index => -1,
		input_sets => {},
		pers => [],
	);

	set_user({}, 'regular_user', undef, undef);

	my $html = render($edit_form, {%edit_form_data, can_delete => 0, can_delete_image => 0});
	unlike($html, qr{type=delete}, 'edit form: no delete link without can_delete');
	unlike($html, qr{manage_images_accordion}, 'edit form: no manage images section without can_delete_image');

	$html = render($edit_form, {%edit_form_data, can_delete => 1, can_delete_image => 0});
	like($html, qr{type=delete}, 'edit form: delete link with can_delete');
	like($html, qr{\[icon:delete\]}, 'edit form: display_icon() is mocked');
	unlike($html, qr{manage_images_accordion}, 'edit form: manage images section depends on can_delete_image');

	# Org member on the producers platform: manage images without the moderator-only style
	$html = render($edit_form, {%edit_form_data, can_delete => 1, can_delete_image => 1});
	like($html, qr{manage_images_accordion}, 'edit form: manage images section with can_delete_image');
	like($html, qr{<a href="#manage_images_drop">}, 'edit form: manage images link is well-formed for non moderators');

	# Moderator: manage images link has the moderator-only class
	set_user({moderator => 1}, 'mod', undef, undef);
	$html = render($edit_form, {%edit_form_data, can_delete => 1, can_delete_image => 1});
	like(
		$html,
		qr{<a href="#manage_images_drop" class="moderator-only">},
		'edit form: manage images link is well-formed for moderators'
	);

	my $product_page = 'web/pages/product/product_page.tt.html';
	$html = render($product_page, {code => '123456', title => 'Test Product', can_delete => 0});
	unlike($html, qr{type=delete}, 'product page: no delete button without can_delete');

	$html = render($product_page, {code => '123456', title => 'Test Product', can_delete => 1});
	like($html, qr{type=delete}, 'product page: delete button with can_delete');
};

# Restore settings
$server_options{producers_platform} = $prev_producers_platform;
$server_options{private_products} = $prev_private_products;
set_user({}, undef, undef, undef);

done_testing();
