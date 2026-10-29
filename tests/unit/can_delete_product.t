#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::Config qw/%server_options %admins/;
use ProductOpener::Users qw/%User $User_id $Org_id $Owner_id can_delete_product/;
use ProductOpener::Display qw/process_template/;

# Reset state
%User = ();
$User_id = undef;
$Org_id = undef;
$Owner_id = undef;
my $prev_producers_platform = $server_options{producers_platform};
my $prev_private_products = $server_options{private_products};

subtest "Public platform permissions" => sub {
	$server_options{producers_platform} = 0;
	$server_options{private_products} = 0;

	# Plain user
	%User = ();
	$User_id = 'regular_user';
	$Org_id = undef;
	$Owner_id = undef;
	is(can_delete_product(), 0, 'plain user cannot delete product on public platform');

	# User with org_id on public platform still cannot delete
	%User = (org_id => 'acme');
	$User_id = 'org_user';
	$Org_id = 'acme';
	$Owner_id = 'org-acme';
	is(can_delete_product(), 0, 'user with org cannot delete product on public platform');

	# Pro moderator on public platform cannot delete
	%User = (pro_moderator => 1);
	$User_id = 'promod';
	$Org_id = undef;
	$Owner_id = undef;
	is(can_delete_product(), 0, 'pro_moderator cannot delete product on public platform');

	# Moderator can delete
	%User = (moderator => 1);
	$User_id = 'mod';
	is(can_delete_product(), 1, 'moderator can delete product on public platform');

	# Admin can delete
	%User = ();
	$User_id = 'stephane';
	local $admins{'stephane'} = 1;
	is(can_delete_product(), 1, 'admin can delete product on public platform');
};

subtest "Producers platform permissions" => sub {
	$server_options{producers_platform} = 1;
	$server_options{private_products} = 1;

	# Plain user without org on pro platform
	%User = ();
	$User_id = 'new_user';
	$Org_id = undef;
	$Owner_id = 'user-new_user';
	is(can_delete_product(), 0, 'user without org cannot delete product on pro platform');

	# Member of an organization on pro platform
	%User = (org_id => 'acme');
	$User_id = 'acme_member';
	$Org_id = 'acme';
	$Owner_id = 'org-acme';
	is(can_delete_product(), 1, 'org member can delete product on pro platform even if not moderator or pro_moderator');

	# Org member with product belonging to same org
	my $acme_product_ref = {code => '123456', owner => 'org-acme'};
	is(can_delete_product(undef, undef, undef, $acme_product_ref),
		1, 'org member can delete product belonging to their org');

	# Org member with product belonging to different org
	my $other_product_ref = {code => '123456', owner => 'org-other'};
	is(can_delete_product(undef, undef, undef, $other_product_ref),
		0, 'org member cannot delete product belonging to another org');

	# Pro moderator on pro platform
	%User = (pro_moderator => 1);
	$User_id = 'promod';
	$Org_id = undef;
	$Owner_id = undef;
	is(can_delete_product(), 1, 'pro_moderator can delete product on pro platform');
	is(can_delete_product(undef, undef, undef, $other_product_ref),
		1, 'pro_moderator can delete any org product on pro platform');

	# Moderator on pro platform
	%User = (moderator => 1);
	$User_id = 'mod';
	$Org_id = undef;
	$Owner_id = undef;
	is(can_delete_product(), 1, 'moderator can delete product on pro platform');

	# Admin on pro platform
	%User = ();
	$User_id = 'stephane';
	local $admins{'stephane'} = 1;
	is(can_delete_product(), 1, 'admin can delete product on pro platform');
};

subtest "Template rendering of delete button" => sub {
	# Public platform - plain user does not see delete button
	$server_options{producers_platform} = 0;
	$server_options{private_products} = 0;
	%User = ();
	$User_id = 'regular_user';
	$Org_id = undef;
	$Owner_id = undef;

	my $html_edit = '';
	process_template(
		'web/pages/product_edit/product_edit_form_display.tt.html',
		{
			type => 'edit',
			code => '123456',
			errors_index => -1,
			input_sets => {},
			pers => [],
		},
		\$html_edit,
		{lc => 'en'}
	);
	unlike($html_edit, qr{type=delete}, 'delete link not rendered on edit form for plain user on public platform');

	my $html_page = '';
	process_template(
		'web/pages/product/product_page.tt.html',
		{
			code => '123456',
			title => 'Test Product',
		},
		\$html_page,
		{lc => 'en'}
	);
	unlike($html_page, qr{type=delete}, 'delete button not rendered on product page for plain user on public platform');

	# Pro platform - org member sees delete button
	$server_options{producers_platform} = 1;
	$server_options{private_products} = 1;
	%User = (org_id => 'acme');
	$User_id = 'acme_member';
	$Org_id = 'acme';
	$Owner_id = 'org-acme';

	$html_edit = '';
	process_template(
		'web/pages/product_edit/product_edit_form_display.tt.html',
		{
			type => 'edit',
			code => '123456',
			errors_index => -1,
			input_sets => {},
			pers => [],
			product => {code => '123456', owner => 'org-acme'},
		},
		\$html_edit,
		{lc => 'en'}
	);
	like($html_edit, qr{type=delete}, 'delete link rendered on edit form for org member on pro platform');

	$html_page = '';
	process_template(
		'web/pages/product/product_page.tt.html',
		{
			code => '123456',
			title => 'Test Product',
			product => {code => '123456', owner => 'org-acme'},
		},
		\$html_page,
		{lc => 'en'}
	);
	like($html_page, qr{type=delete}, 'delete button rendered on product page for org member on pro platform');
};

# Restore settings
$server_options{producers_platform} = $prev_producers_platform;
$server_options{private_products} = $prev_private_products;
%User = ();
$User_id = undef;
$Org_id = undef;
$Owner_id = undef;

done_testing();
