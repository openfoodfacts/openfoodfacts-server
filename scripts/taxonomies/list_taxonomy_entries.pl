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

use Modern::Perl '2017';
use utf8;

my $usage = <<TXT
list_taxonomy_entries.pl - list taxonomy entries matching filters

Usage:

list_taxonomy_entries.pl --type ingredients --include_languages en,fr
-> list all ingredients, with columns for the English and French names

list_taxonomy_entries.pl --type ingredients --include_paths
-> list all ingredients, with a column for the name path (from the root of the taxonomy)

list_taxonomy_entries.pl --type ingredients --include_languages_paths en,fr
-> list all ingredients, with columns for the English and French name paths (from the root of the taxonomy)

Filter by property:

list_taxonomy_entries.pl --type ingredients --with-property vegan:en
-> list all ingredients that have a value for the vegan:en property

list_taxonomy_entries.pl --type ingredients --with-property vegan:en=yes
-> list all ingredients that have the value "yes" for the vegan:en property

list_taxonomy_entries.pl --type ingredients --without-property vegan:en
-> list all ingredients that do not have a value for the vegan:en property

list_taxonomy_entries.pl --type ingredients --without-property vegan:en=yes
-> list all ingredients that do not have the value "yes" for the vegan:en property

Filter by inherited property:

list_taxonomy_entries.pl --type ingredients --with-inherited-property vegan:en=yes
-> list all ingredients with an inherited value "yes" for the vegan:en property

list_taxonomy_entries.pl --type ingredients --without-inherited-property vegan:en
-> list all ingredients that do not have an inherited value for the vegan:en property

Filter by canonical entry name:

list_taxonomy_entries.pl --type categories --canonical-regexp 'en:bread'
-> list all categories whose canonical tagid matches the regex

Combine filters:

list_taxonomy_entries.pl --type categories --with-property gpc_category_code:en --canonical-regexp 'en:bread'
-> list categories that have a gpc_category_code and whose canonical name matches 'en:bread'

Example:

./scripts/taxonomies/list_taxonomy_entries.pl --type categories --include_languages en --include_languages_path en --include_properties ciqual_food_code:en,ciqual_proxy_food_code:en --include_inherited_properties ciqual_food_code:en,ciqual_proxy_food_code:en | grep "en:"
TXT
	;

binmode(STDIN, ":encoding(UTF-8)");
binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Tags qw/:all/;

use Getopt::Long;

my $tagtype;
my $canonical_regexp;
my @with_properties;
my @without_properties;
my @with_inherited_properties;
my @without_inherited_properties;
my $include_paths;
my $include_languages;
my $include_languages_paths;
my $include_properties;
my $include_inherited_properties;

GetOptions(
	"type=s" => \$tagtype,    # string
	"canonical-regexp=s" => \$canonical_regexp,
	"with-property=s@" => \@with_properties,
	"without-property=s@" => \@without_properties,
	"with-inherited-property=s@" => \@with_inherited_properties,
	"without-inherited-property=s@" => \@without_inherited_properties,
	"include_paths" => \$include_paths,
	"include_languages=s" => \$include_languages,
	"include_languages_paths=s" => \$include_languages_paths,
	"include_properties=s" => \$include_properties,
	"include_inherited_properties=s" => \$include_inherited_properties,
) or die("Error in command line arguments:\n\n$usage\n");

if (not defined $tagtype) {
	die("missing the taxonomy type argument.\n\n$usage\n");
}
elsif (defined $translations_to{$tagtype}) {

	# Ouput the header line
	my @header = ("id");
	# Taxonomy entries in different languages
	if (defined $include_languages) {
		foreach my $target_lc (split(/,/, $include_languages_paths)) {
			push @header, "name_$target_lc";
		}
	}
	# Taxonomy paths (id + different languages)
	if (defined $include_paths) {
		push @header, "path";
	}
	if (defined $include_languages_paths) {
		foreach my $target_lc (split(/,/, $include_languages_paths)) {
			push @header, "path_$target_lc";
		}
	}
	# Properties
	if (defined $include_properties) {
		foreach my $property (split(/,/, $include_properties)) {
			push @header, "property_$property";
		}
	}
	# Inherited properties
	if (defined $include_inherited_properties) {
		foreach my $property (split(/,/, $include_inherited_properties)) {
			push @header, "inherited_property_$property";
		}
	}
	print join("\t", @header), "\n";

	foreach my $tagid (sort keys %{$translations_to{$tagtype}}) {
		# Skip synonyms
		next if ((exists $just_synonyms{$tagtype}) and (exists $just_synonyms{$tagtype}{$tagid}));

		my $match = 1;

		# Canonical regexp filter
		if (defined $canonical_regexp) {
			if ($tagid !~ /$canonical_regexp/) {
				$match = 0;
				next;
			}
		}

		# With properties
		foreach my $property_spec (@with_properties) {
			my ($property, $expected_value) = split(/=/, $property_spec, 2);
			my $value = get_property($tagtype, $tagid, $property);

			if (not defined $expected_value) {
				# just check existence
				if (not defined $value) {
					$match = 0;
					last;
				}
			}
			elsif ($expected_value eq 'exists') {
				if (not defined $value) {
					$match = 0;
					last;
				}
			}
			elsif ($expected_value eq 'null') {
				if (defined $value) {
					$match = 0;
					last;
				}
			}
			elsif ($expected_value =~ /^-/) {
				if ((defined $value) and ($value eq $')) {
					$match = 0;
					last;
				}
			}
			elsif ((not defined $value) or ($value ne $expected_value)) {
				$match = 0;
				last;
			}
		}

		# Without properties
		foreach my $property_spec (@without_properties) {
			my ($property, $forbidden_value) = split(/=/, $property_spec, 2);
			my $value = get_property($tagtype, $tagid, $property);

			if (not defined $forbidden_value) {
				# must not have the property at all
				if (defined $value) {
					$match = 0;
					last;
				}
			}
			elsif ($forbidden_value eq 'exists') {
				if (defined $value) {
					$match = 0;
					last;
				}
			}
			elsif ($forbidden_value eq 'null') {
				if (not defined $value) {
					$match = 0;
					last;
				}
			}
			elsif ($forbidden_value =~ /^-/) {
				if ((defined $value) and ($value eq $')) {
					$match = 0;
					last;
				}
			}
			elsif ((defined $value) and ($value eq $forbidden_value)) {
				$match = 0;
				last;
			}
		}

		# With inherited properties
		foreach my $property_spec (@with_inherited_properties) {
			my ($property, $expected_value) = split(/=/, $property_spec, 2);
			my $value = get_inherited_property($tagtype, $tagid, $property);

			if (not defined $expected_value) {
				# just check existence
				if (not defined $value) {
					$match = 0;
					last;
				}
			}
			elsif ($expected_value eq 'exists') {
				if (not defined $value) {
					$match = 0;
					last;
				}
			}
			elsif ($expected_value eq 'null') {
				if (defined $value) {
					$match = 0;
					last;
				}
			}
			elsif ($expected_value =~ /^-/) {
				if ((defined $value) and ($value eq $')) {
					$match = 0;
					last;
				}
			}
			elsif ((not defined $value) or ($value ne $expected_value)) {
				$match = 0;
				last;
			}
		}

		# Without inherited properties
		foreach my $property_spec (@without_inherited_properties) {
			my ($property, $forbidden_value) = split(/=/, $property_spec, 2);
			my $value = get_inherited_property($tagtype, $tagid, $property);

			if (not defined $forbidden_value) {
				# must not have the property at all
				if (defined $value) {
					$match = 0;
					last;
				}
			}
			elsif ($forbidden_value eq 'exists') {
				if (defined $value) {
					$match = 0;
					last;
				}
			}
			elsif ($forbidden_value eq 'null') {
				if (not defined $value) {
					$match = 0;
					last;
				}
			}
			elsif ($forbidden_value =~ /^-/) {
				if ((defined $value) and ($value eq $')) {
					$match = 0;
					last;
				}
			}
			elsif ((defined $value) and ($value eq $forbidden_value)) {
				$match = 0;
				last;
			}
		}

		if ($match) {
			my @values = ($tagid);

			# Taxonomy entries in different languages
			if (defined $include_languages) {
				foreach my $target_lc (split(/,/, $include_languages_paths)) {
					my $name = display_taxonomy_tag_name($target_lc, $tagtype, $tagid);
					push @values, (defined $name) ? $name : '';
				}
			}

			# Taxonomy paths (id + different languages)
			if (defined $include_paths) {
				my $path_ref = get_taxonomy_tag_path($tagtype, $tagid);
				push @values, (defined $path_ref) ? join(" > ", @$path_ref) : '';
			}
			if (defined $include_languages_paths) {
				my $path_ref = get_taxonomy_tag_path($tagtype, $tagid);

				foreach my $target_lc (split(/,/, $include_languages_paths)) {

					push @values,
						(defined $path_ref)
						? join(" > ", map {display_taxonomy_tag_name($target_lc, $tagtype, $_)} @$path_ref)
						: '';
				}
			}

			# Properties
			if (defined $include_properties) {
				foreach my $property (split(/,/, $include_properties)) {
					my $value = get_property($tagtype, $tagid, $property);
					push @values, (defined $value) ? $value : '';
				}
			}
			# Inherited properties
			if (defined $include_inherited_properties) {
				foreach my $property (split(/,/, $include_inherited_properties)) {
					my $value = get_inherited_property($tagtype, $tagid, $property);
					push @values, (defined $value) ? $value : '';
				}
			}

			print join("\t", @values), "\n";
		}
	}
}
else {
	die("$tagtype is not an existing built taxonomy\n\n$usage\n");
}

exit(0);
