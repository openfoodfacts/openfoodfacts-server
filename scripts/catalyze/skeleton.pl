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
chdir path($Bin)->parent(2) or die $!;

# remove files generated from previous attempts
-d $appname and path($appname)->remove_tree;

# let Catalyst create initial application files
my $cata_cmd = $^O eq 'MSWin32' ? 'catalyst' : 'catalyst.pl';
warn "creating Catalyst app $appname\n";
system "$cata_cmd -force $appname";

# add some config and subclass information within the main moudule
customize_main_application_module();

# let Catalyst create controllers for each existing cgi script
my $create_script = "$appname/script/\L$appname\E_create.pl";
my @cgi_files = path("cgi")->children(qr/\.pl$/);
foreach my $cgi (@cgi_files) {

	# let Catalyst create the controller
	my $controller = ucfirst($cgi->relative("cgi")) =~ s/\.pl$//r;
	warn "creating controller $controller\n";
	my $command = "$create_script controller $controller";
	system "perl $command";

	# read the old CGI, split the content
	my $cgi_content = path($cgi)->slurp_utf8;
	my ($preamble, $used_modules) = ("", "");
	$cgi_content =~ s{\A(.*?)^use}{use}ms                   and $preamble = $1;
	$cgi_content =~ s{\A( (?: (?: use\h.* | \h*) \n)* )}{}x and $used_modules = $1;

	# remove imports of CGI or modperl modules
	$used_modules =~ s{^use (CGI|Apache2).*\n}{}gm;

	remove_CGI_or_modperl_calls(\$cgi_content);

	# indent the old code
	$cgi_content =~ s{^([^\n])}{\t$1}gm;

	# merge the old code into the Catalyst controller
	my $controller_file = "$appname/lib/$appname/Controller/$controller.pm";
	path($controller_file)->edit_utf8(sub{
			s{\A(.*?)use namespace}{$preamble$1$used_modules\nuse namespace}s;
			s{^\h+\$c->response->body.*}{$cgi_content}m;
		});
}

say "done";



sub remove_CGI_or_modperl_calls($old_code_ref) {
	for ($$old_code_ref) {
		s{single_param\(}         	   {\$c->req->single_param(}g;
		s{request_param\(}        	   {\$c->req->request_param(}g;
		s{\$ENV\{'REQUEST_METHOD'\}}   {\$c->req->method}g;
		s{\$r->method\(\)}             {\$c->req->method}g;
		s{\$r->status\(}          	   {\$c->response->status(}g;
		s{\$r->headers_in->\{Referer\}}{\$c->req->headers->referer}g;
		s{\$r->headers_out->set\(}	   {\$c->response->header(}g;
		s{\bexit\(\d*\)}          	   {\$c->detach}g;  # THINK : what to do if the number is not 0 ?
		s{return Apache2::Const::OK}   {return}g;       # Catalyst doesn't need a return value from an action
		s{\$->rflush;}                 {}g;             # Catalyst will take care of the flushing
		s{\$log\b}                     {\$c->log}g;     # logging through the Catalyst logger

		# TODO : catch print statements, distinguish between headers and body


		# warn about remaining modperl calls
		warn "OLD_CGI_MODPERL: $1\n" while m/(\$r->\S+)/g;
		warn "OLD_CGI_MODPERL: $1\n" while m/(\bprint.*)/g;
	}
}





# need our own request class with backcompat methods 'single_param()' and 'request_param()'



sub customize_main_application_module {

	
	path("$appname/lib/$appname.pm")->edit_utf8(sub{

			# tell the main App class that we have a custom Request class
			s{# Start the application}{__PACKAGE__->request_class("${appname}::Request");\n\n# Start the application};

			# tell Catalyst that this app is running behind a frontend proxy
			s{name => '$appname',}{$&\n\tusing_frontend_proxy => 1,}
		});

	# write the custom Request class
	my $req_class_content = <<~'__CLASS__';
        package ${appname}::Request;
        use Moose;
        use ProductOpener::PerlStandards;
        use namespace::autoclean;
        BEGIN {extends 'Catalyst::Request';}
        # compatibility methods for old way of accessing params in ProductOpener
        sub single_param($self, $key)  {scalar $self->param($key)}
        sub request_param($self, $key) {scalar $self->param($key) // $self->body_data->{$key}}
        1;
        __CLASS__
	Template->new->process(\$req_class_content, {appname => $appname}, \my $output);
	path("$appname/lib/$appname/Request.pm")->spew_utf8($output);
}


	




__END__

TODO



		$r->err_headers_out->add('Set-Cookie' => $request_ref->{cookie});


