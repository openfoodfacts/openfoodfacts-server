#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Log::Any::Adapter 'TAP';
use Storable qw(lock_store);
use Fcntl ':flock';

use ProductOpener::Store
	qw/get_fileid get_string_id_for_lang get_urlid store_object retrieve_object store_config retrieve_config link_object move_object remove_object object_iter object_exists object_path_exists/;
use ProductOpener::Paths qw/%BASE_DIRS ensure_dir_created_or_die/;

is(get_fileid('Do not challenge me!'), 'do-not-challenge-me');

my @tests = (
	"Bonjour !",
	"Café Olé! 3€ -10%",
	"No hablo Español, señor",
	"สำนักงานคณะกรรมการกลางอิสลามแห่งประเทศไทย, คณะกรรมการกลางอิสลามแห่งประเทศไทย",
	"예네버르", "ラム酒", "DLG Jährlich Prämiert", "fr:Bœuf"
);
foreach my $test (@tests) {
	ok(length get_fileid($test) > 0, "get_fileid(${test})");
	ok(length get_urlid($test) > 0, "get_urlid(${test})");
}

is(get_fileid("Café au lait, bœuf gros sel de Guérande", 0, 'fr'), "cafe-au-lait-boeuf-gros-sel-de-guerande");
is(get_fileid("ethic-advisor.UUID_in-MiXeD_CaSe"), "ethic-advisor.UUID-in-MiXeD-CaSe");
is(get_fileid("àáâãäåçèéêëìíîïñòóôõöùúûüýÿ", 0, 'fr'), "aaaaaaceeeeiiiinooooouuuuyy");
is(get_fileid("àáâãäåçèéêëìíîïñòóôõöùúûüýÿ", 1), "aaaaaaceeeeiiiinooooouuuuyy");
is(get_fileid("àáâãäåçèéêëìíîïñòóôõöùúûüýÿ", 0, 'de'), "àáâãäåçèéêëìíîïñòóôõöùúûüýÿ");
is(get_fileid("Farine de blé 56g *", 0, 'fr'), "farine-de-ble-56g");
is(get_fileid('ẞ'), 'ß');
is(get_fileid('ẞ', 1), 'ss');

is(get_string_id_for_lang("no_language", "Café crème"), "cafe-creme");
is(get_string_id_for_lang("fr", "Café crème"), "cafe-creme");
is(get_string_id_for_lang("de", "Café crème"), "café-crème");
is(get_string_id_for_lang("de", "Äpfel"), "äpfel");
is(get_string_id_for_lang("en", "Äpfel"), "apfel");
is(get_string_id_for_lang("es", "Trazas : cacahuete, Trazas : huevo. frutos de cáscara."),
	"trazas-cacahuete-trazas-huevo-frutos-de-cascara");
is(get_string_id_for_lang("fr", "Pâte de cacao"), "pate-de-cacao");

# accents with one character, or unaccented character + unicode accent mark
is(get_string_id_for_lang("es", "arándanos, arándanos"), "arandanos-arandanos");

# Greek
is(get_string_id_for_lang("en", "string with spaces"), "string-with-spaces");
is(get_string_id_for_lang("el", "string with spaces"), "string-with-spaces");
is(get_string_id_for_lang("en", "E420 - Σορβιτολη"), "e420-σορβιτολη");
is(get_string_id_for_lang("el", "E420 - Σορβιτολη"), "e420-σορβιτολη");

# Test store object
my $test_root_path = "$BASE_DIRS{CACHE_TMP}/test-store";
my $test_name = "test-object";
my $test_path = "$test_root_path/$test_name";

# Make sure json file doesn't exist
remove_object($test_path);
# Create an initial test file
ensure_dir_created_or_die($test_root_path);
lock_store({id => 1}, "$test_path.sto");

ok(object_exists($test_path), "object_exists should recognize sto files");

is(retrieve_object("$test_path"), {id => 1}, "Verify retrieve copes with a sto file");

# Use the new method to update it
store_object("$test_path", {id => 2});
ok((-e "$test_path.json"), "Verify that the json file has been created");
open(my $JSON, '<', "$test_path.json");
local $/;    #Enable 'slurp' mode
my $data = <$JSON>;
close($JSON);
is($data, '{"id":2}', "Content of json file is correct");

ok((not -e "$test_path.sto"), "The old sto file should be deleted");
is(retrieve_object("$test_path"), {id => 2}, "Check data is saved");

# Test linking
remove_object("$test_path-link");
# Note links are done using relative paths
link_object($test_name, "$test_path-link");
is(retrieve_object("$test_path-link"), {id => 2}, "Link should show original's data");

# Update the original
store_object("$test_path", {id => 3});
is(retrieve_object("$test_path-link"), {id => 3}, "Link reflects original");

# Update via the link
store_object("$test_path-link", {id => 4});
is(retrieve_object("$test_path"), {id => 4}, "Original reflects update via link");

# Link to an sto file
remove_object("$test_path-link-stofile");
lock_store({id => "stofile"}, "$test_path-stofile.sto");
link_object("$test_name-stofile", "$test_path-link-stofile");
is(retrieve_object("$test_path-link-stofile"), {id => "stofile"}, "Link to sto reflects original");

# Update via the link when the old file is an STO
remove_object("$test_path-sto");
lock_store({id => "stolink"}, "$test_path-sto.sto");
symlink("$test_name-sto.sto", "$test_path-sto-link.sto");
# Check data is fetched OK
is(retrieve_object("$test_path-sto-link"), {id => "stolink"}, "Sto Link works");
# Update via the link. This should create the real json file and link and delete the sto file and link
store_object("$test_path-sto-link", {id => "stolink2"});
is(retrieve_object("$test_path-sto"), {id => "stolink2"}, "Original reflects update via link");
ok(-e "$test_path-sto.json", "JSON file is created");
ok(-e "$test_path-sto-link.json", "JSON link is created");
ok(!-e "$test_path-sto.sto", "STO file is deleted");
ok(!-e "$test_path-sto-link.sto", "STO link is deleted");

# Open an orphaned link, e.g. product.sto link points to a revision that has already been converted to JSON
remove_object("$test_path-product_revision");
store_object("$test_path-current_revision", {id => '1'});
symlink("$test_name-current_revision.sto", "$test_path-product_revision.sto");
is(retrieve_object("$test_path-product_revision"), {id => '1'}, "Data is fetched from the JSON file");

# If we save back to the link it creates a JSON link to the target file
store_object("$test_path-product_revision", {id => '2'});
ok(-l "$test_path-product_revision.json", "New path stays as a link");
is(retrieve_object("$test_path-current_revision"), {id => '2'}, "Target file is updated");

# Move object
store_object("$test_path-tomove", {id => "tomove"});
move_object("$test_path-tomove", "$test_path-moved");
is(retrieve_object("$test_path-moved"), {id => "tomove"}, "File moved");
ok(!-e "$test_path-tomove.json", "Original file deleted");

# Move copes with an sto file
lock_store({id => "sto-tomove"}, "$test_path-sto-tomove.sto");
move_object("$test_path-sto-tomove", "$test_path-sto-moved");
is(retrieve_object("$test_path-sto-moved"), {id => "sto-tomove"}, "Sto File moved");
ok(!-e "$test_path-stotomove.sto", "Original sto file deleted");

# Check copes with an empty JSON file
open(my $EMPTY, '>', "$test_path-empty.json");
close($EMPTY);
is(retrieve_object("$test_path-empty"), undef, "Empty JSON returns undef");

# Check copes with invalid JSON file
open(my $INVALID, '>', "$test_path-invalid.json");
print $INVALID '{ not json';
close($INVALID);
is(retrieve_object("$test_path-invalid"), undef, "invalid JSON returns undef");

is(retrieve_object("$test_path-no_exists"), undef, "Check copes with a non-existent file");

# Verify that JSON is formatted with store_config. Keys are sorted but array order is preserved
store_config("$test_path-sorting", {c => 1, a => 3, b => ['z', 'x', 'y']});
open(my $SORTED, '<', "$test_path-sorting.json");
local $/;    #Enable 'slurp' mode
my $json = <$SORTED>;
close($SORTED);

is(
	$json, '{
 "a":3,
 "b":[
  "z",
  "x",
  "y"
 ],
 "c":1
}
', "JSON is formatted with store_config"
);

# Creates paths if needed
srand();
my $long_path_root = "$test_root_path/nested/" . rand(100000);
my $long_path_suffix = "/" . rand(100000);
my $long_path = $long_path_root . $long_path_suffix . "/nested";
store_object($long_path, {data => $long_path});
is(retrieve_object($long_path), {data => $long_path}, "Creates directory on-the-fly");

ok(object_exists($long_path), "object_exists copes with files");

ok(object_path_exists($long_path_root), "object_path_exists copes with paths");

# Can move objects to a new path
my $new_root = $long_path_root . "/" . rand(100000);
move_object($long_path_root . $long_path_suffix, $new_root);
my $new_path = $new_root . "/nested";
is(retrieve_object($new_path), {data => $long_path}, "Moves data");
ok(!-e $long_path, "Original path removed");

# Test object iterator
my $next = object_iter($test_root_path);
my @object_paths = ();
while (my $object_path = $next->()) {
	push(@object_paths, $object_path);
}
ok(grep {$_ eq $test_path} @object_paths, "Iterator returns test file");
ok(grep {$_ eq $new_path} @object_paths, "Iterator returns random file");

# Test pattern match
$next = object_iter($test_root_path, qr/-link/);
@object_paths = ();
while (my $object_path = $next->()) {
	push(@object_paths, $object_path);
}
ok(!grep {$_ eq $test_path} @object_paths, "Iterator skips files not matching pattern");
ok(grep {$_ eq "$test_path-link"} @object_paths, "Iterator includes files matching pattern");

# Test directory exclusion
$next = object_iter($test_root_path, undef, qr/nested/);
@object_paths = ();
while (my $object_path = $next->()) {
	push(@object_paths, $object_path);
}
ok(grep {$_ eq $test_path} @object_paths, "Iterator includes files in non-excluded directories");
ok(!grep {$_ eq "nested"} @object_paths, "Iterator excludes files in excluded directories");

# Enable these on an ad-hoc basis to test locking. Can't leave enabled as coverage doesn't support threading
# use threads;
# # Verify that read waits for a current write to complete
# open(my $LOCKED, '>', "$test_path-locked.json");
# flock($LOCKED, LOCK_EX);
# # Write some data to the file
# print $LOCKED '{"id":';
# # Retrieve on another thread
# my $thread = threads->create(\&retrieve_object, "$test_path-locked");
# sleep(0.1);
# # Write the rest of the JSON
# print $LOCKED '3}';
# flock($LOCKED, LOCK_UN);
# close($LOCKED);
# my $result = $thread->join();
# is($result, {id => 3}, "retrieve waits for lock and returns new data");

# # Verify write waits for the current read to complete
# # Open the original test file for reading
# open(my $READ, '<', "$test_path-locked.json");
# flock($READ, LOCK_SH);
# local $/;    #Enable 'slurp' mode
# # Start a thread that updates it
# my $store_thread = threads->create(\&store_object, "$test_path-locked", {id => 4});
# sleep(0.1);
# my $read_data = <$READ>;
# flock($READ, LOCK_UN);
# close($READ);
# $store_thread->join();
# is($read_data, '{"id":3}', "Read before store should have old value");
# is(retrieve_object("$test_path-locked"), {id => 4}, "New data is written once read completes");

done_testing();
