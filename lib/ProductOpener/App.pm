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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::App - the ProductOpener application

=head1 DESCRIPTION

An instance of this class is created at application startup time.
The object holds long-term information, like for example
paths to various directories.

Short-term information related to the HTTP request lifecycle
should go into L<ProductOpener::Controller> or its subobjects
(L<ProductOpener::Request>, L<ProductOpener::Response>). 


=cut

package ProductOpener::App;
use ProductOpener::PerlStandards;

sub new($class) {

	my $self = bless {}, $class;

	$self->init_file_timestamps;




	# On demand exports can be very big, limit the number of products
	$self->{export_limit} = 10000;

	# TODO: explain why such a high number
	$self->{tags_page_size} = 10000;

	if (defined $options{export_limit}) {
		$self->{export_limit} = $options{export_limit};
	}

	# Save all tag types to index in a set to make checks easier
	$self->{index_tag_types_set}{$_} = undef foreach @ProductOpener::Config::index_tag_types;


	$self->{default_request_ref} = {page => 1,};



	$self->{static_subdomain} = format_subdomain('static');
	$self->{images_subdomain} = format_subdomain('images');




	return $self;
}


# sub get_world_subdomain() {
# 	my $prefix = ($lc eq "en") ? "world" : "world-$lc";
# 	return format_subdomain($prefix);
# }



=head2 TODO REWRITE DOC %file_timestamps

When the module is loaded (at the start of Apache with mod_perl), we record the modification date
of static files like CSS styles an JS code so that we can add a version parameter to the request
in order to make sure the browser will not serve an old cached version.

=head3 Synopsis

    $scripts .= <<HTML
        <script type="text/javascript" src="/js/dist/product-multilingual.js?v=$file_timestamps{"js/dist/product-multilingual.js"}"></script>
    HTML
    ;

=cut


sub init_file_timestamps($self) {

	state @files_generated_by_npm_run_build = (
		"css/dist/app-ltr.css",
		"css/dist/app-rtl.css",
		"css/dist/product-multilingual.css",
		"js/dist/product-multilingual.js",
	   );



	my $start_time = time();

	foreach my $file (@files_generated_by_npm_run_build) {

		if (-e "$www_root/$file") {
			$self->{file_timestamp}{$file} = (stat "$www_root/$file")[9];
		}
		else {
			#$log->trace("A timestamped file does not exist. Falling back to process start time, in case we are running in different Docker containers.", { path => "$www_root/$file", source => $file_timestamps{$file}, fallback => $start_time }) if $log->is_trace();
			$self->{file_timestamp}{$file} =  $start_time;
	}
}





1;
