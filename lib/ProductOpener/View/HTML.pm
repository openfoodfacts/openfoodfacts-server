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

ProductOpener::View::HTML - HTTP response as HTML

=cut

package ProductOpener::View::HTML;
use ProductOpener::PerlStandards;



# Initialize the Template module
$tt = Template->new(
	{
		INCLUDE_PATH => $data_root . '/templates',
		INTERPOLATE => 1,
		EVAL_PERL => 1,
		STAT_TTL => 60,    # cache templates in memory for 1 min before checking if the source changed
		COMPILE_EXT => '.ttc',    # compile templates to Perl code for much faster reload
		COMPILE_DIR => $data_root . "/tmp/templates",
		ENCODING => 'UTF-8',
	}
);



=head2 process_template ( $template_filename , $template_data_ref , $result_content_ref )

Add some functions and variables needed by many templates and process the template with template toolkit.

=cut

sub TODO_process_template ($template_filename, $template_data_ref, $result_content_ref) {

	# Add functions and values that are passed to all templates

	$template_data_ref->{server_options_private_products} = $server_options{private_products};
	$template_data_ref->{server_options_producers_platform} = $server_options{producers_platform};
	$template_data_ref->{producers_platform_url} = $producers_platform_url;
	$template_data_ref->{server_domain} = $server_domain;
	$template_data_ref->{static_subdomain} = $static_subdomain;
	$template_data_ref->{images_subdomain} = $images_subdomain;
	$template_data_ref->{formatted_subdomain} = $formatted_subdomain;
	(not defined $template_data_ref->{user_id}) and $template_data_ref->{user_id} = $User_id;
	(not defined $template_data_ref->{user}) and $template_data_ref->{user} = \%User;
	(not defined $template_data_ref->{org_id}) and $template_data_ref->{org_id} = $Org_id;

	$template_data_ref->{product_type} = $options{product_type};
	$template_data_ref->{admin} = $admin;
	$template_data_ref->{moderator} = $User{moderator};
	$template_data_ref->{pro_moderator} = $User{pro_moderator};
	$template_data_ref->{sep} = separator_before_colon($lc);
	$template_data_ref->{lang} = \&lang;
	$template_data_ref->{f_lang} = \&f_lang;
	# escaping quotes for use in javascript or json
	# using short names to favour readability
	$template_data_ref->{esq} = sub {escape_char(@_, "\'")};    # esq as escape_single_quote_and_newlines
	$template_data_ref->{edq} = sub {escape_char(@_, '"')};    # edq as escape_double_quote
	$template_data_ref->{lang_sprintf} = \&lang_sprintf;
	$template_data_ref->{lc} = $lc;
	$template_data_ref->{cc} = $cc;
	$template_data_ref->{display_icon} = \&display_icon;
	$template_data_ref->{time_t} = time();
	$template_data_ref->{display_date_without_time} = \&display_date_without_time;
	$template_data_ref->{display_date_ymd} = \&display_date_ymd;
	$template_data_ref->{display_date_tag} = \&display_date_tag;
	$template_data_ref->{url_for_text} = \&url_for_text;
	$template_data_ref->{product_url} = \&product_url;
	$template_data_ref->{product_action_url} = \&product_action_url;
	$template_data_ref->{product_name_brand_quantity} = \&product_name_brand_quantity;
	$template_data_ref->{has_permission} = sub ($permission) {
		# Note: we pass a fake $request_ref object with only the fields admin, moderator and pro_moderator
		# an alternative would be to pass the $request_ref object to process_template() calls
		return has_permission({admin => $admin, moderator => $User{moderator}, pro_moderator => $User{pro_moderator}},
			$permission);
	};

	# select2 options generator for all entries in a taxonomy
	$template_data_ref->{generate_select2_options_for_taxonomy_to_json} = sub ($tagtype) {
		return generate_select2_options_for_taxonomy_to_json($lc, $tagtype);
	};

	# Return a link to one taxonomy entry in the target language
	$template_data_ref->{canonicalize_taxonomy_tag_link} = sub ($tagtype, $tag) {
		return canonicalize_taxonomy_tag_link($lc, $tagtype, $tag);
	};

	# Display one taxonomy entry in the target language
	$template_data_ref->{display_taxonomy_tag} = sub ($tagtype, $tag) {
		return display_taxonomy_tag($lc, $tagtype, $tag);
	};

	# Display one taxonomy entry in the target language, without language prefix
	$template_data_ref->{display_taxonomy_tag_name} = sub ($tagtype, $tag) {
		return display_taxonomy_tag_name($lc, $tagtype, $tag);
	};

	# Display a list of taxonomy entries in the target language
	$template_data_ref->{display_taxonomy_tags_list} = sub ($tagtype, $tags_ref) {
		if (defined $tags_ref) {
			return join(", ", map {display_taxonomy_tag($lc, $tagtype, $_)} @$tags_ref);
		}
		else {
			return "";
		}
	};

	$template_data_ref->{round} = sub ($var) {
		return sprintf("%.0f", $var);
	};
	$template_data_ref->{sprintf} = sub ($var1, $var2) {
		return sprintf($var1, $var2);
	};

	$template_data_ref->{encode_json} = sub ($var) {
		return decode_utf8(JSON::PP->new->utf8->canonical->encode($var));
	};

	return ($tt->process($template_filename, $template_data_ref, $result_content_ref));
}




1;

