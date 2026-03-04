# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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

package ProductOpener::Checkpoint;

use ProductOpener::PerlStandards;

use File::Basename qw/basename/;
use List::MoreUtils qw/first_index/;

use ProductOpener::Paths qw/:all/;

sub new ($class) {
	my $script_name = basename($0);
	my $filename = "$BASE_DIRS{CACHE_TMP}/$script_name.checkpoint";
	if (!-e $filename) {
		`touch $filename`;
	}
	open(my $checkpoint_file, '+<', $filename) or die "Could not open file '$filename' $!";
	$checkpoint_file->autoflush;
	my $checkpoint = '';
	my $is_resume = first_index {$_ eq "resume"} @ARGV;
	if ($is_resume > -1) {
		seek($checkpoint_file, 0, 0);
		$checkpoint = <$checkpoint_file>;
		chomp $checkpoint if $checkpoint;
		splice(@ARGV, $is_resume, 1);
	}
	my $log_filename = "$BASE_DIRS{CACHE_TMP}/$script_name.log";
	my $mode = ($is_resume > -1 ? '>>' : '>');
	open(my $log_file, $mode, $log_filename);
	$log_file->autoflush;

	my $self = {
		checkpoint_file => $checkpoint_file,
		log_file => $log_file,
		value => $checkpoint
	};

	my $blessed = bless $self, $class;
	if ($checkpoint) {
		$blessed->log("Resuming from $checkpoint");
	}

	return $blessed;
}

sub update ($self, $checkpoint) {
	my $checkpoint_file = $self->{checkpoint_file};
	seek($checkpoint_file, 0, 0);
	print $checkpoint_file $checkpoint;
	truncate($checkpoint_file, tell($checkpoint_file));
	$self->{value} = $checkpoint;
	return;
}

sub log ($self, $message) {
	my $log_file = $self->{log_file};
	my $log_message = '[' . localtime() . '] ' . $message . "\n";
	print $log_message;
	print $log_file $log_message;
	return;
}

sub DESTROY {
	my ($self) = @_;
	$self->log("Finished");
	close $self->{checkpoint_file};
	close $self->{log_file};
	return;
}

1;
