#!/usr/bin/perl -w

use ProductOpener::PerlStandards;

use Test2::V0;

use File::Temp qw/tempdir/;

use ProductOpener::ImportConvert qw/download_file_to/;

# The url of a download_to: mapping comes from the data file of a supplier, and it used to be
# concatenated into a one argument system() call: the double quotes that the code added around it
# are shell metacharacters, so the line always went through /bin/sh, and a double quote in the cell
# closed them. Here a cell that would run a command if the line was interpreted by a shell must be
# passed to wget as a single argument instead.

my $temp_dir = tempdir(CLEANUP => 1);
my $output_file = "$temp_dir/image.jpg";

# The payload closes the quotes that the old code added around the url, then runs a command.
# The url does not resolve, so the download fails either way: what is tested is that no shell ever
# sees the value.
my $injection_url = 'http://images.example.invalid/x";touch ' . $temp_dir . '/pwned;"';
my $pwned_file = "$temp_dir/pwned";

is(download_file_to($injection_url, $output_file), 0, "the download of a shell metacharacter url fails");
ok(not(-e $pwned_file), "no command was run by a shell");
is(-s $output_file, 0, "nothing was downloaded");

# Values that are not http(s) urls are refused before wget is called

foreach my $url (undef, "", "file:///etc/passwd", "ftp://images.example.invalid/x.jpg", "images.example.invalid/x.jpg")
{
	is(download_file_to($url, $output_file), 0, "'" . ($url // "undef") . "' is not downloaded");
}

is(-s $output_file, 0, "wget was not called for a value that is not an http(s) url");

done_testing();
