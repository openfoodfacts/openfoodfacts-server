#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP';
use File::Temp qw/tempdir/;
use File::Path qw/make_path/;

use ProductOpener::Display qw/get_packager_code_coordinates/;
use ProductOpener::PackagerCodes qw/init_packager_codes %packager_codes @sorted_packager_codes/;
use ProductOpener::ProductsTags qw/set_field_input_tags_for_source/;
use ProductOpener::Store qw/store/;

subtest 'new and legacy product tags resolve against an old registry' => sub {
	my $data_root = tempdir(CLEANUP => 1);
	local $ProductOpener::PackagerCodes::data_root = $data_root;
	# Clear the shared variables in place so Display sees the same registry.
	%packager_codes = ();
	@sorted_packager_codes = ();
	make_path("$data_root/packager-codes");

	# Representative entries from DE-merge-UTF-8.csv and BE-merge-UTF-8.tsv.
	store(
		"$data_root/packager-codes/packager_codes.sto",
		{
			"de-by-30410-ec" => {
				cc => "de",
				name_des_betriebs => "Metzgerei Rauch",
				lat => "49.421147",
				lng => "12.1423655",
			},
			"be-1-11-ec" => {cc => "be", denomination => "Robberechts B.V.B.A."},
			"be-11-1-ec" => {cc => "be", denomination => "VAN HOORNWEDER MARCEL & Zn NV"},
		}
	);
	init_packager_codes();

	my $product_ref = {};
	set_field_input_tags_for_source($product_ref, "en", "emb_codes", "packaging", "DE BY 30410 EC");
	my $tag = $product_ref->{emb_codes_tags}[0];
	is($tag, "de-by30410-ec", "newly entered DE code uses the compact tag");
	is($packager_codes{$tag}{name_des_betriebs}, "Metzgerei Rauch", "the new tag resolves the packager name");
	is(
		[get_packager_code_coordinates($tag)],
		["49.421147", "12.1423655"],
		"the new tag retains the map coordinates before the registry is rebuilt"
	);
	is($packager_codes{"de-by-30410-ec"}, $packager_codes{$tag}, "legacy products still resolve the same record");
	is($packager_codes{"be-1-11-ec"}{denomination}, "Robberechts B.V.B.A.", "BE 1/11 retains its establishment");
	is(
		$packager_codes{"be-11-1-ec"}{denomination},
		"VAN HOORNWEDER MARCEL & Zn NV",
		"BE 11/1 retains its different establishment"
	);
	ok(!exists $packager_codes{"be-111-ec"}, "no colliding BE alias is created");
	is(
		\@sorted_packager_codes,
		["be-1-11-ec", "be-11-1-ec", "de-by30410-ec"],
		"suggestions contain one canonical spelling per code"
	);
};

subtest 'an existing canonical registry record takes precedence over an alias' => sub {
	my $data_root = tempdir(CLEANUP => 1);
	local $ProductOpener::PackagerCodes::data_root = $data_root;
	%packager_codes = ();
	@sorted_packager_codes = ();
	make_path("$data_root/packager-codes");
	store(
		"$data_root/packager-codes/packager_codes.sto",
		{
			"de-by-30410-ec" => {cc => "de", name_des_betriebs => "Old record"},
			"de-by30410-ec" => {cc => "de", name_des_betriebs => "Current record"},
		}
	);
	init_packager_codes();
	is($packager_codes{"de-by30410-ec"}{name_des_betriebs}, "Current record", "canonical data is preserved");
	is($packager_codes{"de-by-30410-ec"}{name_des_betriebs}, "Old record", "legacy data is preserved");
	is(\@sorted_packager_codes, ["de-by30410-ec"], "aliases do not duplicate suggestions");
};

done_testing();
