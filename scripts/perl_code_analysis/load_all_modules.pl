# Load all modules without running them, just for compile check, from the current Git working copy
use 5.24.0;
use utf8;
use strict;
use warnings;
use lib "../../lib";
use lib "local_lib";

use Module::Load qw/load/;
use Path::Tiny;
use Getopt::Long;
use File::Find::Rule;

BEGIN {
	# steal from the .env docker file to populate env variables in memory
	open my $fh, "<", "../../.env" or die $!;
	while (<$fh>) {
		chomp;
		if (/^(\w+)=(.*)/) {
			$ENV{$1}=$2;
		}
	}

	# additional env var
	$ENV{PRODUCT_OPENER_FLAVOR_SHORT}='off';


	# those env vars must be defined to prevent warnings
	$ENV{$_} = "" for qw/SCRIPT_NAME QUERY_STRING HTTP_USER_AGENT/;


	# make sure we have a local_lib/ProductOpener directory
	path("local_lib/ProductOpener")->mkdir;

	# create 'HackGlobalVars.pm' module
	my $git_off_web_dir = path("../../../openfoodfacts-web");
	$git_off_web_dir->is_dir or die "did not find the openfoodfacts-web dir";
	my $absolute_path = $git_off_web_dir->absolute;
	path("local_lib/HackGlobalVars.pm")->spew_utf8(<<~_EOF_);
      	package HackGlobalVars;
      	use strict;
      	use warnings;
      	use ProductOpener::Config qw/\$www_root/;
      	use ProductOpener::Paths  qw/%BASE_DIRS/;
      	\$BASE_DIRS{LANG} = '$absolute_path';
      	\$www_root = '$absolute_path';
      	1;
      	_EOF_

	# hack Config_off.pm source
	my $config_off = path("../../lib/ProductOpener/Config_off.pm")->slurp_utf8;
	$config_off =~  s{\$build_cache_repo = }
					 {\$build_cache_repo = "openfoodfacts/openfoodfacts-build-cache"; # };
	path("local_lib/ProductOpener/Config_off.pm")->spew_utf8($config_off);

	# hack Path.pm source
	my $paths_pm = path("../../lib/ProductOpener/Paths.pm")->slurp_utf8;
	$paths_pm =~   s{_source_dir\(\) . "/taxonomies"}
					{_source_dir() . "/../taxonomies"; # };
	path("local_lib/ProductOpener/Paths.pm")->spew_utf8($paths_pm);


	# override global exit so that cgi scripts loaded through "do" don't stop the whole thing
	*CORE::GLOBAL::exit = sub(;$) {
		warn "EXIT_OVERRIDE\n";
	};

}

use HackGlobalVars;

GetOptions \my %opt,
  'mod=s@{,}',    # modules to load
  'cgi=s@{,}',    # cgi scripts
  'script=s@{,}', # cmdline scripts
  'test=s@{,}',   # tests
  ;

$opt{mod}    //= [ map {my ($mod) = $_ =~ m[^.*/(.*?)\.pm$]; $mod} glob "../../lib/ProductOpener/*.pm"];
$opt{cgi}    //= [glob "../../cgi/*.pl"];
$opt{script} //= [grep {!/obsolete/} File::Find::Rule->name(qr/\.pl$/)->in("../../scripts")];
$opt{test}   //= [File::Find::Rule->name(qr/\.t$/)->in("../../tests")];


# load all ProductOpener modules
foreach my $mod (map {"ProductOpener::$_"} sort $opt{mod}->@*) {
	warn "loading $mod\n";
	load $mod;
}
warn "MODULES OK\n";


# warn "LOADING cgi\n"    and load_files($opt{cgi}->@*);
# warn "LOADING script\n" and load_files($opt{script}->@*);
# warn "LOADING test\n"   and load_files($opt{test}->@*);

sub load_files {

	foreach my $file (@_) {
		warn "loading $file\n";
		my ($out, $err);
		{
			local *STDOUT;	open(STDOUT, ">", \ $out) or die $!;
			local *STDERR;	open(STDERR, ">", \ $err) or die $!;

			use English; local $COMPILING = 1; do $file;
		}

		my $probl = $@ // $!;
		warn "FAIL : $probl\n" if $probl;
	}

	# warn $err if $err;
}

