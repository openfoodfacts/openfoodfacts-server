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
categories, ingredients, labels, countries, nutrients, product names and ingredients lists.

Rules are stored in YAML files in the rules/ directory, grouped by product type and by target field,
e.g. rules/food/categories/beverages.yml. docs/dev/explain-tags-rules.md explains the format of the rules,
the design choices, and how to test a rule.

How it works:

=over

=item *

load_tags_rules() reads the YAML files, checks each rule, and compiles its conditions to Perl functions
(_compile_rule(), _compile_condition()). Invalid rules are reported and skipped.

=item *

evaluate_tags_rules() selects the rules of the categories of the product, runs their conditions,
and checks that the categories they would add are not incompatible with the other categories of the product.

=item *

apply_tags_rules_to_product() stores the result in the "rules" source of tags_sources.
add_tags_rules_data_quality_tags() adds the data quality tags, from check_quality().

=back

The tag fields that conditions can test, and the tag fields that rules can add tags to, are set for each flavor
in $options{tags_rules} (lib/ProductOpener/Config_off.pm). Flavors without this setting do not run tags rules.

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
use ProductOpener::Tags qw/is_a exists_taxonomy_tag gen_tags_list_with_parents get_property
	canonicalize_taxonomy_tag get_minimal_tags_subset %writable_tags_fields
	get_all_taxonomy_entries get_taxonomy_entry_synonyms_regexps join_regexps_longest_first %translations_to/;
use ProductOpener::Store qw/unac_string_perl/;
use ProductOpener::ProductsTags
	qw/set_field_input_tags_for_source get_field_input_tags_from_all_sources generate_field_tags_from_all_sources add_tag/;

use Data::DeepAccess qw(deep_get deep_set);
use File::Find qw/find/;
use JSON::MaybeXS;
use YAML::XS ();

# Name of the source in tags_sources.[field] where tags added by rules are stored
my $rules_source = "rules";

# Data quality warning added when a rule would add a category that is incompatible with another category
my $conflict_warning = "en:category-rules-conflict";

# Tag fields that conditions can test, e.g. "labels: en:organic" (flavor setting)
my %condition_tag_fields = ();
foreach my $field (@{deep_get(\%options, "tags_rules", "condition_tag_fields") // []}) {
	$condition_tag_fields{$field} = 1;
}

# Fields that the "add" action can write, and their kind:
# - "tags": tag fields (flavor setting), stored in tags_sources.[field].rules by apply_tags_rules_to_product()
# - "data_quality": computed fields, added by check_quality() through add_tags_rules_data_quality_tags()
my %add_fields = (
	data_quality_warnings => "data_quality",
	data_quality_info => "data_quality",
);
foreach my $field (@{deep_get(\%options, "tags_rules", "add_tag_fields") // []}) {
	$add_fields{$field} = "tags";
}

my %rule_keys = (id => 1, description => 1, if => 1, unless => 1, add => 1, tests => 1, comment => 1);

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
		return _new_ruleset();
	}

	if (not defined $tags_rules_for_product_type{$product_type}) {
		my $dir = $BASE_DIRS{RULES} . "/" . $product_type;
		my $ruleset_ref = load_tags_rules($dir);
		foreach my $error (@{$ruleset_ref->{errors}}) {
			$log->error("invalid tags rule", {dir => $dir, error => $error}) if $log->is_error();
		}
		$tags_rules_for_product_type{$product_type} = $ruleset_ref;
	}
	return $tags_rules_for_product_type{$product_type};
}

sub _new_ruleset() {
	return {rules => [], by_category => {}, by_id => {}, errors => []};
}

=head2 load_tags_rules ($dir)

Load, check and compile all the rules files (*.yml) in a directory and its subdirectories.
Each file contains a list of rules.

=head3 Return value

A hash ref (a "ruleset"):

=over

=item *

rules: list of compiled rules (see _compile_rule()), in file order

=item *

by_category: required category => list of rules. Used to select the rules to evaluate for a product.

=item *

by_id: rule id => rule

=item *

errors: list of errors (strings), prefixed with the file, the rule id and the place of the error in the rule
(e.g. "if.ingredients.first"). Rules with errors are not in "rules".

=back

=cut

sub load_tags_rules ($dir) {

	my $ruleset_ref = _new_ruleset();

	return $ruleset_ref if not -d $dir;

	my @files = ();
	find({wanted => sub {push @files, $File::Find::name if /\.ya?ml$/ and -f $_}, no_chdir => 1}, $dir);

	foreach my $file (sort @files) {

		my $rules_list_ref = eval {YAML::XS::LoadFile($file)};
		if ($@) {
			push @{$ruleset_ref->{errors}}, "$file: cannot parse YAML: $@";
			next;
		}
		next if not defined $rules_list_ref;
		if (ref($rules_list_ref) ne 'ARRAY') {
			push @{$ruleset_ref->{errors}}, "$file: the file must contain a list of rules";
			next;
		}

		foreach my $rule_def (@$rules_list_ref) {
			my $rule_ref = _compile_rule($ruleset_ref, $file, $rule_def);
			next if not defined $rule_ref;

			$rule_ref->{order} = scalar @{$ruleset_ref->{rules}};
			push @{$ruleset_ref->{rules}}, $rule_ref;
			$ruleset_ref->{by_id}{$rule_ref->{id}} = $rule_ref;
			foreach my $category (@{$rule_ref->{required_categories}}) {
				push @{$ruleset_ref->{by_category}{$category}}, $rule_ref;
			}
		}
	}

	return $ruleset_ref;
}

=head2 _compile_rule ($ruleset_ref, $file, $rule_def)

Check one rule of a rules file and compile it.

$rule_def is the rule as read from the YAML file: a mapping with the keys id, description, if, unless, add,
tests and comment (see docs/dev/explain-tags-rules.md).

Returns the compiled rule, or undef if the rule has errors (the errors are added to $ruleset_ref->{errors}).
The compiled rule is a hash ref with:

=over

=item *

id, description, file, tests (the match / no_match test products)

=item *

required_categories: the categories of the top-level "categories" condition of "if". The rule is only evaluated
for products in one of those categories (or in a child), and it can only add categories under them.

=item *

if_sub: function that returns true if all the "if" conditions match the product

=item *

unless_sub: function that returns true if any of the "unless" conditions matches (undef if there is no "unless")

=item *

add: field => list of tags to add

=back

=cut

sub _compile_rule ($ruleset_ref, $file, $rule_def) {

	if (ref($rule_def) ne 'HASH') {
		push @{$ruleset_ref->{errors}}, "$file: each rule must be a mapping";
		return;
	}

	# Rule ids are not prefixed with the file name: they are used in the misc tags en:tags-rule-[rule id],
	# which must not change when a rule is moved to another file.
	my $id = $rule_def->{id};
	if ((not defined $id) or ($id !~ /^[a-z0-9]+(-[a-z0-9]+)*$/)) {
		push @{$ruleset_ref->{errors}},
			"$file: rule id '" . ($id // '') . "' is missing or invalid (lowercase letters, digits and dashes)";
		return;
	}
	if (defined $ruleset_ref->{by_id}{$id} or $ruleset_ref->{seen_ids}{$id}) {
		push @{$ruleset_ref->{errors}}, "$file: rule $id: duplicate rule id";
		return;
	}
	$ruleset_ref->{seen_ids}{$id} = 1;

	my @errors = ();

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
		foreach my $tag (_as_list($rule_def->{if}{categories})) {
			push @required_categories, _check_tag("categories", $tag, "if.categories", \@errors);
		}
	}

	# Conditions: "if" matches when all its conditions match, "unless" when any of its conditions matches
	my $if_sub = _compile_condition($rule_def->{if}, "all", "if", \@errors);
	my $unless_sub;
	if (defined $rule_def->{unless}) {
		$unless_sub = _compile_condition($rule_def->{unless}, "any", "unless", \@errors);
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
			my @tags = ();
			foreach my $tag (_as_list($rule_def->{add}{$field})) {
				push @tags, _check_tag($field, $tag, "add.$field", \@errors);
			}
			push @errors, "add.$field: no tags" if not @tags;
			$add{$field} = \@tags;
		}
	}

	# Added categories must be children of the required categories.
	# A rule refines a category that a contributor already entered: it cannot add an unrelated category.
	# This keeps rules safe, and lets evaluate_tags_rules() select the rules from the categories of the product.
	foreach my $tag (@{$add{categories} // []}) {
		my $is_under_required = 0;
		foreach my $required (@required_categories) {
			if (($tag ne $required) and is_a("categories", $tag, $required)) {
				$is_under_required = 1;
			}
		}
		if (not $is_under_required) {
			push @errors,
				"add.categories: category '$tag' must be a child of the required categories ("
				. join(", ", @required_categories) . ")";
		}
	}

	# Tests: products that must match the rule, and products that must not match it (run by tags_rules.t)
	my $tests_ref = $rule_def->{tests} // {};
	if (ref($tests_ref) ne 'HASH') {
		push @errors, "tests: must be a mapping with match and no_match lists";
		$tests_ref = {};
	}
	foreach my $key (sort keys %$tests_ref) {
		if (($key ne "match") and ($key ne "no_match")) {
			push @errors, "tests: unknown key '$key'";
		}
		elsif (ref($tests_ref->{$key}) ne 'ARRAY') {
			push @errors, "tests.$key: must be a list of products";
		}
	}
	if (not @{$tests_ref->{match} // []}) {
		push @errors, "tests: at least one 'match' test product is required";
	}

	if (@errors) {
		foreach my $error (@errors) {
			push @{$ruleset_ref->{errors}}, "$file: rule $id: $error";
		}
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
	};
}

# Check that a tag of a rules file exists in the taxonomy of $field, and that it is written with its canonical id
# (so that rules can be searched for a tag). Returns the canonical id.
# $path is the place of the tag in the rule (for error messages), e.g. "if.categories".
sub _check_tag ($field, $tag, $path, $errors_ref) {

	if ((not defined $tag) or (ref($tag) ne '') or ($tag !~ /^[a-z]{2}:./)) {
		push @$errors_ref, "$path: '" . ($tag // '') . "' is not a tag id with a language prefix, e.g. en:example";
		return "";
	}

	my $taxonomy = $field;
	if ($field =~ /^data_quality/) {
		$taxonomy = "data_quality";
	}

	my $canonical_tag = canonicalize_taxonomy_tag("en", $taxonomy, $tag);
	if (not exists_taxonomy_tag($taxonomy, $canonical_tag)) {
		push @$errors_ref, "$path: tag '$tag' does not exist in the $taxonomy taxonomy";
	}
	elsif ($canonical_tag ne $tag) {
		push @$errors_ref, "$path: tag '$tag' is not the canonical id, use '$canonical_tag'";
	}
	return $canonical_tag;
}

# A value of a rules file can be a single value or a list: return it as a list
sub _as_list ($value) {
	if (not defined $value) {
		return ();
	}
	if (ref($value) eq 'ARRAY') {
		return @$value;
	}
	return ($value);
}

=head2 Conditions

Conditions are compiled to Perl functions that take an evaluation context (see _new_context())
and return true if the condition matches the product.

The YAML structure gives the logic, so that most rules need no explicit "all" or "any":

=over

=item *

Under "if" and "all", the keys of a mapping, or the items of a list, must all match (AND).

=item *

Under "any" and "unless", one of the keys of the mapping, or one of the items of the list, must match (OR).

=item *

Each item of a list is itself a condition whose keys must all match (AND).

=item *

A list of tags in a tag condition is an OR: categories: [en:x, en:y] matches products in en:x or in en:y.

=item *

not: condition: the condition must not match. not: [c1, c2]: none of the conditions matches.

=back

Each compile function takes the path of the condition in the rule (e.g. "if.any[1].ingredients"),
used in the error messages, and a reference to the list of errors.

=cut

# Compile a mapping or a list of conditions.
# $logic is "all" (all the parts must match) or "any" (one of the parts must match).
sub _compile_condition ($cond, $logic, $path, $errors_ref) {

	my @subs = ();

	if (ref($cond) eq 'ARRAY') {
		# Each item of the list is a condition whose parts must all match
		for (my $i = 0; $i < scalar @$cond; $i++) {
			push @subs, _compile_condition($cond->[$i], "all", $path . "[$i]", $errors_ref);
		}
	}
	elsif (ref($cond) eq 'HASH') {
		foreach my $key (sort keys %$cond) {
			my $sub = _compile_condition_key($key, $cond->{$key}, "$path.$key", $errors_ref);
			push @subs, $sub if defined $sub;
		}
	}
	else {
		push @$errors_ref,
			"$path: expected a mapping of conditions (e.g. {labels: en:organic}) or a list of conditions, got '"
			. ($cond // '') . "'";
	}

	if ($logic eq "all") {
		return sub ($ctx) {
			foreach my $sub (@subs) {
				return 0 if not $sub->($ctx);
			}
			return 1;
		};
	}
	else {
		return sub ($ctx) {
			foreach my $sub (@subs) {
				return 1 if $sub->($ctx);
			}
			return 0;
		};
	}
}

# Compile one key of a mapping of conditions: $key is the type of condition (e.g. "labels", "ingredients", "any")
# and $value its parameters. Returns a function, or undef if the condition is unknown.
sub _compile_condition_key ($key, $value, $path, $errors_ref) {

	if ($key eq 'all') {
		return _compile_condition($value, "all", $path, $errors_ref);
	}
	elsif ($key eq 'any') {
		return _compile_condition($value, "any", $path, $errors_ref);
	}
	elsif ($key eq 'not') {
		# not: [c1, c2] matches when none of the conditions matches
		my $logic = (ref($value) eq 'ARRAY') ? "any" : "all";
		my $sub = _compile_condition($value, $logic, $path, $errors_ref);
		return sub ($ctx) {return not $sub->($ctx)};
	}
	elsif ($condition_tag_fields{$key}) {
		return _compile_tags_condition($key, $value, $path, $errors_ref);
	}
	elsif ($key eq 'ingredients') {
		return _compile_ingredients_condition($value, $path, $errors_ref);
	}
	elsif ($key eq 'nutrients') {
		return _compile_nutrients_condition($value, $path, $errors_ref);
	}
	elsif ($key eq 'specific_ingredients') {
		return _compile_specific_ingredients_condition($value, $path, $errors_ref);
	}
	elsif ($key eq 'name') {
		return _compile_regexp_condition($value, ["product_name", "generic_name"], $path, $errors_ref);
	}
	elsif ($key eq 'ingredients_text') {
		return _compile_regexp_condition($value, ["ingredients_text"], $path, $errors_ref);
	}

	push @$errors_ref, "$path: unknown condition '$key'";
	return;
}

# Tag condition (e.g. labels: en:organic): the product must have one of the tags, or a child of one of them
sub _compile_tags_condition ($field, $value, $path, $errors_ref) {

	my @tags = ();
	foreach my $tag (_as_list($value)) {
		push @tags, _check_tag($field, $tag, $path, $errors_ref);
	}
	push @$errors_ref, "$path: no tags" if not @tags;

	return sub ($ctx) {
		my $product_tags_ref = _get_product_tags($ctx, $field);
		foreach my $tag (@tags) {
			return 1 if $product_tags_ref->{$tag};
		}
		return 0;
	};
}

# Ingredients condition: a mapping of ingredients conditions (contains, first, in_first, processing, known)
# that must all match. Ingredients are matched with is_a(), so a condition on en:wholemeal-flour
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

		if ($key eq 'contains') {
			# One of the ingredients, at any depth, is one of the listed ingredients (or a child)
			my @of = _check_ingredients($value, $key_path, $errors_ref);
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
			# The first ingredient is one of the listed ingredients (or a child)
			my @of = _check_ingredients($value, $key_path, $errors_ref);
			push @subs, sub ($ctx) {
				my $first_ingredient_ref = deep_get($ctx->{product}, "ingredients", 0);
				return ((defined $first_ingredient_ref) and _ingredient_is_a($first_ingredient_ref, \@of));
			};
		}
		elsif ($key eq 'in_first') {
			# One of the first n ingredients is one of the listed ingredients (or a child)
			if ((ref($value) ne 'HASH') or (($value->{n} // '') !~ /^\d+$/) or (not defined $value->{of})) {
				push @$errors_ref, "$key_path: must be a mapping with n (number) and of (ingredients)";
				next;
			}
			my $n = $value->{n};
			my @of = _check_ingredients($value->{of}, $key_path, $errors_ref);
			push @subs, sub ($ctx) {
				my $ingredients_ref = $ctx->{product}{ingredients} // [];
				for (my $i = 0; ($i < $n) and ($i < scalar @$ingredients_ref); $i++) {
					return 1 if _ingredient_is_a($ingredients_ref->[$i], \@of);
				}
				return 0;
			};
		}
		elsif ($key eq 'processing') {
			# One of the ingredients, at any depth, has one of the listed processings (or a child),
			# e.g. "Kartoffeln getrocknet", "Sahnepulver" (en:cream with en:powder)
			my @of = map {_check_tag("ingredients_processing", $_, $key_path, $errors_ref)} _as_list($value);
			push @subs, sub ($ctx) {
				my $found = 0;
				_walk_ingredients(
					$ctx->{product}{ingredients},
					sub ($ingredient_ref) {
						foreach my $processing (split(/,/, $ingredient_ref->{processing} // '')) {
							$found = 1 if grep {is_a("ingredients_processing", $processing, $_)} @of;
						}
					}
				);
				return $found;
			};
		}
		elsif ($key eq 'known') {
			# known: true -> the product has an ingredients list, and all ingredients (at all depths) are known.
			# Uses the counts computed by compute_ingredients_tags() (in extract_ingredients_from_text())
			my $expected = $value ? 1 : 0;
			push @subs, sub ($ctx) {
				my $ingredients_n = $ctx->{product}{ingredients_n} // 0;
				my $unknown_ingredients_n = $ctx->{product}{unknown_ingredients_n} // 0;
				my $known = (($ingredients_n > 0) and ($unknown_ingredients_n == 0)) ? 1 : 0;
				return $known == $expected;
			};
		}
		else {
			push @$errors_ref, "$path: unknown condition '$key'";
		}
	}

	return sub ($ctx) {
		foreach my $sub (@subs) {
			return 0 if not $sub->($ctx);
		}
		return 1;
	};
}

sub _check_ingredients ($value, $path, $errors_ref) {
	my @ingredients = ();
	foreach my $ingredient (_as_list($value)) {
		push @ingredients, _check_tag("ingredients", $ingredient, $path, $errors_ref);
	}
	return @ingredients;
}

# Call $callback for each ingredient and sub-ingredient
sub _walk_ingredients ($ingredients_ref, $callback) {
	return if ref($ingredients_ref) ne 'ARRAY';
	foreach my $ingredient_ref (@$ingredients_ref) {
		next if ref($ingredient_ref) ne 'HASH';
		$callback->($ingredient_ref);
		_walk_ingredients($ingredient_ref->{ingredients}, $callback);
	}
	return;
}

# Return 1 if the ingredient is one of the listed ingredients, or a child of one of them
sub _ingredient_is_a ($ingredient_ref, $of_ref) {
	my $id = $ingredient_ref->{id};
	return 0 if not defined $id;
	foreach my $of (@$of_ref) {
		return 1 if is_a("ingredients", $id, $of);
	}
	return 0;
}

# Nutrients condition: nutrient id => {min, max}, all must match.
# Values are read from the aggregated nutrition set, per 100g or 100ml, as sold.
sub _compile_nutrients_condition ($spec, $path, $errors_ref) {

	if ((ref($spec) ne 'HASH') or (not %$spec)) {
		push @$errors_ref, "$path: must be a mapping of nutrient ids to {min, max}";
		return;
	}

	my @checks = ();
	foreach my $nid (sort keys %$spec) {
		my $range_ref = $spec->{$nid};
		if (ref($range_ref) ne 'HASH') {
			push @$errors_ref, "$path.$nid: must be a mapping with min and/or max";
			next;
		}
		my ($min, $max) = ($range_ref->{min}, $range_ref->{max});
		if ((not defined $min) and (not defined $max)) {
			push @$errors_ref, "$path.$nid: min or max is required";
		}
		foreach my $limit ($min, $max) {
			if ((defined $limit) and ($limit !~ /^-?\d+(\.\d+)?$/)) {
				push @$errors_ref, "$path.$nid: min and max must be numbers";
			}
		}
		push @checks, {nid => $nid, min => $min, max => $max};
	}

	return sub ($ctx) {
		my $set_ref = deep_get($ctx->{product}, "nutrition", "aggregated_set");
		return 0 if not defined $set_ref;
		return 0 if ($set_ref->{preparation} // "as_sold") ne "as_sold";
		return 0 if ($set_ref->{per} // "100g") !~ /^100(g|ml)$/;

		foreach my $check_ref (@checks) {
			my $nutrient_ref = deep_get($set_ref, "nutrients", $check_ref->{nid});
			return 0 if not defined $nutrient_ref;
			my $value = $nutrient_ref->{value};
			return 0 if (not defined $value) or ($value !~ /^-?\d+(\.\d+)?(e-?\d+)?$/i);
			# A "< 1" value is not a minimum, and a "> 1" value is not a maximum
			my $modifier = $nutrient_ref->{modifier} // "";
			if (defined $check_ref->{min}) {
				return 0 if ($value < $check_ref->{min}) or ($modifier =~ /^(<|≤|<=)$/);
			}
			if (defined $check_ref->{max}) {
				return 0 if ($value > $check_ref->{max}) or ($modifier =~ /^(>|≥|>=)$/);
			}
		}
		return 1;
	};
}

# Specific ingredients condition: ingredient id => {min, max} percent, all must match.
# Specific ingredients are the mentions parsed from the ingredients text, e.g. "cocoa: 55% minimum"
# (see parse_specific_ingredients_from_text() in Ingredients.pm). A specific ingredient matches
# the ingredient id or one of its children.
sub _compile_specific_ingredients_condition ($spec, $path, $errors_ref) {

	if ((ref($spec) ne 'HASH') or (not %$spec)) {
		push @$errors_ref, "$path: must be a mapping of ingredient ids to {min, max}, e.g. en:cocoa: {min: 70}";
		return;
	}

	my @checks = ();
	foreach my $ingredient (sort keys %$spec) {
		my $id = _check_tag("ingredients", $ingredient, $path, $errors_ref);
		my $range_ref = $spec->{$ingredient};
		if ((ref($range_ref) ne 'HASH') or ((not defined $range_ref->{min}) and (not defined $range_ref->{max}))) {
			push @$errors_ref, "$path.$ingredient: must be a mapping with min and/or max";
			next;
		}
		push @checks, {id => $id, min => $range_ref->{min}, max => $range_ref->{max}};
	}

	return sub ($ctx) {
		foreach my $check_ref (@checks) {
			my $found = 0;
			foreach my $specific_ingredient_ref (@{$ctx->{product}{specific_ingredients} // []}) {
				my $percent = $specific_ingredient_ref->{percent};
				next if (not defined $percent) or (not defined $specific_ingredient_ref->{id});
				next if not is_a("ingredients", $specific_ingredient_ref->{id}, $check_ref->{id});
				next if (defined $check_ref->{min}) and ($percent < $check_ref->{min});
				next if (defined $check_ref->{max}) and ($percent > $check_ref->{max});
				$found = 1;
				last;
			}
			return 0 if not $found;
		}
		return 1;
	};
}

# Text is matched case- and accent-insensitively
sub _normalize_text ($text) {
	return lc(unac_string_perl($text));
}

# Taxonomies whose entries can be matched in text fields
my %text_taxonomies = map {$_ => 1} qw(categories labels ingredients ingredients_processing);

# Text condition on text fields: a mapping of language codes (or "any") to regular expressions, and/or
# of taxonomies to entries (e.g. labels: en:no-caffeine). Matches if one of them matches one of the texts.
# - regular expressions: fields are [field]_[lc], and [field] when [lc] is the main language of the product,
#   "any" matches all languages. One language is enough.
# - taxonomy entries: each text in a language is matched with the synonyms of the entries (and of their
#   children) in that language (and xx:), as whole words. Translations are maintained in the taxonomies.
sub _compile_regexp_condition ($spec, $fields_ref, $path, $errors_ref) {

	if ((ref($spec) ne 'HASH') or (not %$spec)) {
		push @$errors_ref,
			"$path: must be a mapping of language codes (or 'any') to regular expressions, or of taxonomies to entries";
		return;
	}

	my %regexps = ();
	my %entries = ();
	# languages: any -> the synonyms of the taxonomy entries in all languages match texts in all languages
	my $all_languages = 0;
	foreach my $key (sort keys %$spec) {
		if ($key eq 'languages') {
			if (($spec->{$key} // '') ne 'any') {
				push @$errors_ref, "$path.languages: the only possible value is 'any'";
			}
			$all_languages = 1;
			next;
		}
		if ($text_taxonomies{$key}) {
			my @tags = map {_check_tag($key, $_, "$path.$key", $errors_ref)} _as_list($spec->{$key});
			push @$errors_ref, "$path.$key: no entries" if not @tags;
			$entries{$key} = \@tags;
			next;
		}
		if ($key !~ /^([a-z]{2}|any)$/) {
			push @$errors_ref, "$path: invalid language code or taxonomy '$key'";
			next;
		}
		my $pattern = $spec->{$key};
		if ((not defined $pattern) or (ref($pattern) ne '') or ($pattern eq '')) {
			push @$errors_ref, "$path.$key: invalid regular expression";
			next;
		}
		my $normalized_pattern = unac_string_perl($pattern);
		my $regexp = eval {qr/$normalized_pattern/i};
		if (not defined $regexp) {
			push @$errors_ref, "$path.$key: invalid regular expression '$pattern': $@";
			next;
		}
		$regexps{$key} = $regexp;
	}

	# Regular expressions of the taxonomy entries, per language, built when first needed
	my %entries_regexps = ();

	return sub ($ctx) {
		my $product_ref = $ctx->{product};
		foreach my $lc (keys %regexps) {
			foreach my $text (_get_texts($product_ref, $fields_ref, $lc)) {
				return 1 if _normalize_text($text) =~ $regexps{$lc};
			}
		}
		if (%entries) {
			foreach my $text_ref (_get_texts_with_lc($product_ref, $fields_ref)) {
				my ($lc, $text) = @$text_ref;
				$lc = "any" if $all_languages;
				# exists: also cache languages without synonyms (undef)
				$entries_regexps{$lc} = _taxonomy_entries_regexp(\%entries, $lc) if not exists $entries_regexps{$lc};
				return 1 if (defined $entries_regexps{$lc}) and (_normalize_text($text) =~ $entries_regexps{$lc});
			}
		}
		return 0;
	};
}

# Children of the taxonomy entries (cached)
my %children_cache = ();

sub _taxonomy_entries_and_children ($taxonomy, $tags_ref) {
	my $key = $taxonomy . ":" . join(",", @$tags_ref);
	if (not defined $children_cache{$key}) {
		my %parents = map {$_ => 1} @$tags_ref;
		$children_cache{$key} = [
			grep {
				my $entry = $_;
				$parents{$entry} or grep {is_a($taxonomy, $entry, $_)} @$tags_ref
			} get_all_taxonomy_entries($taxonomy)
		];
	}
	return @{$children_cache{$key}};
}

# Regular expression that matches the synonyms in language $lc (and xx) of taxonomy entries and of their
# children, in a normalized text (see _normalize_text()). Returns undef if there are no synonyms in $lc
sub _taxonomy_entries_regexp ($entries_ref, $lc) {
	my %synonyms_regexps = ();
	foreach my $taxonomy (keys %$entries_ref) {
		foreach my $entry (_taxonomy_entries_and_children($taxonomy, $entries_ref->{$taxonomy})) {
			my @languages = ($lc eq 'any') ? (sort keys %{$translations_to{$taxonomy}{$entry} // {}}) : ($lc, "xx");
			# spaces, dashes and apostrophes are interchangeable
			foreach my $synonym_regexp (
				map {get_taxonomy_entry_synonyms_regexps($taxonomy, $entry, $_, {loose_separators => 1})} @languages)
			{
				# whole words, except for languages written without spaces between words
				my $type = ($synonym_regexp =~ /[\p{Han}\p{Hiragana}\p{Katakana}\p{Thai}]/) ? "anywhere" : "words";
				$synonyms_regexps{$type}{$synonym_regexp} = 1;
			}
		}
	}
	return if not %synonyms_regexps;
	my @alternatives = ();
	foreach my $type (sort keys %synonyms_regexps) {
		my $alternatives = join_regexps_longest_first(keys %{$synonyms_regexps{$type}});
		push @alternatives, ($type eq "words") ? "(?<!\\w)(?:$alternatives)(?!\\w)" : "(?:$alternatives)";
	}
	my $regexp = join('|', @alternatives);
	return qr/$regexp/i;
}

# Return [lc, text] for the non-empty values of text fields: [field]_[lc], and [field] in the main language
sub _get_texts_with_lc ($product_ref, $fields_ref) {
	my @texts = ();
	foreach my $field (@$fields_ref) {
		foreach my $key (keys %$product_ref) {
			my $lc;
			if ($key =~ /^${field}_([a-z]{2})$/) {
				$lc = $1;
			}
			elsif ($key eq $field) {
				$lc = $product_ref->{lc};
			}
			next if not defined $lc;
			my $text = $product_ref->{$key};
			push @texts, [$lc, $text] if (defined $text) and (ref($text) eq '') and ($text ne '');
		}
	}
	return @texts;
}

# Return the non-empty values of text fields in a language ("any": all languages)
sub _get_texts ($product_ref, $fields_ref, $lc) {
	my @texts = ();
	foreach my $field (@$fields_ref) {
		if ($lc eq 'any') {
			foreach my $key (keys %$product_ref) {
				push @texts, $product_ref->{$key} if $key =~ /^${field}(_[a-z]{2})?$/;
			}
		}
		else {
			push @texts, $product_ref->{$field . "_" . $lc};
			push @texts, $product_ref->{$field} if ($product_ref->{lc} // '') eq $lc;
		}
	}
	my @non_empty_texts = grep {(defined $_) and (ref($_) eq '') and ($_ ne '')} @texts;
	return @non_empty_texts;
}

=head2 Evaluation context

The evaluation context caches, for one product, the tags used by the conditions.

=cut

sub _new_context ($product_ref) {
	return {product => $product_ref, tags => {}};
}

# Return the tags of the product for a field, with their parents, as a hash {tag => 1}.
# For fields entered by contributors, producers etc. (e.g. categories, labels), the tags come from all the sources
# of tags_sources.[field] except the "rules" source, so that the output of a rule is never the input of another rule.
# For computed fields (e.g. states), the tags are [field]_tags.
sub _get_product_tags ($ctx, $field) {

	if (not defined $ctx->{tags}{$field}) {
		my @tags = ();
		if ($writable_tags_fields{$field}) {
			my @input_tags = get_field_input_tags_from_all_sources($ctx->{product}, $field, [$rules_source]);
			@tags = gen_tags_list_with_parents("en", $field, \@input_tags);
		}
		else {
			@tags = @{$ctx->{product}{$field . "_tags"} // []};
		}

		my %tags_set = ();
		foreach my $tag (@tags) {
			$tags_set{$tag} = 1;
		}
		$ctx->{tags}{$field} = \%tags_set;
	}
	return $ctx->{tags}{$field};
}

=head2 Conflicts

A rule never adds a category that is incompatible with another category of the product (an existing category,
or a category added by another rule), or with a label of the product. Incompatible tags are listed in the
incompatible_with:en property of the categories taxonomy, and are also checked on the parents of the categories.

=cut

# Return the incompatible_with:en property of a category as a list of [tagtype, canonical tag id],
# e.g. "categories:en:vegan-products, labels:en:vegan" -> (["categories", "en:vegan-products"], ["labels", "en:vegan"])
my %incompatible_with_cache = ();

sub _get_incompatible_tags ($category) {

	if (not defined $incompatible_with_cache{$category}) {
		my @incompatible_tags = ();
		my $property = get_property("categories", $category, "incompatible_with:en") // "";
		foreach my $item (split(/\s*,\s*/, $property)) {
			if ($item =~ /^\s*(categories|labels):(.+?)\s*$/) {
				my ($tagtype, $tag) = ($1, $2);
				push @incompatible_tags, [$tagtype, canonicalize_taxonomy_tag("en", $tagtype, $tag)];
			}
		}
		$incompatible_with_cache{$category} = \@incompatible_tags;
	}
	return @{$incompatible_with_cache{$category}};
}

# Return the tags that are incompatible with a category added by a rule.
# $categories_ref: all the categories that the product would have with the added categories (with parents)
# $labels_ref: the labels of the product (with parents)
sub _get_conflicts ($added_category, $categories_ref, $labels_ref) {

	# The added category and its parents
	my %added_and_parents = ();
	foreach my $category (gen_tags_list_with_parents("en", "categories", [$added_category])) {
		$added_and_parents{$category} = 1;
	}

	my %conflicts = ();

	# The added category (or a parent) says that it is incompatible with a category or a label of the product
	foreach my $category (keys %added_and_parents) {
		foreach my $incompatible_ref (_get_incompatible_tags($category)) {
			my ($tagtype, $tag) = @$incompatible_ref;
			if (($tagtype eq 'categories') and $categories_ref->{$tag} and (not $added_and_parents{$tag})) {
				$conflicts{$tag} = 1;
			}
			elsif (($tagtype eq 'labels') and $labels_ref->{$tag}) {
				$conflicts{"labels:$tag"} = 1;
			}
		}
	}

	# Another category of the product says that it is incompatible with the added category (or a parent)
	foreach my $category (keys %$categories_ref) {
		next if $added_and_parents{$category};
		foreach my $incompatible_ref (_get_incompatible_tags($category)) {
			my ($tagtype, $tag) = @$incompatible_ref;
			if (($tagtype eq 'categories') and $added_and_parents{$tag}) {
				$conflicts{$category} = 1;
			}
		}
	}

	my @conflicts = sort keys %conflicts;
	return @conflicts;
}

=head2 evaluate_tags_rules ($product_ref, $options_ref = {})

Evaluate the rules for a product. The product is not modified.

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

already: rule id => list of the categories the rule would add, but that the product already has

=item *

conflicts: list of { rule, tag, with } for categories that were not added because of a conflict

=back

=cut

sub evaluate_tags_rules ($product_ref, $options_ref = {}) {

	my $ruleset_ref = $options_ref->{rules}
		// get_tags_rules($product_ref->{product_type} // $options{product_type} // "food");

	my $result_ref = {added => {}, matched => [], already => {}, conflicts => []};

	my $ctx = _new_context($product_ref);
	my $product_categories_ref = _get_product_tags($ctx, "categories");

	# 1. Run the rules of the categories of the product
	foreach my $rule_ref (_get_candidate_rules($ruleset_ref, $product_categories_ref, $options_ref->{rule_ids})) {

		next if not $rule_ref->{if_sub}->($ctx);
		next if (defined $rule_ref->{unless_sub}) and $rule_ref->{unless_sub}->($ctx);

		push @{$result_ref->{matched}}, $rule_ref->{id};

		foreach my $field (sort keys %{$rule_ref->{add}}) {
			foreach my $tag (@{$rule_ref->{add}{$field}}) {
				if (($field eq 'categories') and $product_categories_ref->{$tag}) {
					push @{$result_ref->{already}{$rule_ref->{id}}}, $tag;
				}
				else {
					_add_result($result_ref, $field, $tag, $rule_ref->{id});
				}
			}
		}
	}

	# 2. Remove the added categories that are incompatible with the other categories that the product would have
	# (existing categories, and categories added by other rules), or with its labels.
	# Conflicts are only checked for categories: incompatible_with:en is only set in the categories and labels
	# taxonomies, and rules can only add categories (and data quality tags) for now.
	my $added_categories_ref = $result_ref->{added}{categories};
	if (defined $added_categories_ref) {

		my %categories_after_rules = %$product_categories_ref;
		foreach my $category (gen_tags_list_with_parents("en", "categories", [keys %$added_categories_ref])) {
			$categories_after_rules{$category} = 1;
		}
		my $product_labels_ref = _get_product_tags($ctx, "labels");

		foreach my $tag (sort keys %$added_categories_ref) {
			my @conflicts = _get_conflicts($tag, \%categories_after_rules, $product_labels_ref);
			next if not @conflicts;
			foreach my $rule_id (@{$added_categories_ref->{$tag}}) {
				push @{$result_ref->{conflicts}}, {rule => $rule_id, tag => $tag, with => \@conflicts};
				_add_result($result_ref, "data_quality_warnings", $conflict_warning, $rule_id);
			}
			delete $added_categories_ref->{$tag};
		}
		delete $result_ref->{added}{categories} if not %$added_categories_ref;
	}

	return $result_ref;
}

# Return the rules to evaluate for a product: the rules whose required categories the product has, in file order
sub _get_candidate_rules ($ruleset_ref, $product_categories_ref, $rule_ids_ref) {

	my %selected_rule_ids = ();
	foreach my $rule_id (@{$rule_ids_ref // []}) {
		$selected_rule_ids{$rule_id} = 1;
	}

	my %candidates = ();
	foreach my $category (keys %$product_categories_ref) {
		foreach my $rule_ref (@{$ruleset_ref->{by_category}{$category} // []}) {
			next if (defined $rule_ids_ref) and (not $selected_rule_ids{$rule_ref->{id}});
			$candidates{$rule_ref->{order}} = $rule_ref;
		}
	}

	my @candidate_rules = ();
	foreach my $order (sort {$a <=> $b} keys %candidates) {
		push @candidate_rules, $candidates{$order};
	}
	return @candidate_rules;
}

# Add a rule id to the list of rule ids for a tag: $result_ref->{added}{$field}{$tag}
sub _add_result ($result_ref, $field, $tag, $rule_id) {
	my $rule_ids_ref = $result_ref->{added}{$field}{$tag} //= [];
	if (not grep {$_ eq $rule_id} @$rule_ids_ref) {
		push @$rule_ids_ref, $rule_id;
	}
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

	# Fields to update: tag fields with tags added by rules, and fields that already have a rules source
	my %fields = ();
	foreach my $field (keys %{$result_ref->{added}}) {
		$fields{$field} = 1 if $add_fields{$field} eq 'tags';
	}
	foreach my $field (keys %{$product_ref->{tags_sources} // {}}) {
		$fields{$field} = 1 if defined deep_get($product_ref, "tags_sources", $field, $rules_source);
	}

	foreach my $field (sort keys %fields) {

		my $added_ref = $result_ref->{added}{$field} // {};
		my $existing_source_ref = deep_get($product_ref, "tags_sources", $field, $rules_source);

		# No rule adds tags any more: remove the rules source
		if (not %$added_ref) {
			delete $product_ref->{tags_sources}{$field}{$rules_source};
			generate_field_tags_from_all_sources($product_ref, $field);
			next;
		}

		my @tags = sort {$a cmp $b} get_minimal_tags_subset($field, [keys %$added_ref]);
		my %rule_ids_for_tag = ();
		foreach my $tag (keys %$added_ref) {
			$rule_ids_for_tag{$tag} = [sort @{$added_ref->{$tag}}];
		}

		if (_rules_source_is_unchanged($existing_source_ref, \@tags, \%rule_ids_for_tag)) {
			# Keep last_updated_t, but make sure that [field]_tags contains the tags of the rules source
			generate_field_tags_from_all_sources($product_ref, $field);
			next;
		}

		# set_field_input_tags_for_source() also regenerates [field]_tags from all sources
		set_field_input_tags_for_source($product_ref, "en", $field, $rules_source, join(",", @tags));
		deep_set($product_ref, "tags_sources", $field, $rules_source, "rules", \%rule_ids_for_tag);
	}

	_set_tags_rules_misc_tags($product_ref, $result_ref);

	return $result_ref;
}

# Return 1 if the rules source already has the same tags and the same rule ids for each tag
my $canonical_json = JSON::MaybeXS->new->canonical;

sub _rules_source_is_unchanged ($existing_source_ref, $tags_ref, $rule_ids_for_tag_ref) {
	return 0 if not defined $existing_source_ref;
	my $existing = {tags => [sort @{$existing_source_ref->{tags} // []}], rules => $existing_source_ref->{rules} // {}};
	my $new = {tags => $tags_ref, rules => $rule_ids_for_tag_ref};
	return $canonical_json->encode($existing) eq $canonical_json->encode($new);
}

# Set the misc tags en:tags-added-by-rules and en:tags-rule-[rule id]
sub _set_tags_rules_misc_tags ($product_ref, $result_ref) {

	# Keep the misc tags that do not come from the rules
	my @misc_tags = grep {not /^en:tags-(added-by-rules|rule-.*)$/} @{$product_ref->{misc_tags} // []};

	my %contributing_rules = ();
	my $tags_added = 0;
	foreach my $field (keys %{$result_ref->{added}}) {
		foreach my $tag (keys %{$result_ref->{added}{$field}}) {
			$tags_added = 1 if $add_fields{$field} eq 'tags';
			foreach my $rule_id (@{$result_ref->{added}{$field}{$tag}}) {
				$contributing_rules{$rule_id} = 1;
			}
		}
	}

	push @misc_tags, "en:tags-added-by-rules" if $tags_added;
	foreach my $rule_id (sort keys %contributing_rules) {
		push @misc_tags, "en:tags-rule-$rule_id";
	}

	if (@misc_tags or (defined $product_ref->{misc_tags})) {
		$product_ref->{misc_tags} = \@misc_tags;
	}
	return;
}

=head2 add_tags_rules_data_quality_tags ($product_ref, $options_ref = {})

Add the data quality tags of the rules (e.g. rules that add data_quality_warnings, and conflicts)
to the data_quality_[level]_tags of the product.

Called by check_quality() after it resets the data quality tags.

The rules are evaluated again (they were also evaluated by apply_tags_rules_to_product()). This is cheap:
only the rules of the categories of the product are evaluated, and most products have none.

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

Build a product from a test product of a rules file, so that rule authors only need to write tag ids:

	categories: [en:colas]                    # -> tags_sources.categories (also labels, countries, origins)
	states: [en:ingredients-to-be-completed]  # -> states_tags with parents (computed fields)
	ingredients: [en:water, {id: en:sugar, percent: 10, ingredients: [...]}]  # also sets ingredients_n, unknown_ingredients_n
	nutrients: {cocoa: 55}                    # -> nutrition.aggregated_set (per 100g, as sold)
	product_name_fr: Moutarde douce           # other fields are copied as is

Tags and ingredient ids are canonicalized (e.g. en:citric-acid -> en:e330), so test products can use synonyms.

=cut

sub build_product_from_tags_rules_fixture ($fixture_ref) {

	my $product_ref = {lc => "en"};

	foreach my $key (keys %$fixture_ref) {
		my $value = $fixture_ref->{$key};

		if ($condition_tag_fields{$key}) {
			my @tags = ();
			foreach my $tag (_as_list($value)) {
				push @tags, canonicalize_taxonomy_tag("en", $key, $tag);
			}
			if ($writable_tags_fields{$key}) {
				deep_set($product_ref, "tags_sources", $key, "test", "tags", \@tags);
				generate_field_tags_from_all_sources($product_ref, $key);
			}
			else {
				$product_ref->{$key . "_tags"} = [gen_tags_list_with_parents("en", $key, \@tags)];
			}
		}
		elsif ($key eq 'ingredients') {
			$product_ref->{ingredients} = _build_fixture_ingredients($value);
			# Counts of ingredients and unknown ingredients, as computed by compute_ingredients_tags()
			my ($ingredients_n, $unknown_ingredients_n) = (0, 0);
			_walk_ingredients(
				$product_ref->{ingredients},
				sub ($ingredient_ref) {
					$ingredients_n++;
					$unknown_ingredients_n++ if not exists_taxonomy_tag("ingredients", $ingredient_ref->{id} // "");
				}
			);
			$product_ref->{ingredients_n} = $ingredients_n;
			$product_ref->{unknown_ingredients_n} = $unknown_ingredients_n;
		}
		elsif ($key eq 'nutrients') {
			my %nutrients = ();
			foreach my $nid (keys %$value) {
				$nutrients{$nid} = {value => $value->{$nid}, unit => "g"};
			}
			$product_ref->{nutrition}{aggregated_set}
				= {per => "100g", preparation => "as_sold", nutrients => \%nutrients};
		}
		else {
			$product_ref->{$key} = $value;
		}
	}

	return $product_ref;
}

sub _build_fixture_ingredients ($ingredients_list_ref) {
	my @ingredients = ();
	foreach my $item (_as_list($ingredients_list_ref)) {
		if (ref($item) eq 'HASH') {
			my %ingredient = %$item;
			if (defined $ingredient{id}) {
				$ingredient{id} = canonicalize_taxonomy_tag("en", "ingredients", $ingredient{id});
			}
			if (defined $item->{ingredients}) {
				$ingredient{ingredients} = _build_fixture_ingredients($item->{ingredients});
			}
			push @ingredients, \%ingredient;
		}
		else {
			push @ingredients, {id => canonicalize_taxonomy_tag("en", "ingredients", $item)};
		}
	}
	return \@ingredients;
}

1;
