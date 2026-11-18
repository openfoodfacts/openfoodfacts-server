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

=head1 NAME

ProductOpener::TagsRules - add tags to products with rules defined in YAML files

=head1 SYNOPSIS

	use ProductOpener::TagsRules qw/:all/;

	# Pure evaluation (no writes), e.g. for a dry run on a dump
	my $result_ref = evaluate_tags_rules($product_ref);
	# $result_ref->{added}{categories}{"en:caffeinated-colas"} = ["colas-caffeinated"]

	# Evaluate and store the added tags in the "rules" source of tags_sources
	apply_tags_rules_to_product($product_ref);

=head1 DESCRIPTION

Tags rules add more precise tags (e.g. categories) to products, from data that is already on the product:
categories, ingredients, labels, countries, brands, nutrients, product names and ingredients lists.

Rules are stored in YAML files in the rules/ directory, grouped by product type and by target field,
e.g. rules/food/categories/beverages.yml.

docs/dev/explain-tags-rules.md explains the format of the rules files (each field of a rule, the conditions
and the actions), the design choices, and how to test a rule.

How it works:

=over

=item *

load_tags_rules() reads the YAML files, validates each rule and compiles its conditions to closures
(_compile_rule(), _compile_condition_*()). Invalid rules are reported and skipped.

=item *

evaluate_tags_rules() selects the rules whose required categories the product has, runs their conditions,
and checks that the categories they would add do not conflict with existing categories, or with each other.

=item *

apply_tags_rules_to_product() stores the result in the "rules" source of tags_sources,
and add_tags_rules_data_quality_tags() adds the data quality tags from check_quality().

=back

The tag fields that conditions can test, and the tag fields that rules can add tags to, are set for each flavor
in $options{tags_rules} (lib/ProductOpener/Config_off.pm). Flavors without this setting do not run tags rules.

Principles:

=over

=item *

Rules only add tags. They never remove tags. Rules must be close to 100% certain.
Weaker signals add data quality warnings instead of tags, so that the product can be reviewed.

=item *

Rules are flat: they are evaluated against the tags that come from the sources other than "rules",
so the output of a rule is never the input of another rule.

=item *

A rule never adds a category that is incompatible with a category the product already has
(exclusive groups in the rules files, and the incompatible_with:en property of the categories taxonomy).
It adds the en:category-rules-conflict data quality warning instead.

=item *

Tags added by rules are stored in tags_sources.[field].rules, with a "rules" sub-key that lists the rule ids
for each tag. They are recomputed on every product update.

=back

=cut

package ProductOpener::TagsRules;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

use Log::Any qw($log);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(
		&load_tags_rules
		&get_tags_rules
		&evaluate_tags_rules
		&apply_tags_rules_to_product
		&add_tags_rules_data_quality_tags
		&build_product_from_tags_rules_fixture
		&tags_rules_required_categories
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Config qw/%options/;
use ProductOpener::Tags
	qw/is_a exists_taxonomy_tag gen_tags_list_with_parents get_property canonicalize_taxonomy_tag get_minimal_tags_subset/;
use ProductOpener::Store qw/unac_string_perl/;
use ProductOpener::ProductsTags qw/set_field_input_tags_for_source generate_field_tags_from_all_sources add_tag/;

use Data::DeepAccess qw(deep_get deep_set);
use File::Find qw/find/;
use YAML::XS ();

# Name of the source in tags_sources.[field] where tags added by rules are stored
my $rules_source = "rules";

# Data quality warning added when a rule would add a category that conflicts with an existing one
my $conflict_warning = "en:category-rules-conflict";

# Tag fields that can be used in conditions, e.g. "labels: en:organic" (flavor setting)
my %condition_tag_fields = map {$_ => 1} @{deep_get(\%options, "tags_rules", "condition_tag_fields") // []};

# Fields that can be written by the "add" action, and their kind:
# - "tags": tag fields (flavor setting), stored in tags_sources.[field].rules by apply_tags_rules_to_product()
# - "data_quality": computed fields, the tags are added by check_quality() through add_tags_rules_data_quality_tags()
my %add_fields = (
	(map {$_ => "tags"} @{deep_get(\%options, "tags_rules", "add_tag_fields") // []}),
	data_quality_warnings => "data_quality",
	data_quality_info => "data_quality",
);

my %rule_keys = (id => 1, description => 1, if => 1, unless => 1, add => 1, tests => 1, comment => 1);

my %ingredients_condition_keys = (contains => 1, first => 1, in_first => 1, percent => 1, count_of => 1, known => 1);

# Rules loaded for each product type, see get_tags_rules()
my %tags_rules_for_product_type = ();

=head1 FUNCTIONS

=head2 get_tags_rules ($product_type = undef)

Return the rules for a product type (default: the product type of the server),
loaded from rules/[product type]/ the first time it is called.

Invalid rules are logged and skipped. tests/unit/tags_rules.t checks that all rules are valid.

If the flavor has no $options{tags_rules} setting, an empty set of rules is returned.

=cut

sub get_tags_rules ($product_type = undef) {

	$product_type //= $options{product_type} // "food";

	if (not defined $options{tags_rules}) {
		return {rules => [], by_category => {}, exclusive => {}, errors => [], by_id => {}};
	}

	if (not defined $tags_rules_for_product_type{$product_type}) {
		my $dir = $BASE_DIRS{RULES} . "/" . $product_type;
		my $rules_ref = load_tags_rules($dir);
		foreach my $error (@{$rules_ref->{errors}}) {
			$log->error("invalid tags rule", {dir => $dir, error => $error}) if $log->is_error();
		}
		$tags_rules_for_product_type{$product_type} = $rules_ref;
	}
	return $tags_rules_for_product_type{$product_type};
}

=head2 load_tags_rules ($dir)

Load, validate and compile all the rules files (*.yml) in a directory and its subdirectories.

Each file is either a list of rules, or a mapping with a "rules" list and an optional "exclusive" list of
groups of mutually exclusive categories.

=head3 Return value

A hash ref:

=over

=item *

rules: list of compiled rules (see _compile_rule()), in file order

=item *

by_category: required category => list of rules. Used to select the rules to evaluate for a product.

=item *

by_id: rule id => rule

=item *

exclusive: category => { other category => 1 }.
An exclusive group is a list of categories that a product cannot have at the same time
(e.g. [en:caffeinated-colas, en:cola-sodas-without-caffeine]). Groups are listed in the "exclusive" key of
the rules files. For each category of a group, this map lists the other categories of the group,
so that a rule never adds a category that is exclusive with one that the product already has.

=item *

errors: list of validation errors (strings, prefixed with the file, the rule id and the path of the
condition in the rule, e.g. "if.ingredients.first"). Rules with errors are not included in "rules".

=back

=cut

sub load_tags_rules ($dir) {

	my $ruleset_ref = {rules => [], by_category => {}, exclusive => {}, errors => [], by_id => {}};

	return $ruleset_ref if not -d $dir;

	my @files = ();
	find({wanted => sub {push @files, $File::Find::name if /\.ya?ml$/ and -f $_}, no_chdir => 1}, $dir);

	foreach my $file (sort @files) {
		my $content;
		eval {$content = YAML::XS::LoadFile($file);};
		if ($@) {
			push @{$ruleset_ref->{errors}}, "$file: cannot parse YAML: $@";
			next;
		}
		next if not defined $content;

		my ($rules_list_ref, $exclusive_ref);
		if (ref($content) eq 'ARRAY') {
			$rules_list_ref = $content;
		}
		elsif (ref($content) eq 'HASH') {
			foreach my $key (keys %$content) {
				if ($key !~ /^(rules|exclusive)$/) {
					push @{$ruleset_ref->{errors}}, "$file: unknown top-level key '$key'";
				}
			}
			$rules_list_ref = $content->{rules} // [];
			$exclusive_ref = $content->{exclusive} // [];
		}
		else {
			push @{$ruleset_ref->{errors}}, "$file: the file must contain a list of rules or a mapping";
			next;
		}

		_load_exclusive_groups($ruleset_ref, $file, $exclusive_ref) if defined $exclusive_ref;

		if (ref($rules_list_ref) ne 'ARRAY') {
			push @{$ruleset_ref->{errors}}, "$file: rules must be a list";
			next;
		}

		foreach my $rule_def (@$rules_list_ref) {
			my $rule_ref = _compile_rule($ruleset_ref, $file, $rule_def);
			if (defined $rule_ref) {
				$rule_ref->{order} = scalar @{$ruleset_ref->{rules}};
				push @{$ruleset_ref->{rules}}, $rule_ref;
				$ruleset_ref->{by_id}{$rule_ref->{id}} = $rule_ref;
				foreach my $category (@{$rule_ref->{required_categories}}) {
					push @{$ruleset_ref->{by_category}{$category}}, $rule_ref;
				}
			}
		}
	}

	return $ruleset_ref;
}

# Read the "exclusive" key of a rules file: a list of groups of categories that a product cannot have
# at the same time, e.g. [[en:caffeinated-colas, en:cola-sodas-without-caffeine]].
# Fills $ruleset_ref->{exclusive}{category}{other category} = 1 for each pair of categories of a group,
# and pushes errors to $ruleset_ref->{errors}.
sub _load_exclusive_groups ($ruleset_ref, $file, $exclusive_ref) {

	if (ref($exclusive_ref) ne 'ARRAY') {
		push @{$ruleset_ref->{errors}}, "$file: exclusive must be a list of lists of categories";
		return;
	}
	my $i = 0;
	foreach my $group_ref (@$exclusive_ref) {
		my $path = "exclusive[" . $i++ . "]";
		if ((ref($group_ref) ne 'ARRAY') or (scalar @$group_ref < 2)) {
			push @{$ruleset_ref->{errors}},
				"$file: $path: each exclusive group must be a list of at least 2 categories";
			next;
		}
		my @errors = ();
		my @group = map {_canonicalize_tag("categories", $_, $path, \@errors)} @$group_ref;
		if (@errors) {
			push @{$ruleset_ref->{errors}}, map {"$file: $_"} @errors;
			next;
		}
		foreach my $tag (@group) {
			foreach my $other (@group) {
				next if $other eq $tag;
				$ruleset_ref->{exclusive}{$tag}{$other} = 1;
			}
		}
	}
	return;
}

# Check that a tag of a rules file exists in the taxonomy of $field, and that it is written with its
# canonical id (so that rules are easy to search and to compare with product data).
# $path is the place of the tag in the rules file (for error messages), e.g. "if.categories".
# Returns the canonical tag id. Brands have no taxonomy: they are normalized like brands_tags.
sub _canonicalize_tag ($field, $tag, $path, $errors_ref) {

	if ((not defined $tag) or (ref($tag) ne '') or ($tag eq '')) {
		push @$errors_ref, "$path: invalid tag value, expected a tag id like en:example";
		return "";
	}

	if ($field eq "brands") {
		return _normalize_brand($tag);
	}

	if ($tag !~ /^[a-z]{2}:/) {
		push @$errors_ref, "$path: tag '$tag' must be prefixed with a language code (e.g. en:)";
		return $tag;
	}

	my $taxonomy = $field;
	$taxonomy = "data_quality" if $field =~ /^data_quality/;

	my $canon_tag = canonicalize_taxonomy_tag("en", $taxonomy, $tag);
	if (not exists_taxonomy_tag($taxonomy, $canon_tag)) {
		push @$errors_ref, "$path: tag '$tag' does not exist in the $taxonomy taxonomy";
	}
	elsif ($canon_tag ne $tag) {
		push @$errors_ref, "$path: tag '$tag' is not the canonical id, use '$canon_tag'";
	}
	return $canon_tag;
}

sub _normalize_brand ($brand) {
	$brand = lc(unac_string_perl($brand));
	$brand =~ s/^xx://;
	$brand =~ s/[^a-z0-9]+/-/g;
	$brand =~ s/^-|-$//g;
	return $brand;
}

sub _as_list ($value) {
	return () if not defined $value;
	return @$value if ref($value) eq 'ARRAY';
	return ($value);
}

=head2 _compile_rule ($ruleset_ref, $file, $rule_def)

Validate one rule of a rules file and compile it.

$rule_def is the rule as read from the YAML file: a mapping with the keys id, description, if, unless, add,
tests and comment (see docs/dev/explain-tags-rules.md).

Returns the compiled rule, or undef if the rule has errors (the errors are pushed to $ruleset_ref->{errors}).
The compiled rule is a hash ref with:

=over

=item *

id, description, file, definition (the YAML mapping), tests (the match / no_match fixtures)

=item *

required_categories: the categories of the top-level "categories" condition of "if". Only products in one of
those categories (or in a child) are evaluated, and the rule can only add categories under them.

=item *

if_sub: closure that returns 1 if all the "if" conditions match the product

=item *

unless_sub: closure that returns 1 if any of the "unless" conditions matches (undef if there is no "unless")

=item *

add: field => list of canonical tags to add

=back

=cut

sub _compile_rule ($ruleset_ref, $file, $rule_def) {

	my @errors = ();

	if (ref($rule_def) ne 'HASH') {
		push @{$ruleset_ref->{errors}}, "$file: each rule must be a mapping";
		return;
	}

	# Rule ids are global (not prefixed by the file name): they are used in the misc tags
	# en:tags-rule-[rule id], which must not change when a rule is moved to another file.
	my $id = $rule_def->{id};
	if ((not defined $id) or ($id !~ /^[a-z0-9]+(-[a-z0-9]+)*$/)) {
		push @{$ruleset_ref->{errors}},
			"$file: rule id '" . ($id // '') . "' is missing or invalid (lowercase letters, digits and dashes)";
		return;
	}
	my $where = "$file: rule $id";

	# Duplicate ids are reported by tests/unit/tags_rules.t, with the file of the second rule
	if (defined $ruleset_ref->{by_id}{$id} or $ruleset_ref->{seen_ids}{$id}) {
		push @{$ruleset_ref->{errors}}, "$where: duplicate rule id";
		return;
	}
	$ruleset_ref->{seen_ids}{$id} = 1;

	foreach my $key (sort keys %$rule_def) {
		push @errors, "unknown key '$key'" if not $rule_keys{$key};
	}
	push @errors, "missing description" if not defined $rule_def->{description};

	# Required categories: the top-level categories condition of "if"
	my @required_categories = ();
	if ((ref($rule_def->{if}) ne 'HASH') or (not defined $rule_def->{if}{categories})) {
		push @errors, "if: must be a mapping with a top-level 'categories' condition (the required categories)";
	}
	else {
		@required_categories
			= map {_canonicalize_tag("categories", $_, "if.categories", \@errors)}
			_as_list($rule_def->{if}{categories});
	}

	# Conditions: "if" matches when all its conditions match, "unless" when any of its conditions matches
	my $if_sub = _compile_condition_all($rule_def->{if}, "if", \@errors);
	my $unless_sub;
	if (defined $rule_def->{unless}) {
		$unless_sub = _compile_condition_any($rule_def->{unless}, "unless", \@errors);
	}

	# Action: tags to add, for each field
	my %add = ();
	if ((ref($rule_def->{add}) ne 'HASH') or (scalar keys %{$rule_def->{add}} == 0)) {
		push @errors, "add: must be a mapping of fields to tags, e.g. add: {categories: en:x}";
	}
	else {
		foreach my $field (sort keys %{$rule_def->{add}}) {
			if (not $add_fields{$field}) {
				push @errors, "add: unsupported field '$field' (supported: " . join(", ", sort keys %add_fields) . ")";
				next;
			}
			my @tags = map {_canonicalize_tag($field, $_, "add.$field", \@errors)} _as_list($rule_def->{add}{$field});
			push @errors, "add.$field: no tags" if not @tags;
			$add{$field} = \@tags;
		}
	}

	# Added categories must be more precise than the required categories.
	# A rule refines a category that the product already has: it cannot add an unrelated category.
	# This keeps rules safe (a rule only applies to the products of its required categories, which a
	# contributor entered), and lets evaluate_tags_rules() select the rules from the categories of the product.
	foreach my $tag (@{$add{categories} // []}) {
		my $under_required = 0;
		foreach my $required (@required_categories) {
			if (($tag ne $required) and is_a("categories", $tag, $required)) {
				$under_required = 1;
				last;
			}
		}
		if (not $under_required) {
			push @errors,
				"add.categories: category '$tag' must be a descendant of the required categories ("
				. join(", ", @required_categories) . ")";
		}
	}

	# Tests
	my $tests_ref = $rule_def->{tests} // {};
	if (ref($tests_ref) ne 'HASH') {
		push @errors, "tests must be a mapping with match and no_match lists";
		$tests_ref = {};
	}
	foreach my $key (sort keys %$tests_ref) {
		if ($key !~ /^(match|no_match)$/) {
			push @errors, "tests: unknown key '$key'";
		}
		elsif (ref($tests_ref->{$key}) ne 'ARRAY') {
			push @errors, "tests: $key must be a list of products";
		}
	}
	if (not @{$tests_ref->{match} // []}) {
		push @errors, "tests: at least one 'match' test product is required";
	}

	if (@errors) {
		push @{$ruleset_ref->{errors}}, map {"$where: $_"} @errors;
		return;
	}

	return {
		id => $id,
		description => $rule_def->{description},
		file => $file,
		required_categories => \@required_categories,
		if_sub => $if_sub,
		unless_sub => $unless_sub,
		add => \%add,
		tests => $tests_ref,
		definition => $rule_def,
	};
}

=head2 Condition compilation

Conditions are compiled to closures that take an evaluation context (see _new_context()) and return 1 or 0.

The YAML structure gives the logic, so that most rules need no explicit "all" or "any":

=over

=item *

Under "if" and "all", the keys of a mapping, or the items of a list, must all match (AND).
e.g. if: {categories: en:colas, labels: en:organic}

=item *

Under "any" and "unless", one of the keys of the mapping, or one of the items of the list, must match (OR).
"unless" lists the cases where the rule must not apply: the rule does not apply if any of them matches.

=item *

Each item of a list is itself a condition whose keys must all match (AND).

=item *

A list of tags in a tag condition is an OR: categories: [en:x, en:y] matches products in en:x or in en:y.

=item *

not: condition: the condition must not match. not: [c1, c2]: none of the conditions matches.

=back

Each compile function takes the path of the condition in the rule (e.g. "if.any[1].ingredients"),
used to prefix the error messages, and a reference to the list of errors.

=cut

# Compile a condition that matches if all its parts match:
# a mapping (all keys must match) or a list of conditions (all items must match).
sub _compile_condition_all ($cond, $path, $errors_ref) {
	my @subs = _compile_condition_parts($cond, $path, $errors_ref);
	return sub ($ctx) {
		foreach my $sub (@subs) {
			return 0 if not $sub->($ctx);
		}
		return 1;
	};
}

# Compile a condition that matches if any of its parts matches:
# a mapping (any key must match) or a list of conditions (any item must match).
sub _compile_condition_any ($cond, $path, $errors_ref) {
	my @subs = _compile_condition_parts($cond, $path, $errors_ref);
	return sub ($ctx) {
		foreach my $sub (@subs) {
			return 1 if $sub->($ctx);
		}
		return 0;
	};
}

# Compile the parts of a condition: each key of a mapping, or each item of a list (an item is itself
# a mapping or a list, whose parts must all match). Returns the list of closures.
sub _compile_condition_parts ($cond, $path, $errors_ref) {

	my @subs = ();
	if (ref($cond) eq 'ARRAY') {
		my $i = 0;
		foreach my $item (@$cond) {
			push @subs, _compile_condition_all($item, $path . "[" . $i++ . "]", $errors_ref);
		}
	}
	elsif (ref($cond) eq 'HASH') {
		foreach my $key (sort keys %$cond) {
			push @subs, _compile_condition_key($key, $cond->{$key}, "$path.$key", $errors_ref);
		}
	}
	else {
		push @$errors_ref,
			"$path: expected a mapping of conditions (e.g. {labels: en:organic}) or a list of conditions, got '"
			. ($cond // '') . "'";
	}
	return grep {defined} @subs;
}

# Compile one key of a condition mapping: $key is the type of condition (e.g. "labels", "ingredients", "any")
# and $value its parameters. Returns a closure, or undef if the condition is unknown.
sub _compile_condition_key ($key, $value, $path, $errors_ref) {

	if ($key eq 'all') {
		return _compile_condition_all($value, $path, $errors_ref);
	}
	elsif ($key eq 'any') {
		return _compile_condition_any($value, $path, $errors_ref);
	}
	elsif ($key eq 'not') {
		my $sub
			= (ref($value) eq 'ARRAY')
			? _compile_condition_any($value, $path, $errors_ref)
			: _compile_condition_all($value, $path, $errors_ref);
		return sub ($ctx) {return not $sub->($ctx)};
	}
	# key is a tag field (e.g. labels): the product must have one of the tags, or a child of one of them
	elsif ($condition_tag_fields{$key}) {
		my @tags = map {_canonicalize_tag($key, $_, $path, $errors_ref)} _as_list($value);
		push @$errors_ref, "$path: no tags" if not @tags;
		# the rule matches if any of the tags of the product (with their parents)
		# is one of the specified tags
		return sub ($ctx) {
			my $product_tags_ref = _get_complete_tag_set($ctx, $key);
			foreach my $tag (@tags) {
				return 1 if $product_tags_ref->{$tag};
			}
			return 0;
		};
	}
	# key is a tag field with _exact (e.g. categories_exact): one of the tags must have been entered
	# on the product, the parents of the entered tags do not match.
	# e.g. categories_exact: en:colas matches a product entered as en:colas, not one entered as en:diet-colas
	elsif (($key =~ /^(.+)_exact$/) and ($condition_tag_fields{$1})) {
		my $field = $1;
		if ($field eq 'brands') {
			push @$errors_ref, "$path: brands have no parents, use brands instead";
			return;
		}
		my @tags = map {_canonicalize_tag($field, $_, $path, $errors_ref)} _as_list($value);
		push @$errors_ref, "$path: no tags" if not @tags;
		return sub ($ctx) {
			my $product_tags_ref = _get_input_tag_set($ctx, $field);
			foreach my $tag (@tags) {
				return 1 if $product_tags_ref->{$tag};
			}
			return 0;
		};
	}
	elsif ($key eq 'ingredients') {
		return _compile_ingredients_condition($value, $path, $errors_ref);
	}
	elsif ($key eq 'nutrients') {
		return _compile_nutrients_condition($value, $path, $errors_ref);
	}
	elsif ($key eq 'name') {
		return _compile_regexp_condition($value, [qw(product_name generic_name)], $path, $errors_ref);
	}
	elsif ($key eq 'ingredients_text') {
		return _compile_regexp_condition($value, [qw(ingredients_text)], $path, $errors_ref);
	}

	push @$errors_ref, "$path: unknown condition '$key'";
	return;
}

sub _compile_min_max ($path, $spec, $errors_ref) {

	my ($min, $max) = ($spec->{min}, $spec->{max});
	foreach my $value ($min, $max) {
		if ((defined $value) and ($value !~ /^-?\d+(\.\d+)?$/)) {
			push @$errors_ref, "$path: min and max must be numbers";
		}
	}
	if ((not defined $min) and (not defined $max)) {
		push @$errors_ref, "$path: min or max is required";
	}
	return ($min, $max);
}

# Compile an ingredients condition: a mapping of ingredients conditions (contains, first, in_first, percent,
# count_of, known) that must all match. Ingredients are matched with is_a(), so a condition on en:wholemeal-flour
# also matches en:wholemeal-rye-flour.
sub _compile_ingredients_condition ($spec, $path, $errors_ref) {

	if (ref($spec) ne 'HASH') {
		push @$errors_ref, "$path: must be a mapping, e.g. {first: en:water}";
		return;
	}

	my @subs = ();

	foreach my $key (sort keys %$spec) {

		my $value = $spec->{$key};
		my $key_path = "$path.$key";

		if (not $ingredients_condition_keys{$key}) {
			push @$errors_ref, "$path: unknown condition '$key'";
		}
		elsif ($key eq 'contains') {
			my @of = map {_canonicalize_tag("ingredients", $_, $key_path, $errors_ref)} _as_list($value);
			push @subs, sub ($ctx) {
				my $found = 0;
				_walk_ingredients(
					$ctx->{product}{ingredients},
					sub ($ingredient_ref) {
						$found = 1 if _ingredient_is_a($ingredient_ref, \@of);
					}
				);
				return $found;
			};
		}
		elsif ($key eq 'first') {
			my @of = map {_canonicalize_tag("ingredients", $_, $key_path, $errors_ref)} _as_list($value);
			push @subs, sub ($ctx) {
				my $first_ref = deep_get($ctx->{product}, "ingredients", 0);
				return ((defined $first_ref) and _ingredient_is_a($first_ref, \@of)) ? 1 : 0;
			};
		}
		elsif ($key eq 'in_first') {
			if ((ref($value) ne 'HASH') or (($value->{n} // '') !~ /^\d+$/) or (not defined $value->{of})) {
				push @$errors_ref, "$key_path: must be a mapping with n (number) and of (ingredients)";
				next;
			}
			my $n = $value->{n};
			my @of = map {_canonicalize_tag("ingredients", $_, $key_path, $errors_ref)} _as_list($value->{of});
			push @subs, sub ($ctx) {
				my $ingredients_ref = $ctx->{product}{ingredients} // [];
				for (my $i = 0; ($i < $n) and ($i < scalar @$ingredients_ref); $i++) {
					return 1 if _ingredient_is_a($ingredients_ref->[$i], \@of);
				}
				return 0;
			};
		}
		elsif ($key eq 'percent') {
			if ((ref($value) ne 'HASH') or (not defined $value->{of})) {
				push @$errors_ref, "$key_path: must be a mapping with of (ingredients), min and/or max";
				next;
			}
			foreach my $percent_key (keys %$value) {
				push @$errors_ref, "$key_path: unknown key '$percent_key'"
					if $percent_key !~ /^(of|min|max|use)$/;
			}
			my @of = map {_canonicalize_tag("ingredients", $_, $key_path, $errors_ref)} _as_list($value->{of});
			my ($min, $max) = _compile_min_max($key_path, $value, $errors_ref);
			my $use = $value->{use} // "any";
			if ($use !~ /^(declared|estimate|any)$/) {
				push @$errors_ref, "$key_path: use must be declared, estimate or any";
			}
			push @subs, sub ($ctx) {
				my $ingredients_ref = $ctx->{product}{ingredients};
				return 0 if (not defined $ingredients_ref) or (not @$ingredients_ref);
				my ($sum, $missing) = _sum_percent($ingredients_ref, \@of, $use);
				return 0 if $missing;
				return 0 if (defined $min) and ($sum < $min);
				return 0 if (defined $max) and ($sum > $max);
				return 1;
			};
		}
		elsif ($key eq 'count_of') {
			if ((ref($value) ne 'HASH') or (not defined $value->{of})) {
				push @$errors_ref, "$key_path: must be a mapping with of (ingredients), min and/or max";
				next;
			}
			my @of = map {_canonicalize_tag("ingredients", $_, $key_path, $errors_ref)} _as_list($value->{of});
			my ($min, $max) = _compile_min_max($key_path, $value, $errors_ref);
			push @subs, sub ($ctx) {
				my %ids = ();
				_walk_ingredients(
					$ctx->{product}{ingredients},
					sub ($ingredient_ref) {
						$ids{$ingredient_ref->{id}} = 1 if _ingredient_is_a($ingredient_ref, \@of);
					}
				);
				my $count = scalar keys %ids;
				return 0 if (defined $min) and ($count < $min);
				return 0 if (defined $max) and ($count > $max);
				return 1;
			};
		}
		elsif ($key eq 'known') {
			# known: true -> the product has an ingredients list and all ingredients (at all depths) are known
			my $expected = $value ? 1 : 0;
			push @subs, sub ($ctx) {
				my $ingredients_ref = $ctx->{product}{ingredients};
				my $known = ((defined $ingredients_ref) and (scalar @$ingredients_ref > 0)) ? 1 : 0;
				if ($known) {
					_walk_ingredients(
						$ingredients_ref,
						sub ($ingredient_ref) {
							$known = 0
								if not exists_taxonomy_tag("ingredients", $ingredient_ref->{id} // "");
						}
					);
				}
				return $known == $expected ? 1 : 0;
			};
		}
	}

	return sub ($ctx) {
		foreach my $sub (@subs) {
			return 0 if not $sub->($ctx);
		}
		return 1;
	};
}

sub _walk_ingredients ($ingredients_ref, $callback) {
	return if ref($ingredients_ref) ne 'ARRAY';
	foreach my $ingredient_ref (@$ingredients_ref) {
		next if ref($ingredient_ref) ne 'HASH';
		$callback->($ingredient_ref);
		_walk_ingredients($ingredient_ref->{ingredients}, $callback) if defined $ingredient_ref->{ingredients};
	}
	return;
}

sub _ingredient_is_a ($ingredient_ref, $of_ref) {
	my $id = $ingredient_ref->{id} // return 0;
	foreach my $of (@$of_ref) {
		return 1 if is_a("ingredients", $id, $of);
	}
	return 0;
}

# Sum the percent of the ingredients that are one of the $of_ref ingredients.
# When an ingredient matches, its sub-ingredients are not counted again.
# Returns the sum and a flag that is 1 if a matching ingredient has no value.
sub _sum_percent ($ingredients_ref, $of_ref, $use) {
	my ($sum, $missing) = (0, 0);
	foreach my $ingredient_ref (@$ingredients_ref) {
		next if ref($ingredient_ref) ne 'HASH';
		if (_ingredient_is_a($ingredient_ref, $of_ref)) {
			my $value
				= ($use eq 'declared') ? $ingredient_ref->{percent}
				: ($use eq 'estimate') ? $ingredient_ref->{percent_estimate}
				: ($ingredient_ref->{percent} // $ingredient_ref->{percent_estimate});
			if (defined $value) {
				$sum += $value;
			}
			else {
				$missing = 1;
			}
		}
		elsif (ref($ingredient_ref->{ingredients}) eq 'ARRAY') {
			my ($sub_sum, $sub_missing) = _sum_percent($ingredient_ref->{ingredients}, $of_ref, $use);
			$sum += $sub_sum;
			$missing ||= $sub_missing;
		}
	}
	return ($sum, $missing);
}

# Compile a nutrients condition: nutrient id => {min, max}, all must match.
# Values are read from the aggregated nutrition set, per 100g or 100ml, as sold.
sub _compile_nutrients_condition ($spec, $path, $errors_ref) {

	if ((ref($spec) ne 'HASH') or (not %$spec)) {
		push @$errors_ref, "$path: must be a mapping of nutrient ids to {min, max}";
		return;
	}

	my @checks = ();
	foreach my $nid (sort keys %$spec) {
		if ($nid !~ /^[a-z0-9]+(-[a-z0-9]+)*$/) {
			push @$errors_ref, "$path: invalid nutrient id '$nid'";
		}
		if (ref($spec->{$nid}) ne 'HASH') {
			push @$errors_ref, "$path.$nid: must be a mapping with min and/or max";
			next;
		}
		my ($min, $max) = _compile_min_max("$path.$nid", $spec->{$nid}, $errors_ref);
		push @checks, [$nid, $min, $max];
	}

	return sub ($ctx) {
		my $set_ref = deep_get($ctx->{product}, "nutrition", "aggregated_set") // return 0;
		return 0 if ($set_ref->{preparation} // "as_sold") ne "as_sold";
		return 0 if ($set_ref->{per} // "100g") !~ /^100(g|ml)$/;
		foreach my $check_ref (@checks) {
			my ($nid, $min, $max) = @$check_ref;
			my $nutrient_ref = deep_get($set_ref, "nutrients", $nid) // return 0;
			my $value = $nutrient_ref->{value};
			return 0 if (not defined $value) or ($value !~ /^-?\d+(\.\d+)?(e-?\d+)?$/i);
			my $modifier = $nutrient_ref->{modifier} // "";
			if (defined $min) {
				return 0 if ($value < $min) or ($modifier =~ /^(<|≤|<=)$/);
			}
			if (defined $max) {
				return 0 if ($value > $max) or ($modifier =~ /^(>|≥|>=)$/);
			}
		}
		return 1;
	};
}

# Text is matched case- and accent-insensitively
sub _normalize_text ($text) {
	return lc(unac_string_perl($text));
}

# Compile a regular expression condition on text fields: language code (or "any") => regular expression.
# Matches if one of the regular expressions matches one of the $fields_ref fields in its language
# (case and accent insensitive).
sub _compile_regexp_condition ($spec, $fields_ref, $path, $errors_ref) {

	if ((ref($spec) ne 'HASH') or (not %$spec)) {
		push @$errors_ref, "$path: must be a mapping of language codes (or 'any') to regular expressions";
		return;
	}

	my %regexps = ();
	foreach my $lc (sort keys %$spec) {
		if ($lc !~ /^([a-z]{2}|any)$/) {
			push @$errors_ref, "$path: invalid language code '$lc'";
			next;
		}
		my $pattern = $spec->{$lc};
		if ((not defined $pattern) or (ref($pattern) ne '') or ($pattern eq '')) {
			push @$errors_ref, "$path.$lc: invalid regular expression";
			next;
		}
		my $regexp = eval {qr/${\ unac_string_perl($pattern)}/i};
		if ($@ or not defined $regexp) {
			push @$errors_ref, "$path.$lc: invalid regular expression '$pattern': $@";
			next;
		}
		$regexps{$lc} = $regexp;
	}

	return sub ($ctx) {
		my $product_ref = $ctx->{product};
		foreach my $lc (keys %regexps) {
			my $regexp = $regexps{$lc};
			my @values = ();
			foreach my $field (@$fields_ref) {
				if ($lc eq 'any') {
					push @values, map {$product_ref->{$_}} grep {/^${field}(_[a-z]{2})?$/} keys %$product_ref;
				}
				else {
					push @values, $product_ref->{"${field}_$lc"};
					push @values, $product_ref->{$field} if ($product_ref->{lc} // '') eq $lc;
				}
			}
			foreach my $value (@values) {
				next if (not defined $value) or (ref($value) ne '') or ($value eq '');
				return 1 if _normalize_text($value) =~ $regexp;
			}
		}
		return 0;
	};
}

=head2 Evaluation context

The evaluation context caches, for one product, the sets of tags used by the conditions.

For fields that have tags_sources, tags from the "rules" source are ignored, so that rules are flat.
The tags are recomputed with their parents from the current taxonomy.

=cut

# sets: field => {tag => 1} for _get_complete_tag_set(), input_sets: same for _get_input_tag_set()
sub _new_context ($product_ref) {
	return {product => $product_ref, sets => {}, input_sets => {}};
}

# Return the tags entered for a field (without parents), from all the sources of tags_sources.[field]
# except the "rules" source. Returns undef if the field has no tags_sources (e.g. older product data).
sub _input_tags ($product_ref, $field) {
	my $sources_ref = deep_get($product_ref, "tags_sources", $field);
	if ((ref($sources_ref) eq 'HASH') and (%$sources_ref)) {
		my %input = ();
		foreach my $source (keys %$sources_ref) {
			next if $source eq $rules_source;
			next if ref($sources_ref->{$source}) ne 'HASH';
			$input{$_} = 1 foreach @{$sources_ref->{$source}{tags} // []};
		}
		return [sort keys %input];
	}
	return;
}

# Return the set of tags of the product for a field, with their parents: {tag => 1}.
# Used by tag conditions (e.g. categories: en:colas also matches a product in en:diet-colas).
# Tags added by rules are not included (rules are flat), except for products without tags_sources,
# where the [field]_tags are used as is.
sub _get_complete_tag_set ($ctx, $field) {
	return $ctx->{sets}{$field} //= do {
		my $product_ref = $ctx->{product};
		my @tags;
		if ($field eq 'brands') {
			@tags = map {_normalize_brand($_)} @{$product_ref->{brands_tags} // []};
		}
		else {
			my $input_tags_ref = _input_tags($product_ref, $field);
			if (defined $input_tags_ref) {
				@tags = gen_tags_list_with_parents("en", $field, $input_tags_ref);
			}
			else {
				@tags = @{$product_ref->{$field . "_tags"} // []};
			}
		}
		+{map {$_ => 1} @tags};
	};
}

# Return the set of tags entered on the product for a field, without their parents: {tag => 1}.
# Used by [field]_exact conditions. Without tags_sources, the most specific tags of [field]_tags are used.
sub _get_input_tag_set ($ctx, $field) {
	return $ctx->{input_sets}{$field} //= do {
		my $input_tags_ref = _input_tags($ctx->{product}, $field)
			// [get_minimal_tags_subset($field, $ctx->{product}{$field . "_tags"} // [])];
		+{map {$_ => 1} @$input_tags_ref};
	};
}

=head2 Conflicts

A category conflicts with another one if they are in the same exclusive group of a rules file,
or if one of them (or one of their parents) has an incompatible_with:en property that lists the other one
(or one of its parents).

=cut

# Return the list of tags with which a category conflicts, among the tags of a set (hash ref with parents)
sub _category_conflicts ($ruleset_ref, $tag, $set_ref, $labels_set_ref = {}) {

	my %conflicts = ();

	my @tag_and_parents = gen_tags_list_with_parents("en", "categories", [$tag]);
	my %tag_and_parents = map {$_ => 1} @tag_and_parents;

	# Exclusive groups of the tag or of its parents
	foreach my $tagid (@tag_and_parents) {
		foreach my $other (keys %{$ruleset_ref->{exclusive}{$tagid} // {}}) {
			$conflicts{$other} = 1 if $set_ref->{$other} and not $tag_and_parents{$other};
		}
	}

	# incompatible_with:en on the tag or its parents
	foreach my $tagid (@tag_and_parents) {
		foreach my $incompatible (_incompatible_with($tagid)) {
			my ($tagtype, $other) = @$incompatible;
			if (($tagtype eq 'categories') and $set_ref->{$other}) {
				$conflicts{$other} = 1;
			}
			elsif (($tagtype eq 'labels') and $labels_set_ref->{$other}) {
				$conflicts{"labels:$other"} = 1;
			}
		}
	}

	# incompatible_with:en on the existing categories (the set already contains the parents)
	foreach my $other (keys %$set_ref) {
		foreach my $incompatible (_incompatible_with($other)) {
			my ($tagtype, $incompatible_tag) = @$incompatible;
			if (($tagtype eq 'categories') and $tag_and_parents{$incompatible_tag}) {
				$conflicts{$other} = 1;
			}
		}
	}

	my @conflicts = sort keys %conflicts;
	return @conflicts;
}

my %incompatible_with_cache = ();

sub _incompatible_with ($tagid) {
	my $cached_ref = $incompatible_with_cache{$tagid} //= do {
		my @list = ();
		my $property = get_property("categories", $tagid, "incompatible_with:en");
		if (defined $property) {
			foreach my $item (split(/\s*,\s*/, $property)) {
				if ($item =~ /^\s*(\w+):([a-z]{2}:.+?)\s*$/) {
					push @list, [$1, $2];
				}
			}
		}
		\@list;
	};
	return @$cached_ref;
}

=head2 evaluate_tags_rules ($product_ref, $options_ref = {})

Evaluate the rules for a product. Pure function: the product is not modified.

=head3 Options

=over

=item *

rules: a ruleset returned by load_tags_rules() (default: get_tags_rules() for the product type)

=item *

rule_ids: list of rule ids: only evaluate those rules

=back

=head3 Return value

A hash ref:

=over

=item *

added: field => { tag => [rule ids] }. Fields are the targets of the add actions (e.g. categories,
data_quality_warnings). Conflicts add the en:category-rules-conflict tag to data_quality_warnings.

=item *

matched: list of the ids of the rules whose conditions matched

=item *

already: rule id => list of the tags the rule would add, but that the product already has

=item *

conflicts: list of { rule, tag, with } for categories that were not added because of a conflict

=back

=cut

sub evaluate_tags_rules ($product_ref, $options_ref = {}) {

	my $ruleset_ref = $options_ref->{rules}
		// get_tags_rules($product_ref->{product_type} // $options{product_type} // "food");

	my $result_ref = {added => {}, matched => [], already => {}, conflicts => []};

	return $result_ref if not @{$ruleset_ref->{rules}};

	my $ctx = _new_context($product_ref);

	my %rule_ids_filter = ();
	if (defined $options_ref->{rule_ids}) {
		%rule_ids_filter = map {$_ => 1} @{$options_ref->{rule_ids}};
	}

	# Candidate rules: rules indexed by one of the categories of the product
	my $categories_ref = _get_complete_tag_set($ctx, "categories");
	my %candidates = ();
	foreach my $category (keys %$categories_ref) {
		foreach my $rule_ref (@{$ruleset_ref->{by_category}{$category} // []}) {
			$candidates{$rule_ref->{order}} = $rule_ref;
		}
	}

	foreach my $order (sort {$a <=> $b} keys %candidates) {
		my $rule_ref = $candidates{$order};
		next if (%rule_ids_filter) and (not $rule_ids_filter{$rule_ref->{id}});

		next if not $rule_ref->{if_sub}->($ctx);
		next if (defined $rule_ref->{unless_sub}) and $rule_ref->{unless_sub}->($ctx);

		push @{$result_ref->{matched}}, $rule_ref->{id};

		foreach my $field (sort keys %{$rule_ref->{add}}) {
			foreach my $tag (@{$rule_ref->{add}{$field}}) {
				if ($field eq 'categories') {
					if ($categories_ref->{$tag}) {
						push @{$result_ref->{already}{$rule_ref->{id}}}, $tag;
						next;
					}
					my @conflicts = _category_conflicts($ruleset_ref, $tag, $categories_ref,
						_get_complete_tag_set($ctx, "labels"));
					if (@conflicts) {
						push @{$result_ref->{conflicts}}, {rule => $rule_ref->{id}, tag => $tag, with => \@conflicts};
						_add_result($result_ref, "data_quality_warnings", $conflict_warning, $rule_ref->{id});
						next;
					}
				}
				_add_result($result_ref, $field, $tag, $rule_ref->{id});
			}
		}
	}

	# Conflicts between categories added by different rules: add none of them
	my $added_categories_ref = $result_ref->{added}{categories};
	if ((defined $added_categories_ref) and (scalar keys %$added_categories_ref > 1)) {
		my %conflicting = ();
		foreach my $tag (sort keys %$added_categories_ref) {
			# The other added categories and their parents, each mapped to the added categories it comes from:
			# a conflict is often found on a parent (e.g. an exclusive group of parent categories)
			my %others_with_parents = ();
			foreach my $other (grep {$_ ne $tag} keys %$added_categories_ref) {
				foreach my $other_or_parent (gen_tags_list_with_parents("en", "categories", [$other])) {
					$others_with_parents{$other_or_parent}{$other} = 1;
				}
			}
			my %conflicts = ();
			foreach my $conflict (_category_conflicts($ruleset_ref, $tag, \%others_with_parents)) {
				$conflicts{$_} = 1 foreach keys %{$others_with_parents{$conflict} // {}};
			}
			if (%conflicts) {
				$conflicting{$tag} = [sort keys %conflicts];
			}
		}
		foreach my $tag (sort keys %conflicting) {
			foreach my $rule_id (@{$added_categories_ref->{$tag}}) {
				push @{$result_ref->{conflicts}}, {rule => $rule_id, tag => $tag, with => $conflicting{$tag}};
				_add_result($result_ref, "data_quality_warnings", $conflict_warning, $rule_id);
			}
			delete $added_categories_ref->{$tag};
		}
		delete $result_ref->{added}{categories} if not %$added_categories_ref;
	}

	return $result_ref;
}

# Add a rule id to the list of rule ids for a tag: $result_ref->{added}{$field}{$tag}
sub _add_result ($result_ref, $field, $tag, $rule_id) {
	my $list_ref = $result_ref->{added}{$field}{$tag} //= [];
	push @$list_ref, $rule_id if not grep {$_ eq $rule_id} @$list_ref;
	return;
}

=head2 apply_tags_rules_to_product ($product_ref, $options_ref = {})

Evaluate the rules for a product, and store the tags they add in the "rules" source of tags_sources:

	tags_sources.categories.rules = {
		tags => ["en:caffeinated-colas"],
		last_updated_t => 1762800000,
		rules => {"en:caffeinated-colas" => ["colas-caffeinated"]},
	}

The source is only changed when the tags or the rules ids change, and it is removed when no rule adds tags.
categories_tags (and other [field]_tags) are regenerated from all sources.

Also sets the misc tags en:tags-added-by-rules (when some tags were added) and en:tags-rule-[rule id]
(for each rule that added a tag or a data quality tag).

Data quality tags are not stored: they are added by check_quality(), see add_tags_rules_data_quality_tags().

Returns the result of evaluate_tags_rules().

=cut

sub apply_tags_rules_to_product ($product_ref, $options_ref = {}) {

	my $result_ref = evaluate_tags_rules($product_ref, $options_ref);

	# Fields to update: fields with tags added by rules, and fields with an existing rules source
	my %fields = ();
	foreach my $field (keys %{$result_ref->{added}}) {
		$fields{$field} = 1 if $add_fields{$field} eq 'tags';
	}
	if (ref($product_ref->{tags_sources}) eq 'HASH') {
		foreach my $field (keys %{$product_ref->{tags_sources}}) {
			$fields{$field} = 1 if defined deep_get($product_ref, "tags_sources", $field, $rules_source);
		}
	}

	foreach my $field (sort keys %fields) {
		my $added_ref = $result_ref->{added}{$field} // {};
		my $existing_ref = deep_get($product_ref, "tags_sources", $field, $rules_source);

		if (not %$added_ref) {
			if (defined $existing_ref) {
				delete $product_ref->{tags_sources}{$field}{$rules_source};
				generate_field_tags_from_all_sources($product_ref, $field);
			}
			next;
		}

		my @tags = sort {$a cmp $b} get_minimal_tags_subset($field, [sort keys %$added_ref]);
		my %rules_map = map {$_ => [sort @{$added_ref->{$_}}]} keys %$added_ref;

		if (    (defined $existing_ref)
			and (join(",", sort @{$existing_ref->{tags} // []}) eq join(",", @tags))
			and (_rules_map_key($existing_ref->{rules}) eq _rules_map_key(\%rules_map)))
		{
			# Nothing changed: keep last_updated_t, but make sure the [field]_tags include the rules tags
			generate_field_tags_from_all_sources($product_ref, $field);
			next;
		}

		set_field_input_tags_for_source($product_ref, "en", $field, $rules_source, join(",", @tags));
		deep_set($product_ref, "tags_sources", $field, $rules_source, "rules", \%rules_map);
	}

	# Misc tags
	my @misc_tags = grep {not /^en:tags-(added-by-rules|rule-.*)$/} @{$product_ref->{misc_tags} // []};
	my %contributing_rules = ();
	my $tags_added = 0;
	foreach my $field (keys %{$result_ref->{added}}) {
		foreach my $tag (keys %{$result_ref->{added}{$field}}) {
			$tags_added = 1 if $add_fields{$field} eq 'tags';
			$contributing_rules{$_} = 1 foreach @{$result_ref->{added}{$field}{$tag}};
		}
	}
	push @misc_tags, "en:tags-added-by-rules" if $tags_added;
	push @misc_tags, map {"en:tags-rule-$_"} sort keys %contributing_rules;
	if (@misc_tags or (defined $product_ref->{misc_tags})) {
		$product_ref->{misc_tags} = \@misc_tags;
	}

	return $result_ref;
}

sub _rules_map_key ($rules_map_ref) {
	return "" if ref($rules_map_ref) ne 'HASH';
	return join(";", map {$_ . "=" . join(",", sort @{$rules_map_ref->{$_} // []})} sort keys %$rules_map_ref);
}

=head2 add_tags_rules_data_quality_tags ($product_ref, $options_ref = {})

Add the data quality tags of the rules (e.g. rules that add data_quality_warnings, and conflicts)
to the data_quality_[level]_tags of the product.

Called by check_quality() after it resets the data quality tags.

=cut

sub add_tags_rules_data_quality_tags ($product_ref, $options_ref = {}) {

	my $result_ref = evaluate_tags_rules($product_ref, $options_ref);

	foreach my $field (sort keys %{$result_ref->{added}}) {
		next if $add_fields{$field} ne 'data_quality';
		foreach my $tag (sort keys %{$result_ref->{added}{$field}}) {
			add_tag($product_ref, $field, $tag);
		}
	}
	return $result_ref;
}

=head2 tags_rules_required_categories ($ruleset_ref = undef)

Return the sorted list of all the required categories of the rules
(e.g. to select the products to reprocess after a rules change).

=cut

sub tags_rules_required_categories ($ruleset_ref = undef) {
	$ruleset_ref //= get_tags_rules();
	my @categories = sort keys %{$ruleset_ref->{by_category}};
	return @categories;
}

=head2 build_product_from_tags_rules_fixture ($fixture_ref)

Build a product from a test fixture of a rules file, so that rule authors only need to write tag ids:

	categories: [en:colas]                    # -> categories_tags with parents (also labels, countries, origins, states)
	brands: [xx:some-brand]                   # -> brands_tags
	ingredients: [en:water, {id: en:sugar, percent: 10, ingredients: [...]}]
	nutrients: {cocoa: 55}                    # -> nutrition.aggregated_set (per 100g, as sold)
	product_name_fr: Moutarde douce           # other fields are copied as is

Tags and ingredient ids are canonicalized (e.g. en:citric-acid -> en:e330), so fixtures can use synonyms.

=cut

sub build_product_from_tags_rules_fixture ($fixture_ref) {

	my $product_ref = {lc => "en"};

	foreach my $key (keys %$fixture_ref) {
		my $value = $fixture_ref->{$key};
		if ($key eq 'brands') {
			$product_ref->{brands_tags} = [_as_list($value)];
		}
		elsif ($condition_tag_fields{$key}) {
			$product_ref->{$key . "_tags"} = [
				gen_tags_list_with_parents(
					"en", $key, [map {canonicalize_taxonomy_tag("en", $key, $_)} _as_list($value)]
				)
			];
		}
		elsif ($key eq 'ingredients') {
			$product_ref->{ingredients} = _fixture_ingredients($value);
		}
		elsif ($key eq 'nutrients') {
			my %nutrients = map {$_ => {value => $value->{$_}, unit => "g"}} keys %$value;
			$product_ref->{nutrition}{aggregated_set}
				= {per => "100g", preparation => "as_sold", nutrients => \%nutrients};
		}
		else {
			$product_ref->{$key} = $value;
		}
	}

	return $product_ref;
}

sub _fixture_ingredients ($list_ref) {
	my @ingredients = ();
	foreach my $item (_as_list($list_ref)) {
		if (ref($item) eq 'HASH') {
			my %ingredient = %$item;
			$ingredient{id} = canonicalize_taxonomy_tag("en", "ingredients", $ingredient{id})
				if defined $ingredient{id};
			$ingredient{ingredients} = _fixture_ingredients($item->{ingredients}) if defined $item->{ingredients};
			push @ingredients, \%ingredient;
		}
		else {
			push @ingredients, {id => canonicalize_taxonomy_tag("en", "ingredients", $item)};
		}
	}
	return \@ingredients;
}

1;
