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

package ProductOpener::Store;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&get_urlid
		&get_fileid
		&store
		&retrieve
		&unac_string_perl
		&get_string_id_for_lang
		&get_url_id_for_lang
		&store_object
		&retrieve_object
		&retrieve_object_json
		&object_exists
		&object_path_exists
		&store_config
		&retrieve_config
		&link_object
		&move_object
		&remove_object
		&object_iter
		&write_json
		&write_canonical_json
		&read_json
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}
use vars @EXPORT_OK;    # no 'my' keyword for these

use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;

use Storable qw(lock_store lock_retrieve);

use URI::Escape::XS;
use Unicode::Normalize;
use Log::Any qw($log);
use Cpanel::JSON::XS;
use Fcntl ':flock';
use File::Basename qw/dirname/;
use File::Copy qw/move/;
use File::Copy::Recursive qw/dirmove/;
use Cwd qw/abs_path/;
use Carp qw/carp/;

# Use Cpanel::JSON::XS directly rather than JSON::MaybeXS as otherwise check_perl gives error:
# Can't locate object method "indent_length" via package "JSON::XS"
# Make sure we include convert_blessed to cater for blessed objects, like booleans
my $json_for_config = Cpanel::JSON::XS->new->allow_nonref->convert_blessed->canonical->indent->indent_length(1)->utf8;
my $json_for_objects = Cpanel::JSON::XS->new->allow_nonref->convert_blessed->utf8;

# Text::Unaccent unac_string causes Apache core dumps with Apache 2.4 and mod_perl 2.0.9 on jessie

sub unac_string_perl ($s) {

	$s
		=~ tr/àáâãäåçèéêëìíîïñòóôõöùúûüýÿÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝŸ/aaaaaaceeeeiiiinooooouuuuyyaaaaaaceeeeiiiinooooouuuuyy/;

	# alternative methods, slower than above, but more readable and still faster than s///.

	#$s =~ tr/àáâãäåçèéêëìíîïñòóôõöùúûüýÿ/aaaaaaceeeeiiiinooooouuuuyy/;
	#$s =~ tr/ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝŸ/aaaaaaceeeeiiiinooooouuuuyy/;

	#$s =~ tr/àáâãäåÀÁÂÃÄÅ/a/;
	#$s =~ tr/çÇ/c/;
	#$s =~ tr/èéêëÈÉÊË/e/;
	#$s =~ tr/ìíîïÌÍÎÏ/i/;
	#$s =~ tr/ñÑ/n/;
	#$s =~ tr/òóôõöÒÓÔÕÖ/o/;
	#$s =~ tr/ùúûüÙÚÛÜ/u/;
	#$s =~ tr/ýÿÝŸ/y/;

	$s =~ s/œ|Œ/oe/g;
	$s =~ s/æ|Æ/ae/g;

	return $s;
}

# Tags in European characters (iso-8859-1 / Latin-1 / Windows-1252) are canonicalized:
# 1. lowercase
# 2. unaccent: é -> è, + German umlauts: ä -> ae if $unaccent is 1 OR $lc is 'fr'
# 3. turn ascii characters that are not letters / numbers to -
# 4. keep other UTF-8 characters (e.g. Chinese, Japanese, Korean, Arabic, Hebrew etc.) untouched
# 5. remove leading and trailing -, turn multiple - to -

# IMPORTANT: if you change the behaviour of this method,
# you need to change $BUILD_TAGS_VERSION in Tags.pm

sub get_string_id_for_lang ($lc, $string) {

	defined $lc or die("Undef \$lc in call to get_string_id_for_lang (string: $string)\n");

	if (not defined $string) {
		return "";
	}

	# Normalize Unicode characters
	# Form NFC
	$string = NFC($string);

	my $unaccent = $string_normalization_for_lang{default}{unaccent};
	my $lowercase = $string_normalization_for_lang{default}{lowercase};

	if (defined $string_normalization_for_lang{$lc}) {
		if (defined $string_normalization_for_lang{$lc}{unaccent}) {
			$unaccent = $string_normalization_for_lang{$lc}{unaccent};
		}
		if (defined $string_normalization_for_lang{$lc}{lowercase}) {
			$lowercase = $string_normalization_for_lang{$lc}{lowercase};
		}
	}

	if ($lowercase) {
		# do not lowercase UUIDs
		# e.g.
		# yuka.VFpGWk5hQVQrOEVUcWRvMzVETGU0czVQbTZhd2JIcU1OTXdCSWc9PQ
		# (app)Waistline: e2e782b4-4fe8-4fd6-a27c-def46a12744c
		if ($string !~ /^[a-z\-]+\.[a-zA-Z0-9-_]{8}[a-zA-Z0-9-_]+$/) {
			$string =~ tr/\N{U+1E9E}/\N{U+00DF}/;    # Actual lower-case for capital ß
			$string = lc($string);
			$string =~ tr/./-/;
		}
	}

	if ($unaccent) {
		$string =~ tr/àáâãäåçèéêëìíîïñòóôõöùúûüýÿ/aaaaaaceeeeiiiinooooouuuuyy/;
		$string =~ s/œ|Œ/oe/g;
		$string =~ s/æ|Æ/ae/g;
		$string =~ s/ß|\N{U+1E9E}/ss/g;
	}

	# turn special chars and zero width space to -
	$string =~ tr/\000-\037\x{200B}/-/;

	# avoid turning &quot; in -quot-
	$string =~ s/\&(quot|lt|gt);/-/g;

	$string =~ s/[\s!"#\$%&'()*+,\/:;<=>?@\[\\\]^_`{\|}~¡¢£¤¥¦§¨©ª«¬®¯°±²³´µ¶·¸¹º»¼⅓½⅔¾¿×ˆ˜–—‘’‚“”„†‡•…‰‹›€™\t]/-/g;
	$string =~ tr/-/-/s;

	if (index($string, '-') == 0) {
		$string = substr $string, 1;
	}

	my $l = length($string);
	if (rindex($string, '-') == $l - 1) {
		$string = substr $string, 0, $l - 1;
	}

	return $string;

}

sub get_fileid ($file, $unaccent = undef, $lc = undef) {

	if (not defined $file) {
		return "";
	}

	if ((defined $lc) and ($lc eq 'fr')) {
		$unaccent = 1;
	}

	# do not lowercase UUIDs
	# e.g.
	# yuka.VFpGWk5hQVQrOEVUcWRvMzVETGU0czVQbTZhd2JIcU1OTXdCSWc9PQ
	# (app)Waistline: e2e782b4-4fe8-4fd6-a27c-def46a12744c
	if ($file !~ /^[a-z\-]+\.[a-zA-Z0-9-_]{8}[a-zA-Z0-9-_]+$/) {
		$file =~ tr/\N{U+1E9E}/\N{U+00DF}/;    # Actual lower-case for capital ß
		$file = lc($file);
		$file =~ tr/./-/;
	}

	if ($unaccent) {
		$file =~ tr/àáâãäåçèéêëìíîïñòóôõöùúûüýÿ/aaaaaaceeeeiiiinooooouuuuyy/;
		$file =~ s/œ|Œ/oe/g;
		$file =~ s/æ|Æ/ae/g;
		$file =~ s/ß|\N{U+1E9E}/ss/g;
	}

	# turn special chars and zero width space to -
	$file =~ tr/\000-\037\x{200B}/-/;

	# avoid turning &quot; in -quot-
	$file =~ s/\&(quot|lt|gt);/-/g;

	$file =~ s/[\s!"#\$%&'()*+,\/:;<=>?@\[\\\]^_`{\|}~¡¢£¤¥¦§¨©ª«¬®¯°±²³´µ¶·¸¹º»¼⅓½⅔¾¿×ˆ˜–—‘’‚“”„†‡•…‰‹›€™\t]/-/g;
	$file =~ tr/-/-/s;

	if (index($file, '-') == 0) {
		$file = substr $file, 1;
	}

	my $l = length($file);
	if (rindex($file, '-') == $l - 1) {
		$file = substr $file, 0, $l - 1;
	}

	return $file;

}

sub get_url_id_for_lang ($lc, $input) {

	my $string = $input;

	$string = get_string_id_for_lang($lc, $string);

	if ($string =~ /[^a-zA-Z0-9-]/) {
		$string = URI::Escape::XS::encodeURIComponent($string);
	}

	$log->trace("get_urlid", {in => $input, out => $string}) if $log->is_trace();

	return $string;
}

sub get_urlid ($input, $unaccent = undef, $lc = undef) {

	my $file = $input;

	$file = get_fileid($file, $unaccent, $lc);

	if ($file =~ /[^a-zA-Z0-9-]/) {
		$file = URI::Escape::XS::encodeURIComponent($file);
	}

	$log->trace("get_urlid", {in => $input, out => $file}) if $log->is_trace();

	return $file;
}

sub store ($file, $ref) {

	return lock_store($ref, $file);
}

sub retrieve ($file) {

	# If the file does not exist, return undef.
	if (!-e $file) {
		return;
	}
	my $return = undef;
	eval {$return = lock_retrieve($file);};

	if ($@ ne '') {
		carp("cannot retrieve $file : $@");
	}

	return $return;
}

#11901: Remove once production is migrated.
sub get_serialize_to_json_level() {
	return $serialize_to_json;
}

=head2 write_json($file_path, $ref)

Write a JSON file with exclusive file locking

=cut

sub write_json($file_path, $ref) {
	# If $ref is to a scalar then dereference it first
	if (ref $ref eq 'SCALAR') {
		$ref = $$ref;
	}

	# Open in append mode so that we can get a lock on the file before it is wiped
	open(my $OUT, ">>", $file_path) or die "Can't write to $file_path";

	# Get an exclusive lock on the file and the seek back to the start
	flock($OUT, LOCK_EX) or die "Can't get exclusive lock on $file_path";

	# Truncate any residual data in the file
	truncate($OUT, 0);

	my $json = $json_for_objects->encode($ref);
	# Strip out any nul characters as many parsers can't cope with these
	# This doesn't seem to add too much overhead
	$json =~ s/\000//g;
	print $OUT $json;

	# Release the lock. Some docs say this isn't needed but tests show otherwise
	flock($OUT, LOCK_UN);
	close($OUT);

	return;
}

=head2 write_canonical_json($file_path, $ref)

Write a JSON file in canonical, indented format without any file locking

=cut

sub write_canonical_json($file_path, $ref) {
	open(my $OUT, ">", $file_path) or die "Can't write to $file_path";
	print $OUT $json_for_config->encode($ref);
	close($OUT);
	return;
}

=head2 read_json_raw($file_path)

Reads from a JSON file with shared file locking. Note returns JSON string, not a hash. Dies on error

=cut

sub read_json_raw($file_path) {
	open(my $IN, "<", $file_path) or die("Can't open $file_path");
	flock($IN, LOCK_SH) or die "Can't get shared lock on $file_path";
	local $/;    #Enable 'slurp' mode
	my $json = <$IN>;
	# Release the lock. Some docs say this isn't needed but tests show otherwise
	flock($IN, LOCK_UN);
	close($IN);
	return $json;
}

=head2 read_json($file_path)

Reads from a JSON file with shared file locking. Returns a hash. Dies on error

=cut

sub read_json($file_path) {
	my $ref = $json_for_objects->decode(read_json_raw($file_path));
	# return a reference if it isn't one already
	if (ref $ref eq '') {
		return \$ref;
	}
	return $ref;
}

=head2 store_object ($path, $ref)

Serializes an object in our preferred object store, removing it from legacy storage if it is present.
Tries to emulate [Storable](https://metacpan.org/dist/Storable/source/Storable.pm) behavior
but uses die instead of croak

=cut

sub store_object ($path, $ref) {
	my $sto_path = $path . '.sto';
	my $file_path = $path . '.json';

	if (!-e $file_path || !-e $sto_path) {
		# If doesn't already exist ensure the directory tree is in place
		ensure_dir_created_or_die(dirname($file_path));
	}

	#11901: Always do this once production is migrated
	if (get_serialize_to_json_level() > 0) {
		if (!-e $file_path && -l $sto_path) {
			# JSON file does not currently exist and existing STO file is a symlink
			# In this case we need write the data to the JSON symlink target an then create the JSON symlink
			my $real_path = abs_path($sto_path);
			my $json_path = remove_extension($real_path) . '.json';

			# Write the data to the symlink target
			write_json($json_path, $ref);

			# Create the JSON symlink
			# Note we need to use a relative path for the link
			my $relative_path = remove_extension(readlink($sto_path)) . '.json';
			symlink($relative_path, $file_path);

			#11901: Always do this once production is migrated.
			if (get_serialize_to_json_level() == 2) {
				# Delete the real file. Symlink will be deleted further down
				unlink($real_path);
			}
		}
		else {
			# JSON symlink already exists or we are writing to a real file
			write_json($file_path, $ref);
		}
	}

	#11901: Remove once production is migrated and always do the else. Use STO file as well as JSON
	if (get_serialize_to_json_level() < 2) {
		store($sto_path, $ref);
	}
	else {
		# Remove the STO file if it exists
		if (-e ($sto_path)) {
			unlink($sto_path);
		}
	}

	return;
}

sub remove_extension($path) {
	return substr $path, 0, rindex($path, '.');
}

=head2 retrieve_object($path)

Fetch the JSON object from storage and return as a hash ref. Reverts to STO file if no JSON file exists.
Will die if JSON is malformed.

=cut

sub retrieve_object($path) {
	my $file_path = $path . '.json';
	my $sto_path = $path . '.sto';

	#11901: Remove once production is fully migrated. Use STO file as master source of truth if it exists
	if (-e $sto_path) {
		return retrieve($sto_path);
	}

	if (-e $file_path) {
		my $ref;
		# Carp on error to be consistent with retrieve
		eval {$ref = read_json($file_path);} or carp("cannot retrieve $file_path : $@");
		return $ref;
	}
	else {
		# If the old file is a link but the target no longer exists then assume the target has already been migrated to JSON
		if (-l $sto_path) {
			my $real_path = abs_path($sto_path);
			# print STDERR $real_path ."\n";
			if ($real_path) {
				# Can retrieve object on the real file which will return the JSON if it exists
				return retrieve_object(remove_extension($real_path));
			}
			else {
				die "retrieve_object unable to get real path from link: $sto_path";
			}
		}
		# Fallback to old method
		return retrieve($sto_path);
	}
}

=head2 retrieve_object_json($path)

Fetch the JSON object from storage and return as a JSON string. Reverts to STO file and serializes as JSON if no JSON file exists

=cut

sub retrieve_object_json($path) {
	my $file_path = $path . '.json';
	if (-e $file_path) {
		return read_json_raw($file_path);
	}
	# Fallback to old method
	return $json_for_objects->encode(retrieve($path . '.sto'));
}

=head2 object_exists($path)

Indicates whether an object (STO or JSON) exists at the specified path

=cut

sub object_exists($path) {
	return (-e "$path.json" or -e "$path.sto");
}

=head2 object_path_exists($path)

Indicates whether an directory exists at the specified path

=cut

sub object_path_exists($path) {
	return (-d $path);
}

=head2 move_object($old_path, $new_path)

Moves a single object or all objects in the path

=cut

sub move_object($old_path, $new_path) {
	# File::Copy move() is intended to move files, not
	# directories. It does work on directories if the
	# source and target are on the same file system
	# (in which case the directory is just renamed),
	# but fails otherwise.
	# An alternative is to use File::Copy::Recursive
	# but then it will do a copy even if it is the same
	# file system...
	# Another option is to call the system mv command.
	$log->debug("moving object data", {source => $old_path, destination => $new_path})
		if $log->is_debug();

	if (-d $old_path) {
		# Moving a while directory
		ensure_dir_created_or_die($new_path);
		#11872 TOD Should probably die here
		dirmove($old_path, $new_path)
			or $log->error("could not move objects", {source => $old_path, destination => $new_path, error => $!});

	}
	else {
		# Moving a single file
		ensure_dir_created_or_die(dirname($new_path));
		if (-e "$old_path.sto") {
			move("$old_path.sto", "$new_path.sto")
				or die("could not move sto file from $old_path.sto to $new_path.sto, error: $!");
		}
		elsif (not -e "$old_path.json") {
			# Dies if neither the sto or json file exist
			die("could not move from $old_path to $new_path, no sto or json file found");
		}
		if (-e "$old_path.json") {
			move("$old_path.json", "$new_path.json")
				or die("could not move json file from $old_path.json to $new_path.json, error: $!");
		}
	}

	return;
}

=head2 link_object($name, $link)

Makes the $link point to the data in the specified relative $path.
If the object at the $path is an sto file then an STO symbolic link will be created

=cut

sub link_object($name, $link) {
	my $dir = dirname($link);

	#11901: Always do this once production is migrated
	if (get_serialize_to_json_level() > 0) {
		my $real_json_path = "$dir/$name.json";

		# If the JSON target file doesn't exist then log an error, but still create the link anyway
		$log->error("link target does not exist", {link => $link, real_json_path => $real_json_path})
			if $log->is_error() && !-e $real_json_path;

		symlink($name . '.json', $link . '.json') or die("Cannot create link $link.json to $name.sto, error $!");
	}

	my $real_sto_path = "$dir/$name.sto";
	my $sto_link = "$link.sto";
	#11901: Remove get_serialize_to_json_level() part of expression once production is migrated and just create the STO link if the real STO file exists
	if (get_serialize_to_json_level() < 2 or -e $real_sto_path) {
		symlink($name . '.sto', $sto_link);
	}
	else {
		# Delete the STO link if it exists and the real file does not exist
		# We normally delete a link before creating a new one but just in case make sure there is no STO link
		if (-e $sto_link) {
			unlink($sto_link);
			$log->warn("previous link was not deleted", {link => $sto_link}) if $log->is_warn();
		}
	}

	return;
}

=head2 remove_object($path)

Removes an object or link to an object

=cut

sub remove_object($path) {
	unlink($path . '.json');
	# Remove any legacy sto file too
	unlink($path . '.sto');
	return;
}

=head2 object_iter($initial_path, $name_pattern = undef, $exclude_path_pattern = undef, $skip_until_path = undef)

Iterates over the path returning a cursor that can return object paths whose
name matches the $name_pattern regex and whose path does not match the $exclude_path_pattern.
If $skip_until_path is provided, skips all object paths that are lexicographically less than $skip_until_path.

=cut

sub object_iter($initial_path, $name_pattern = undef, $exclude_path_pattern = undef, $skip_until_path = undef) {
	my @dirs = ($initial_path);
	my @object_paths = ();
	return sub {
		if (scalar @object_paths == 0) {
			# explore a new dir until we get some file
			while ((scalar @object_paths == 0) && (scalar @dirs > 0)) {
				my $current_dir = shift @dirs;
				opendir(DIR, $current_dir) or die "Cannot open $current_dir\n";
				# Sort files so that we always explore them in the same order (useful for tests)
				my @candidates = sort readdir(DIR);
				closedir(DIR);
				my $last_name = '';
				foreach my $file (@candidates) {
					# avoid ..
					next if $file =~ /^\.\.?$/;
					# avoid conflicting-codes and invalid-codes
					next if $exclude_path_pattern and $file =~ $exclude_path_pattern;
					my $path = "$current_dir/$file";
					print STDERR "skip_until_path: $skip_until_path - current: $path\n";
					next if ((defined $skip_until_path) and ($path lt $skip_until_path) and not ();
					if (-d $path) {
						# explore sub dirs
						push @dirs, $path;
						next;
					}
					# Have a file. Strip off any extension before pattern matching
					my $object_name = remove_extension($file);

					# Skip if we have a duplicate file name with a different extension, e.g. if STO and JSON coexist during migration
					next if ($object_name eq $last_name);
					$last_name = $object_name;

					next if ($name_pattern and $object_name !~ $name_pattern);
					push(@object_paths, "$current_dir/$object_name");
				}
			}
		}
		# if we still have object_paths, return a name
		if (scalar @object_paths > 0) {
			return shift @object_paths;
		}
		else {
			# or end iteration
			return;
		}
	};
}

=head2 store_config ($path, $ref)

Serializes configuration information, removing it from legacy storage if it is present.
JSON keys are sorted and indentation is used so files can be used in source control
No locking is performed

=cut

sub store_config ($path, $ref) {
	my $sto_path = $path . '.sto';
	my $file_path = $path . '.json';

	#11901: Config files aren't shared so ignore get_serialize_to_json_level() flag. Just remove this comment when migration is complete

	ensure_dir_created_or_die(dirname($file_path));

	write_canonical_json($file_path, $ref);

	#11901: Can remove this once fully migrated: Delete the old storable file
	if (-e $sto_path) {
		unlink($sto_path);
	}

	return;
}

=head2 retrieve_config($path)

Same as retrieve_object but with no locking

=cut

sub retrieve_config($path) {
	my $file_path = $path . '.json';
	if (-e $file_path) {
		my $ref;
		eval {
			open(my $IN, "<", $file_path) or die("Can't open $file_path");
			local $/;    #Enable 'slurp' mode
			$ref = $json_for_config->decode(<$IN>);
			close($IN);
		} or carp("cannot retrieve_config $file_path : $@");
		return $ref;
	}
	# Fallback to old method
	return retrieve($path . '.sto');
}

1;
