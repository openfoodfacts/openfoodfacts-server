# WORK IN PROGRESS (L. Dami april 2024)
#
# This script transforms ProductOpener from the old modperl architecture to a new Catalyst app.
#
# CGI scripts become Catalyst controllers.
# Calls to CGI methods or modperl methods become calls to the catalyst objects ($c->req, $c->response, etc.)


use 5.32.0;
use utf8;
use strict;
use warnings;
use feature 'signatures';
use Path::Tiny;
use FindBin qw/$Bin/;
use Template;
use Catalyst::Devel;

my $appname = "ProductOpenerApp";


# go to root of repository
my $repo_root = path($Bin)->parent(2)->stringify;
chdir $repo_root or die $!;

# remove files generated from previous attempts
-d $appname and path($appname)->remove_tree;

# let Catalyst create initial application files
my $cata_cmd = $^O eq 'MSWin32' ? 'catalyst' : 'catalyst.pl';
warn "creating Catalyst app $appname\n";
system "$cata_cmd -force $appname";


# local module to simulate a production environment
create_local_env_module($repo_root, $appname);

# add some config and subclass information within the main module
customize_main_application_module($appname);


# additional local libraries to load in scripts created by Catalyst
my @more_libs = ("$repo_root/lib", "d:/Git/openfoodfacts/perl_code_analysis/local_lib");
my $use_more_libs = join "\n", map {qq{use lib "$_";}} @more_libs;
for my $script (path($appname)->child("script")->children) {
	warn "adding 'use lib ...' into $script\n";
	path($script)->edit_utf8(sub {
		s{^use Catalyst::ScriptRunner;}{$use_more_libs\n$&}m;
	});
}

my %redirected_scripts = (
	"product.pl"      => "product_multilingual.pl",
	"product_jqm.pl"  => "product_jqm_multilingual.pl",
	"product_jqm2.pl" => "product_jqm_multilingual.pl",
   );
my %is_redirected_script = reverse %redirected_scripts;


# let Catalyst create controllers for each existing cgi script
my $create_script = "$appname/script/\L$appname\E_create.pl";
my @cgi_files = path("cgi")->children(qr/\.pl$/);
CGI:
foreach my $cgi (@cgi_files) {

	my $basename = $cgi->basename;
	next CGI if $is_redirected_script{$basename};
	my $source = $redirected_scripts{$basename} // $basename;

	# let Catalyst create the controller
	my $controller = ucfirst($basename) =~ s/\.pl$//r;
	my $command = "$create_script controller $controller";
	warn "$command\n";
	system "perl $command";

	# read the old CGI, split the content
	my $cgi_content = path("cgi/$source")->slurp_utf8;
	my ($preamble, $used_modules) = ("", "");
	$cgi_content =~ s{\A(.*?)^use}{use}ms                           and $preamble     = $1;
	$cgi_content =~ s{\A( (?: (?: use\h [^;]+;\h* | \h*) \n)* )}{}x and $used_modules = $1;

	# remove imports of CGI or modperl modules
	$used_modules =~ s{^use (CGI|Apache2).*\n}{}gm;

	# load HTTP::Status
	substr $used_modules, 0, 0, qq{use HTTP::Status ();\n};

	# TMP HACK TO SEE THE LOADING ORDER
	substr $used_modules, 0, 0, qq{warn "loading old CGI $cgi\\n";\n};

	# replace old calls to CGI or modperl subs by Catalyst methods
	replace_CGI_or_modperl_calls(\$cgi_content);

	# indent the old code
	$cgi_content =~ s{^([^\n])}{\t$1}gm;
	$cgi_content =~ s{<<\h*}{<<~}g; # so that heredocs still work with the new indentation
	# TODO : DO NOT INDENT POD + HANDLE SUBS


	# merge the old code into the Catalyst controller
	my $controller_file = "$appname/lib/$appname/Controller/$controller.pm";
	path($controller_file)->edit_utf8(sub{
			s{\A(.*?)use namespace}{$preamble$1$used_modules\nuse namespace}s;
			s{^\h+\$c->response->body.*}{$cgi_content}m;
		});
}

say "done";



sub replace_CGI_or_modperl_calls($old_code_ref) {
	for ($$old_code_ref) {
		s{single_param\(}         	   	 {\$c->req->single_param(}g;
		s{request_param\(}        	   	 {\$c->req->request_param(}g;
		s{\$ENV\{'REQUEST_METHOD'\}}   	 {\$c->req->method}g;
		s{\$r->method\(\)}             	 {\$c->req->method}g;
		s{\$r->status\(}          	   	 {\$c->response->status(}g;
		s{\$r->headers_in->\{Referer\}}	 {\$c->req->headers->referer}g;
		s{\$r->headers_out->set\(}	   	 {\$c->response->header(}g;
		s{\bexit\(\d*\)}          	   	 {\$c->detach}g;              # THINK : what to do if the number is not 0 ?
		s{return (Apache2::Const::)?OK\b}{return}g;                   # Catalyst doesn't need a return value from an action
		s{\$->rflush;}                 	 {}g;                         # Catalyst will take care of the flushing
		s{\$log\b}                     	 {\$c->log}g;                 # logging through the Catalyst logger
		s{\(HTTP_}                     	 {(HTTP::Status::HTTP_}g;     # constants from HTTP::Status

		# TODO : catch print statements, distinguish between headers and body


		# warn about remaining modperl calls
		warn "OLD_CGI_MODPERL: $1\n" while m/(\$r->\S+)/g;
		warn "OLD_CGI_MODPERL: $1\n" while m/(\bprint.*)/g;
	}
}






sub customize_main_application_module($appname) {
	
	# edit the application class
	path("$appname/lib/$appname.pm")->edit_utf8(sub{

			# tell the main App class that we have a custom Request class
			s{# Start the application}{use ${appname}::Request;\n__PACKAGE__->request_class("${appname}::Request");\n\n# Start the application};

			# tell Catalyst that this app is running behind a frontend proxy
			s{name => '$appname',}{$&\n\tusing_frontend_proxy => 1,};

			# insert our localized hacks before application setup
			s{__PACKAGE__->setup\(\);}{use LocalHackEnv;\n$&};

		});

	# write the custom Request class with backcompat methods 'single_param()' and 'request_param()'
	my $req_class_content = <<~'__END_OF_MODULE__';
        package [% appname %]::Request;
        use Moose;
        use ProductOpener::PerlStandards;
        use namespace::autoclean;
        BEGIN {extends 'Catalyst::Request';}
        # compatibility methods for old way of accessing params in ProductOpener
        sub single_param($self, $key)  {scalar $self->param($key)}
        sub request_param($self, $key) {scalar $self->param($key) // $self->body_data->{$key}}
        1;
        __END_OF_MODULE__
	Template->new->process(\$req_class_content, {appname => $appname}, \my $output);
	path("$appname/lib/$appname/Request.pm")->spew_utf8($output);
}


sub create_local_env_module($repo_root, $appname) {

	my $git_off_web_dir = path($repo_root)->parent->child("openfoodfacts-web");
	$git_off_web_dir->is_dir or die "did not find the openfoodfacts-web dir";
	my $git_off_web_path = $git_off_web_dir->absolute->stringify;


    my $local_env_module_content = <<~'__END_OF_MODULE__';
        # steal from the .env docker file to populate env variables in memory
        open my $fh, "<", "[% repo_root %]/.env" or die $!;
        while (<$fh>) {
            chomp;
            if (/^(\w+)=(.*)/) {
                $ENV{$1}=$2;
            }
        }
        
        # additional env vars
        $ENV{PRODUCT_OPENER_FLAVOR_SHORT}='off';
        $ENV{BUILD_CACHE_REPO}='/home/off/build-cache';  # TOCLARIFY : should it be a relative path?

        
        # those env vars must be defined to prevent warnings
        $ENV{$_} = "" for qw/SCRIPT_NAME QUERY_STRING HTTP_USER_AGENT/;
        
        # where the app will find files from the openfoodfacts-web repository
        require ProductOpener::Config;
        $ProductOpener::Config::www_root = '[% git_off_web_path %]';
        require ProductOpener::Paths;
        $ProductOpener::Paths::BASE_DIRS{LANG} = '[% repo_root %]/taxonomies';
        __END_OF_MODULE__


	my %vars = (repo_root => $repo_root, git_off_web_path => $git_off_web_path);
	Template->new->process(\$local_env_module_content, \%vars, \my $output);
	path("$appname/lib/LocalHackEnv.pm")->spew_utf8($output);

}


__END__

TODO

  - add "use lib ..." to all scripts.
  - ADD d:/Git/openfoodfacts/perl_code_analysis/local_lib

	$r->err_headers_out->add('Set-Cookie' => $request_ref->{cookie});


