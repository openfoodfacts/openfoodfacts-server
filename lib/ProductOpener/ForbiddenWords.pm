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

=encoding UTF-8

=head1 NAME

ProductOpener::ForbiddenWords - detect forbidden words, vulgarities, slurs, and vandalism in product data

=head1 SYNOPSIS

    use ProductOpener::ForbiddenWords qw(
        check_forbidden_words
        contains_forbidden_words
        is_barcode_allowed
        init_forbidden_words
        init_allowlist
        $ALL_FORBIDDEN_WORDS_REGEXP_STR
    );

    # Check a product and populate data_quality_warnings_tags
    check_forbidden_words($product_ref);

    # Check a specific string in a given language
    if (contains_forbidden_words("some text", "fr")) {
        ...
    }

=head1 DESCRIPTION

C<ProductOpener::ForbiddenWords> checks product fields (product names, ingredients, brands)
for forbidden words such as insults, vulgarities, slurs, and intentional vandalism.

When detected during data quality checks, corresponding warning tags are added to
C<$product_ref-E<gt>{data_quality_warnings_tags}>:

=over 4

=item * C<en:product-name-contains-forbidden-words>

=item * C<en:ingredients-contain-forbidden-words>

=item * C<en:brands-contain-forbidden-words>

=item * C<en:forbidden-words-warnings>

=back

Words are defined by language as well as language-independent universal slurs (C<xx>).
To avoid committing obscenities to source control, word lists are loaded from an
uncommitted / gitignored local file (C<conf/forbidden_words.txt>) or fetched from external
repositories (e.g. LDNOOBW) via C<make update_forbidden_words>.

Legitimate novelty products, culinary exceptions (e.g. "couilles de singe", "spotted dick",
"cacao", "cornichon", German "Pute"), and known barcodes are configured in
C<conf/forbidden_words_allowlist.txt>.

=cut

package ProductOpener::ForbiddenWords;

use utf8;
use ProductOpener::PerlStandards;
use feature qw(signatures);
no warnings qw(experimental::signatures);
use Exporter qw< import >;

use File::Basename qw(dirname);

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS $ALL_FORBIDDEN_WORDS_REGEXP_STR);
	@EXPORT_OK = qw(
		&check_forbidden_words
		&contains_forbidden_words
		&get_forbidden_words_list
		&get_forbidden_words_regexp
		&init_forbidden_words
		&init_allowlist
		&is_barcode_allowed
		&set_forbidden_words
		&set_allowed_barcodes
		&set_allowlist_patterns
		$ALL_FORBIDDEN_WORDS_REGEXP_STR
	);
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

my %forbidden_words_by_lang = ();
my %compiled_regexps = ();
my %allowed_barcodes = ();
my %allowlist_patterns = ();
my %country_rules = ();
my $initialized_words = 0;
my $initialized_allowlist = 0;

# Neutral fallback placeholders - actual obscenities are NEVER committed in this code.
# Run 'make update_forbidden_words' to fetch curated word lists into conf/forbidden_words.txt.
my %DEFAULT_FORBIDDEN_WORDS = (
	xx => [qw(test_vandalism_placeholder test_slur_placeholder)],
	fr => [qw(test_insulte_fr test_vulgarite_fr)],
	en => [qw(test_insult_en test_profanity_en)],
	es => [qw(test_insult_es)],
	de => [qw(test_insult_de)],
	it => [qw(test_insult_it)],
);

sub _unaccent ($s) {
	return '' unless defined $s;
	$s =~ tr/àáâãäåçèéêëìíîïñòóôõöùúûüýÿÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝŸ/aaaaaaceeeeiiiinooooouuuuyyaaaaaaceeeeiiiinooooouuuuyy/;
	$s =~ tr/ășțşţĂȘȚŞŢ/aststASTST/;
	$s =~ s/œ|Œ/oe/g;
	return $s;
}

sub _word_to_accent_regex ($word) {
	my $escaped = quotemeta($word);
	$escaped =~ s/a/[aàâä]/gi;
	$escaped =~ s/e/[eéèêë]/gi;
	$escaped =~ s/i/[iîï]/gi;
	$escaped =~ s/o/[oôö]/gi;
	$escaped =~ s/u/[uùûü]/gi;
	$escaped =~ s/c/[cç]/gi;
	$escaped =~ s/\\ /\\s+/g;
	return $escaped;
}

sub _find_conf_file ($filename) {
	my $base = dirname(dirname(dirname(__FILE__)));
	my $path = "$base/conf/$filename";
	return $path if -f $path;

	if ($ENV{PRODUCT_OPENER_DIR}) {
		my $env_path = "$ENV{PRODUCT_OPENER_DIR}/conf/$filename";
		return $env_path if -f $env_path;
	}

	my $docker_path = "/opt/product-opener/conf/$filename";
	return $docker_path if -f $docker_path;

	return undef;
}

=head2 init_allowlist( [ $file_path ] )

Loads allowed barcodes, patterns, and country-specific rules from allowlist file.

=cut

sub init_allowlist ($file_path = undef) {
	return if $initialized_allowlist && !defined $file_path;

	%allowed_barcodes = ();
	%allowlist_patterns = ();
	%country_rules = ();

	$file_path //= $ENV{PRODUCT_OPENER_FORBIDDEN_WORDS_ALLOWLIST};
	$file_path //= _find_conf_file("forbidden_words_allowlist.txt");
	$file_path //= _find_conf_file("forbidden_words_allowlist.sample.txt");

	if (defined $file_path && -e $file_path) {
		if (open(my $fh, "<:encoding(UTF-8)", $file_path)) {
			my $section = '';
			while (my $line = <$fh>) {
				chomp $line;
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				next if $line eq '' || $line =~ /^#/;

				if ($line =~ /^\[([a-z_]+)\]$/i) {
					$section = lc($1);
					next;
				}

				# Strip trailing inline comments
				$line =~ s/\s*#.*$//;
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				next if $line eq '';

				if ($section eq 'barcodes') {
					$allowed_barcodes{$line} = 1;
				}
				elsif ($section eq 'patterns') {
					my $clean = lc _unaccent($line);
					$clean =~ s/[\s\-_]+/ /g;
					$allowlist_patterns{$clean} = 1 if $clean ne '';
				}
				elsif ($section eq 'country_rules') {
					if ($line =~ /^([^:]+):\s*(.+)$/) {
						my ($word, $countries_str) = (lc _unaccent($1), lc $2);
						$word =~ s/^\s+//; $word =~ s/\s+$//;
						my @ctries = split(/\s*,\s*/, $countries_str);
						$country_rules{$word} = \@ctries;
					}
				}
			}
			close($fh);
		}
	}

	# Hardcoded default country rule: German turkey ("Pute")
	$country_rules{pute} //= [qw(de germany allemagne deutschland at austria ch switzerland)];

	$initialized_allowlist = 1;
	return;
}

=head2 is_barcode_allowed( $code )

Returns true if barcode is on the allowlist.

=cut

sub is_barcode_allowed ($code) {
	return 0 unless defined $code && $code ne '';
	init_allowlist() unless $initialized_allowlist;
	return $allowed_barcodes{$code} ? 1 : 0;
}

=head2 init_forbidden_words( [ $file_path ] )

Loads forbidden words from file or uses defaults.

=cut

sub init_forbidden_words ($file_path = undef) {
	return if $initialized_words && !defined $file_path;

	%forbidden_words_by_lang = ();
	%compiled_regexps = ();

	$file_path //= $ENV{PRODUCT_OPENER_FORBIDDEN_WORDS_FILE};
	$file_path //= _find_conf_file("forbidden_words.txt");

	if (defined $file_path && -e $file_path) {
		if (open(my $fh, "<:encoding(UTF-8)", $file_path)) {
			while (my $line = <$fh>) {
				chomp $line;
				$line =~ s/#.*$//;
				$line =~ s/^\s+//;
				$line =~ s/\s+$//;
				next unless $line;

				if ($line =~ /^([a-z]{2}):\s*(.+)$/i) {
					my ($lang, $word) = (lc $1, $2);
					$word =~ s/^\s+//;
					$word =~ s/\s+$//;
					my $clean = lc _unaccent($word);
					push @{$forbidden_words_by_lang{$lang}}, $clean if $clean ne '';
				}
			}
			close($fh);
		}
	}

	# Fall back to defaults if empty
	if (!%forbidden_words_by_lang) {
		foreach my $lang (keys %DEFAULT_FORBIDDEN_WORDS) {
			foreach my $w (@{$DEFAULT_FORBIDDEN_WORDS{$lang}}) {
				my $clean = lc _unaccent($w);
				push @{$forbidden_words_by_lang{$lang}}, $clean;
			}
		}
	}

	# Build universal edit rule regex string
	my %all_unique = ();
	foreach my $lang (keys %forbidden_words_by_lang) {
		foreach my $w (@{$forbidden_words_by_lang{$lang}}) {
			$all_unique{$w} = 1;
		}
	}
	my @all_sorted = sort { length($b) <=> length($a) } keys %all_unique;
	$ALL_FORBIDDEN_WORDS_REGEXP_STR = '\b(?:' . join('|', map { _word_to_accent_regex($_) } @all_sorted) . ')\b';

	$initialized_words = 1;
	return;
}

=head2 set_forbidden_words( \%words_by_lang )

Programmatically override forbidden words (primarily used by tests).

=cut

sub set_forbidden_words ($words_ref) {
	%forbidden_words_by_lang = ();
	%compiled_regexps = ();
	foreach my $lang (keys %$words_ref) {
		foreach my $w (@{$words_ref->{$lang}}) {
			my $clean = lc _unaccent($w);
			push @{$forbidden_words_by_lang{$lang}}, $clean if $clean ne '';
		}
	}
	$initialized_words = 1;
	return;
}

=head2 set_allowed_barcodes( \%barcodes )

Programmatically override allowed barcodes.

=cut

sub set_allowed_barcodes ($barcodes_ref) {
	%allowed_barcodes = %$barcodes_ref;
	$initialized_allowlist = 1;
	return;
}

=head2 set_allowlist_patterns( \@patterns )

Programmatically override allowlist patterns.

=cut

sub set_allowlist_patterns ($patterns_ref) {
	%allowlist_patterns = map { lc _unaccent($_) => 1 } @$patterns_ref;
	$initialized_allowlist = 1;
	return;
}

=head2 get_forbidden_words_list( $lc )

Returns arrayref of normalized forbidden words applicable for language C<$lc>.

=cut

sub get_forbidden_words_list ($lc = 'en') {
	init_forbidden_words() unless $initialized_words;

	$lc = lc($lc // 'en');
	my %seen = ();
	my @words = ();

	foreach my $category ('xx', 'en', $lc) {
		next unless defined $forbidden_words_by_lang{$category};
		foreach my $w (@{$forbidden_words_by_lang{$category}}) {
			push @words, $w unless $seen{$w}++;
		}
	}

	return \@words;
}

=head2 get_forbidden_words_regexp( $lc )

Returns compiled regular expression matching forbidden words for language C<$lc>.

=cut

sub get_forbidden_words_regexp ($lc = 'en') {
	init_forbidden_words() unless $initialized_words;

	$lc = lc($lc // 'en');
	return $compiled_regexps{$lc} if defined $compiled_regexps{$lc};

	my $list_ref = get_forbidden_words_list($lc);
	my @sorted = sort { length($b) <=> length($a) } @$list_ref;

	my $pattern = '\b(?:' . join('|', map { quotemeta($_) } @sorted) . ')\b';
	$pattern =~ s/\\ /\\s+/g;

	my $re = qr/$pattern/i;
	$compiled_regexps{$lc} = $re;
	return $re;
}

sub _is_match_allowlisted ($matched_word, $full_norm_text, $lc = 'en', $country_tags = '') {
	# Check country-specific rule (e.g. 'pute' in Germany)
	if (defined $country_rules{$matched_word}) {
		my $lc_lower = lc($lc // '');
		my $c_lower = lc($country_tags // '');
		foreach my $allowed_c (@{$country_rules{$matched_word}}) {
			if ($lc_lower eq $allowed_c || index($c_lower, $allowed_c) != -1) {
				return 1;
			}
		}
	}

	# French 'P'tit' / 'P'tits' (e.g. P'tit Déli)
	if ($matched_word =~ /^tits?$/) {
		if ($full_norm_text =~ /p['’\-\s]+$matched_word/i) {
			return 1;
		}
	}

	# English 'Ass.' or 'Ass'n' (abbreviation for Association)
	if ($matched_word eq 'ass') {
		if ($full_norm_text =~ /\bass(?:\.|'n|’n)\b/i) {
			return 1;
		}
	}

	my $clean_norm = $full_norm_text;
	$clean_norm =~ s/[^\w\s]/ /g;
	$clean_norm =~ s/\s+/ /g;

	# 'retard' in preservative or functional descriptions (e.g. "potassium sorbate to retard spoilage")
	if ($matched_word =~ /^retards?$/) {
		if ($clean_norm =~ /\b(?:to\s+retard|retards?\s+(?:spoilage|staling|oxidation|mold|mould|growth|decay|fermentation)|flame\s+retardant|fire\s+retardant)\b/i) {
			return 1;
		}
	}

	# 'rape' in culinary contexts (French râpé, Spanish monkfish, Italian beets, English rapeseed)
	if ($matched_word =~ /^rap(?:e|es|ee|ees)$/) {
		if ($text =~ /[âàèé]/i) {
			return 1;
		}
		my $lc_low = lc($lc // '');
		if ($lc_low =~ /^(?:fr|es|it)$/ || $country_tags =~ /(?:france|spain|espagne|italy|italie|italia)/i) {
			return 1;
		}
		if ($clean_norm =~ /\b(?:oil|fat|vegetable|hydrogenated|sunflower|palm|seed|margarine|colza|cabeza|caldo|pescado|monkfish)\b/i) {
			return 1;
		}
	}

	# Spanish/Italian preposition 'con' (with)
	if ($matched_word eq 'con') {
		my $lc_low = lc($lc // '');
		if ($lc_low =~ /^(?:es|it|pt|ca|gl)$/ || $clean_norm =~ /\b(?:carne|leche|tomate|queso|arroz|pollo|aceite|chispas|sabor|chilli)\b/i) {
			return 1;
		}
	}

	# 'cum' in ingredients (OCR of gum, cumin, Latin botanical names)
	if ($matched_word eq 'cum') {
		if ($clean_norm =~ /\b(?:guar|xanthan|bean|acacia|cellulose|arabic|locust|gellan|tara|chewing|bubble|thickener|spice|epice|coriander|paprika|cannelle|cardamome|carotte|chiche|cumin|basilicum|ceylanicum|capsicum|cuminum)\b/i) {
			return 1;
		}
	}

	# 'butt' in ingredients (OCR of butter, pork cuts, BBQ rubs)
	if ($matched_word eq 'butt') {
		if ($clean_norm =~ /\b(?:peanut|cocoa|almond|milk|apple|pork|shoulder|boston|unsalted|rub|dust|bad byron|corn syrup|syrup|solids|pancake|waffle|whey|peppers)\b/i) {
			return 1;
		}
	}

	# 'caca' in ingredients (OCR of cacao)
	if ($matched_word eq 'caca') {
		if ($clean_norm =~ /\b(?:beurre|pate|manteca|burro|maigre|poudre|chocolat|noir|solide|amargo|caramel|creme|vanille|coco|ingrediente|fondente|pasta|cioccolato|blanche|lait)\b/i) {
			return 1;
		}
	}

	# 'cock' in Thai Cock Brand or food contexts
	if ($matched_word eq 'cock') {
		if ($clean_norm =~ /\b(?:boisson|ananas|haricot|mungo|chantaboon|rice stick|tranche|grace|caribbean|soup|cola|sauce|chilli|seasoning)\b/i) {
			return 1;
		}
	}

	# 'poon' in OCR (spoon / boon tot kopje)
	if ($matched_word eq 'poon') {
		if ($clean_norm =~ /\b(?:spoon|kopje|boon|heaped|teaspoon|tablespoon|portion|porcion|pasta)\b/i) {
			return 1;
		}
	}

	# 'negre' in Catalan, Romanian, or food context (black pepper, black wine, black rice)
	if ($matched_word eq 'negre') {
		my $lc_low = lc($lc // '');
		if ($lc_low =~ /^(?:ca|ro)$/ || $clean_norm =~ /\b(?:vi|pebre|arros|coacaze|xocolata|te|fasole|paine|pomme|jus|lactics|oliva)\b/i) {
			return 1;
		}
	}

	# 'fag' in Romanian (lemn de fag = beech wood) or Italian (fag. = fagioli)
	if ($matched_word eq 'fag') {
		my $lc_low = lc($lc // '');
		if ($lc_low =~ /^(?:ro|it)$/ || $country_tags =~ /(?:romania|italy|italia)/i || $clean_norm =~ /\b(?:lemn|afumat|fum|bianchi|spagna|fagioli)\b/i) {
			return 1;
		}
	}

	# 'trique' in French (OCR of acide citrique)
	if ($matched_word eq 'trique') {
		if ($clean_norm =~ /\b(?:acide|acidifiant|correcteur|acidite|citrique|alginate)\b/i) {
			return 1;
		}
	}

	# 'cul' in Italian (OCR of 'di cui' in nutrition) or French (culture bactérienne, sel de cuisine)
	if ($matched_word eq 'cul') {
		if ($clean_norm =~ /\b(?:grassi|acidi|carboidrati|zuccheri|proteine|sale|culture|bacterienne|sel|cuisine)\b/i) {
			return 1;
		}
	}

	# 'suck' in ingredients (OCR of sucre / sugar)
	if ($matched_word eq 'suck') {
		if ($clean_norm =~ /\b(?:farine|ble|sauce|sugar|wheat|coffee|sel|salt|teriyaki|huile|vegetale|sirop|puree|chocolat)\b/i) {
			return 1;
		}
	}

	# 'dick' in German (dick = thick) or brand
	if ($matched_word eq 'dick') {
		my $lc_low = lc($lc // '');
		if ($lc_low eq 'de' || $country_tags =~ /germany/i || $clean_norm =~ /\b(?:extra|cremig|saft|scheiben|burger|agaven|schmelzkase|puree|pomme|carotte|potiron|jane)\b/i) {
			return 1;
		}
	}

	# 'conne' in ingredients (OCR of 'sucre de canne')
	if ($matched_word eq 'conne') {
		if ($clean_norm =~ /\b(?:sucre|sirop|canne|manioc|riz|glucose|chocolat|confiture|entier|fleur)\b/i) {
			return 1;
		}
	}

	# 'bite' in English (bite size, raw bite, sweet bite) or French OCR (farine de blé)
	if ($matched_word eq 'bite') {
		if ($clean_norm =~ /\b(?:size|two|raw|natural|fruit|nut|snack|energy|protein|organic|farine|complete|ble|sweet|big|pro|poivrons|peppers|chilli|bar)\b/i) {
			return 1;
		}
	}

	# 'spic' in ingredients (truncated OCR of spices)
	if ($matched_word eq 'spic') {
		if ($clean_norm =~ /\b(?:salt|garlic|onion|pepper|sauce|powder|glutamate|chloride|flavor|flavour|antioxidant|citric|acid|gum|xanthan|sorbate|sugar|vinegar|oil)\b/i) {
			return 1;
		}
	}

	# 'anal' in ingredients (OCR of analyse nutritionnelle)
	if ($matched_word eq 'anal') {
		if ($clean_norm =~ /\b(?:se|use|isis|nutrition|moyenne|100g|valeur|worm)\b/i) {
			return 1;
		}
	}

	# 'tit' in ingredients (titanium dioxide) or French
	if ($matched_word eq 'tit') {
		if ($clean_norm =~ /\b(?:color|colors|pigment|red|blue|yellow|dioxide|dioxyde|gelatin|bulles|ricotta|gerble)\b/i) {
			return 1;
		}
	}

	# Check allowlist patterns with word boundaries
	my $clean_padded = " $clean_norm ";
	foreach my $pat (keys %allowlist_patterns) {
		if (index($clean_padded, " $pat ") != -1) {
			return 1;
		}
	}

	return 0;
}

=head2 contains_forbidden_words( $text, [ $lc, $country_tags, $code ] )

Returns true if C<$text> contains any forbidden words, taking into account allowlists.

=cut

sub contains_forbidden_words ($text, $lc = 'en', $country_tags = '', $code = undef) {
	return 0 unless defined $text && $text ne '';

	# Barcode bypass
	if (defined $code && is_barcode_allowed($code)) {
		return 0;
	}

	init_forbidden_words() unless $initialized_words;
	init_allowlist() unless $initialized_allowlist;

	my $norm = lc _unaccent($text);
	my $re = get_forbidden_words_regexp($lc);

	while ($norm =~ /$re/g) {
		my $matched = lc _unaccent($&);
		$matched =~ s/[\s\-_]+/ /g;
		$matched =~ s/^\s+//; $matched =~ s/\s+$//;

		# Check if this match is covered by an allowlist pattern or country rule
		if (!_is_match_allowlisted($matched, $norm, $lc, $country_tags)) {
			return 1;
		}
	}

	return 0;
}

=head2 check_forbidden_words( $product_ref )

Inspects product name, ingredients, and brand fields of C<$product_ref>,
and populates C<data_quality_warnings_tags> if any forbidden words are detected.

=cut

sub check_forbidden_words ($product_ref) {
	return unless defined $product_ref && ref($product_ref) eq 'HASH';

	# If product barcode is in the allowlist, skip entirely
	my $code = $product_ref->{code};
	if (defined $code && is_barcode_allowed($code)) {
		return;
	}

	my $main_lc = $product_ref->{lang} // $product_ref->{lc} // 'en';
	my $countries = ref($product_ref->{countries_tags}) eq 'ARRAY'
		? join(',', @{$product_ref->{countries_tags}})
		: ($product_ref->{countries_tags} // $product_ref->{countries} // '');

	my $has_forbidden_name = 0;
	my $has_forbidden_ingredients = 0;
	my $has_forbidden_brands = 0;

	# Check product names (generic_name and product_name)
	my @name_fields = ("product_name", "generic_name");
	foreach my $k (keys %$product_ref) {
		if ($k =~ /^(?:product_name|generic_name)_([a-z]{2,3})$/) {
			push @name_fields, $k;
		}
	}
	my %seen_name_texts = ();
	foreach my $field (@name_fields) {
		my $val = $product_ref->{$field};
		next unless defined $val && $val ne '';
		my $field_lc = ($field =~ /_([a-z]{2,3})$/) ? $1 : $main_lc;
		next if $seen_name_texts{"$field_lc:$val"}++;
		if (contains_forbidden_words($val, $field_lc, $countries, $code)) {
			$has_forbidden_name = 1;
			last;
		}
	}

	# Check ingredients text (skip if 100% of ingredients are recognized and no other languages)
	my $unknown_n = $product_ref->{unknown_ingredients_n};
	my $known_n = $product_ref->{known_ingredients_n};
	my $ing_n = $product_ref->{ingredients_n};
	my $all_ing_rec = (defined $unknown_n && $unknown_n == 0 && (($known_n // 0) > 0 || ($ing_n // 0) > 0));

	my @ing_fields = ();
	my %other_ing_langs = ();
	foreach my $k (keys %$product_ref) {
		if ($k =~ /^ingredients_text_([a-z]{2,3})$/) {
			my $l = $1;
			push @ing_fields, $k;
			$other_ing_langs{$l} = 1 unless $l eq $main_lc;
		}
	}
	push @ing_fields, "ingredients_text" if exists $product_ref->{ingredients_text};

	# If all ingredients recognized and no other languages in ingredients, skip checking ingredients
	if ($all_ing_rec && !%other_ing_langs) {
		@ing_fields = ();
	}

	my %seen_ing_texts = ();
	foreach my $field (@ing_fields) {
		my $val = $product_ref->{$field};
		next unless defined $val && $val ne '';
		my $field_lc = ($field =~ /_([a-z]{2,3})$/) ? $1 : $main_lc;
		next if $all_ing_rec && $field_lc eq $main_lc;
		next if $seen_ing_texts{"$field_lc:$val"}++;
		if (contains_forbidden_words($val, $field_lc, $countries, $code)) {
			$has_forbidden_ingredients = 1;
			last;
		}
	}

	# Check brands
	my @brand_fields = ("brands");
	foreach my $k (keys %$product_ref) {
		if ($k =~ /^brands_([a-z]{2,3})$/) {
			push @brand_fields, $k;
		}
	}
	my %seen_brand_texts = ();
	foreach my $field (@brand_fields) {
		my $val = $product_ref->{$field};
		next unless defined $val && $val ne '';
		my $field_lc = ($field =~ /_([a-z]{2,3})$/) ? $1 : $main_lc;
		next if $seen_brand_texts{"$field_lc:$val"}++;
		if (contains_forbidden_words($val, $field_lc, $countries, $code)) {
			$has_forbidden_brands = 1;
			last;
		}
	}
		my $val = $product_ref->{$field};
		next unless defined $val && $val ne '';
		my $field_lc = ($field =~ /_([a-z]{2,3})$/) ? $1 : $main_lc;
		if (contains_forbidden_words($val, $field_lc, $countries, $code)) {
			$has_forbidden_brands = 1;
			last;
		}
	}

	# Add tags to data_quality_warnings_tags
	$product_ref->{data_quality_warnings_tags} //= [];

	if ($has_forbidden_name) {
		push @{$product_ref->{data_quality_warnings_tags}}, 'en:product-name-contains-forbidden-words';
	}
	if ($has_forbidden_ingredients) {
		push @{$product_ref->{data_quality_warnings_tags}}, 'en:ingredients-contain-forbidden-words';
	}
	if ($has_forbidden_brands) {
		push @{$product_ref->{data_quality_warnings_tags}}, 'en:brands-contain-forbidden-words';
	}
	if ($has_forbidden_name || $has_forbidden_ingredients || $has_forbidden_brands) {
		push @{$product_ref->{data_quality_warnings_tags}}, 'en:forbidden-words-warnings';
	}

	return;
}

# Auto-initialize
init_forbidden_words();
init_allowlist();

1;
