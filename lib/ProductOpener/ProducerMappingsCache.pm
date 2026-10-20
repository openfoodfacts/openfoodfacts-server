package ProductOpener::ProducerMappingsCache;

use ProductOpener::PerlStandards;
use Exporter qw/import/;
use Digest::SHA;
use File::Temp qw/tempfile/;

our @EXPORT_OK = qw/mappings_cache_valid write_mappings_cache_manifest/;

# A successful build must contain exactly one nonempty JSON file per current language.
sub mappings_manifest ($directory, $key, $languages_ref) {

	return if not $key or not @{$languages_ref};
	my @expected = sort map {"$_.json"} @{$languages_ref};
	opendir(my $directory_handle, "$directory/fields_column_names") or return;
	my @actual = sort grep {$_ ne '.' and $_ ne '..'} readdir($directory_handle);
	closedir($directory_handle);
	return if join("\n", @actual) ne join("\n", @expected);

	my @manifest = ($key);
	foreach my $filename (@expected) {
		my $path = "$directory/fields_column_names/$filename";
		return if not -f $path or -l $path or not -s $path;
		open(my $file, '<:raw', $path) or return;
		my $digest = Digest::SHA->new(256)->addfile($file)->hexdigest();
		close($file) or return;
		push @manifest, "$filename\t$digest";
	}
	return join("\n", @manifest) . "\n";
}

sub mappings_cache_valid ($directory, $key, $languages_ref) {

	open(my $file, '<:raw', "$directory/manifest.sha256") or return 0;
	my $saved_key = <$file>;
	return 0 if not defined $saved_key or $saved_key ne "$key\n";
	local $/;
	my $saved_manifest = $saved_key . (<$file> // '');
	close($file) or return 0;
	my $current_manifest = mappings_manifest($directory, $key, $languages_ref);
	return (defined $current_manifest and $saved_manifest eq $current_manifest);
}

sub write_mappings_cache_manifest ($directory, $key, $languages_ref) {

	my $manifest = mappings_manifest($directory, $key, $languages_ref)
		// die("Producer mappings are incomplete; refusing to cache them\n");
	my ($file, $temporary_path) = tempfile('manifest-XXXXXX', DIR => $directory, UNLINK => 1);
	binmode($file, ':raw') or die("Cannot set manifest encoding: $!\n");
	print {$file} $manifest or die("Cannot write producer mappings manifest: $!\n");
	close($file) or die("Cannot close producer mappings manifest: $!\n");
	rename($temporary_path, "$directory/manifest.sha256") or die("Cannot install producer mappings manifest: $!\n");
	return;
}

1;
