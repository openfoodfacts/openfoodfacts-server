#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# This script is meant to be called through process_new_image_off.sh, itself run through an icrontab

use ProductOpener::PerlStandards

	binmode(STDOUT, ":encoding(UTF-8)");

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Images qw/:all/;

use AnyEvent::Inotify::Simple;
use Log::Any qw($log);
use Log::Any::Adapter 'TAP';
use EV;

open(my $LOG, ">>", "$BASE_DIRS{LOGS}/run_cloud_vision_ocr.log");

sub send_file_to_ocr ($file) {
	my $destination = readlink $file;

	if (not defined $destination) {
		$log->error("Error: destination is not a valid symlink to an image file", {file => $file})
			if $log->is_error();
		print $LOG "ERROR: file: $file is not a valid symlink to an image file\n";
		return;
	}

	# compute arguments

	my $code;

	if ($file =~ /^([^\.]*)\.(\d+)\./) {
		$code = $2;
	}

	my $path = $destination;
	$path =~ s/.*\/images/\/images/;

	my $auth = "";
	if ($server_domain =~ /^dev\./) {
		$auth = "off:off@";
	}

	my $image_url = "https://" . $auth . "static." . $server_domain . $path;
	my $json_url = $image_url;
	$json_url =~ s/\.([^\.]+)$//;
	$json_url .= ".json";

	my $json_file = $destination;
	$json_file =~ s/\.([^\.]+)$//;
	$json_file .= ".json.gz";

	print $LOG "file: $file destination: $destination code: $code image_url: $image_url json_file: $json_file\n";
	open(my $gv_logs, ">>:encoding(UTF-8)", "$BASE_DIRS{LOGS}/cloud_vision.log");

	my $cloudvision_ref = send_image_to_cloud_vision($file, $json_file, \@CLOUD_VISION_FEATURES_FULL, $gv_logs);

	if (defined $cloudvision_ref) {

		# Call robotoff to process the image and/or json from Cloud Vision
		my $robotoff_response = send_image_to_robotoff($code, $image_url, $json_url, $auth . "api." . $server_domain);
		if ($robotoff_response->is_success) {
			print $LOG "--> robotoff success: " . $robotoff_response->decoded_content . "\n";
		}
		else {
			print $LOG "--> robotoff error: " . $robotoff_response->status_line . "\n";
		}

		unlink($file);
	}
	return;
}

sub robust_send_file_to_ocr ($file) {
	eval {send_file_to_ocr($file);};
	if ($@) {
		$log->error("send_file_to_ocr failed for $file: $@") if $log->is_error();
	}
	return;
}

sub run ($images_dir) {
	my $inotify = AnyEvent::Inotify::Simple->new(
		directory => $images_dir,
		wanted_events => [qw(create move)],
		event_receiver => sub {
			my ($event, $file, $moved_to) = @_;
			if ($event eq 'create') {
				robust_send_file_to_ocr("$images_dir/$file");
			}
		},
	);

	# call event loop
	EV::run();
	return;
}

sub main() {
	# first argument is the directory to watch
	my $images_dir = $ARGV[0];

	# signal handler for TERM, KILL, QUIT
	foreach my $sig (qw/TERM KILL QUIT/) {
		EV::signal $sig, sub {
			print "Exiting after receiving $sig";
			exit(0);
		};
	}

	run($images_dir);
	return;
}

main();
