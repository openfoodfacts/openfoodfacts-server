package Blogs::Ingredients;

######################################################################
#
#	Package	Ingredients
#
#	Author:	Stephane Gigandet
#	Date:	22/12/11
#
######################################################################

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_Images);
	require Exporter;
	@ISA = qw(Exporter);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
					&extract_ingredients_from_image
					&extract_ingredients_from_text
					
					&extract_ingredients_classes_from_text
					

	
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;
use strict;
use utf8;

use Blogs::Store qw/:all/;
use Blogs::Config qw/:all/;
use Blogs::Users qw/:all/;
use Blogs::Products qw/:all/;
use Blogs::TagsEntries qw/:all/;
use Blogs::Tags qw/:all/;

use Image::OCR::Tesseract 'get_ocr';
use Encode;


# load ingredients classes

opendir(DH, "$data_root/ingredients") or print STDERR "cannot open directory $data_root/ingredients: $!\n";

foreach my $f (readdir(DH)) {
	next if $f eq '.';
	next if $f eq '..';
	next if ($f !~ /\.txt$/);
	
	my $class = $f;
	$class =~ s/\.txt$//;
	
	$ingredients_classes{$class} = {};
	
	open(IN, "<:encoding(UTF-8)", "$data_root/ingredients/$f");
	while (<IN>) {
		chomp;
		next if /^\#/;
		my ($canon_name, $other_names, $misc, $desc, $level, $warning) = split("\t");
		my $id = get_fileid($canon_name);
		next if (not defined $id) or ($id eq '');
		(not defined $level) and $level = 0;
		
		# additives: always set level to 0 right now, until we have a better list
		$level = 0;
		
		if (not defined $ingredients_classes{$class}{$id}) {
			# E322 before E322(i) : E322 should be associated with "lecithine"
			$ingredients_classes{$class}{$id} = {name=>$canon_name, id=>$id, other_names=>$other_names, level=>$level, description=>$desc, warning=>$warning};
		}
		#print STDERR "name: $canon_name\nother_names: $other_names\n";
		foreach my $other_name (split(/,/, $other_names)) {
			$other_name =~ s/^\s+//;
			$other_name =~ s/\s+$//;
			my $other_id = get_fileid($other_name);
			next if $other_id eq '';
			next if $other_name eq '';
			if (not defined $ingredients_classes{$class}{$other_id}) { # Take the first one
				$ingredients_classes{$class}{$other_id} = {name=>$other_name, id=>$id};
				#print STDERR "$id\t$other_id\n";
			}
		}
	}
	close IN;
	
	$ingredients_classes_sorted{$class} = [sort keys %{$ingredients_classes{$class}}];
}
closedir(DH);



sub extract_ingredients_from_image($) {

	my $product_ref = shift;
	my $path = product_path($product_ref->{code});
	my $status = 0;
	
	my $filename = '';
	
	my $id = 'ingredients';
	my $size = 'full';
	if ((defined $product_ref->{images}) and (defined $product_ref->{images}{$id})
		and (defined $product_ref->{images}{$id}{sizes}) and (defined $product_ref->{images}{$id}{sizes}{$size})) {
		$filename = $id . '.' . $product_ref->{images}{$id}{rev} ;
	}
	
	my $image = "$www_root/images/products/$path/$filename.full.jpg";
	my $text;
	
	print STDERR "extract_ingredients_from_image - image: $image\n";
	
	$text =  decode utf8=>get_ocr($image,undef,'fra');
	
	if ((defined $text) and ($text ne '')) {
		$product_ref->{ingredients_text_from_image} = $text;
	}
	else {
		$status = 1;
	}
	
	return $status;

}


sub extract_ingredients_from_text($) {

	my $product_ref = shift;
	my $path = product_path($product_ref->{code});
	my $text = $product_ref->{ingredients_text};
	
	print STDERR "extract_ingredients_from_text - text: $text \n";
	
	# $product_ref->{ingredients_tags} = ["first-ingredient", "second-ingredient"...]
	# $product_ref->{ingredients}= [{id =>, text =>, percent => etc. }, ] # bio / équitable ? 
	
	$product_ref->{'ingredients_tags'} = [];

	# farine (12%), chocolat (beurre de cacao (15%), sucre [10%], protéines de lait, oeuf 1%) - émulsifiants : E463, E432 et E472 - correcteurs d'acidité : E322/E333 E474-E475, acidifiant (acide citrique, acide phosphorique) - sel : 1% ...
	
	my @ranked_ingredients = ();
	my @unranked_ingredients = ();
	my $level = 0;
	
	# transform 0,2% into 0.2%
	$text =~ s/(\d),(\d+)( )?\%/$1.$2\%/g;
	$text =~ s/—/-/g;
	
	sub analyze_ingredients($$$$) {
		my $ranked_ingredients_ref = shift;
		my $unranked_ingredients_ref = shift;
		my $level = shift;
		my $s = shift;
		
		print STDERR "analyze_ingredients level $level: $s\n";
		
		my $last_separator =  undef; # default separator to find the end of "acidifiants : E330 - E472"
		
		my $after = '';
		my $before = '';
		my $between = '';
		my $between_level = $level;
		my $percent = undef;
		
		# find the first separator or ( or [ or : 
		if ($s =~ /(,|;|:|\[|\(|( - ))/i) {
		
			$before = $`;
			my $sep = $1;
			$after = $';
			
			print STDERR "separator: $sep\tbefore: $before\tafter: $after\n";
			
			if ($sep =~ /(:|\[|\()/i) {
			
				my $ending = $last_separator;
				if (not defined $ending) {
					$ending = ",|-";
				}
				if ($sep eq '(') {
					$ending = '\)';
				}
				elsif ($sep eq '[') {
					$ending = '\]';
				}
				$ending .= '|$';
				$ending = '(' . $ending . ')';
				
				print STDERR "special separator: $sep - ending: $ending - after: $after\n";
				
				# another separator before the ending separator ? we probably have several sub-ingredients
				if ($after =~ /^(.*?)$ending/i) {
					$between = $1;
					$after = $';
					
					print STDERR "sub-ingredients - between: $between - after: $after\n";
					
					if ($between =~ /(,|;|:|\[|\(|( - ))/i) {
						$between_level = $level + 1;
					}
					else {
						# no separator found : 34% ? or single ingredient
						if ($between =~ /^\s*(\d+(\.\d+)?)\s*\%\s*$/) {
							print STDERR "percent found:  $1\%\n";
							$percent = $1;
							$between = '';
						}
						else {
							# single ingredient, stay at same level
							print STDERR "single ingredient, stay at same level\n";
						}
					}
				}
				else {
					print STDERR "could not find ending separator: $ending - after: $after\n"
					# ! could not find the ending separator
				}
			
			}
			else {
				# simple separator
				$last_separator = $sep;
			}
			
			if ($after =~ /^\s*(\d+(\.\d+)?)\s*\%\s*(,|;|:|\[|\(|( - )|$)/) {
				print STDERR "percent found: $after = $1 + $'\%\n";
				$percent = $1;
				$after = $';
			}		
		}
		else {
			# no separator found: only one ingredient
			print STDERR "no separator found: $s\n";
			$before = $s;
		}
		
		# Strawberry 10.3%
		if ($before =~ /\s*(\d+(\.\d+)?)\s*\%\s*$/) {
			print STDERR "percent found: $before = $` + $1\%\n";
			$percent = $1;
			$before = $`;
		}		
		
		# 90% boeuf, 100% pur jus de fruit, 45% de matière grasses
		if ($before =~ /^\s*(\d+(\.\d+)?)\s*\%\s*(pur|de|d')?\s*/i) {
			print STDERR "'x% something' : percent found: $before = $' + $1\%\n";
			$percent = $1;
			$before = $';
		}		
		
		
		
		my $ingredient = $before;
		chomp($ingredient);
		$ingredient =~ s/\s+$//;
		$ingredient =~ s/^\s+//;
		my %ingredient = (
			id => get_fileid($ingredient),
			text => $ingredient
		);
		if (defined $percent) {
			$ingredient{percent} = $percent;
		}
		
		if ($ingredient ne '') {
			if ($level == 0) {
				push @$ranked_ingredients_ref, \%ingredient;
			}
			else {
				push @$unranked_ingredients_ref, \%ingredient;
			}
		}
		
		if ($between ne '') {
			analyze_ingredients($ranked_ingredients_ref, $unranked_ingredients_ref , $between_level, $between);
		}
		
		if ($after ne '') {
			analyze_ingredients($ranked_ingredients_ref, $unranked_ingredients_ref , $level, $after);
		}		
		
	}
	
	analyze_ingredients(\@ranked_ingredients, \@unranked_ingredients , 0, $text);
	
	for (my $i = 0; $i <= $#ranked_ingredients; $i++) {
		$ranked_ingredients[$i]{rank} = $i + 1;
	}
	
	foreach my $ingredient (@ranked_ingredients, @unranked_ingredients) {
		push @{$product_ref->{ingredients}}, $ingredient;
		push @{$product_ref->{ingredients_tags}}, $ingredient->{id};
	}
}


sub extract_ingredients_classes_from_text($) {

	my $product_ref = shift;
	my $path = product_path($product_ref->{code});
	my $text = $product_ref->{ingredients_text};
	
	# E 240, E.240, E-240..
	# E250-E251-E260
	#$text =~ s/(\b|-)e( |-|\.)?(\d+)( )?([a-z])??(i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xii|xiv|xv)?(\b|-)/$1 - e$3$5 - $7/ig;
	# add separations between all E340... "colorants naturels : rose E120, verte E161b, blanche : sans colorant"
	#$text =~ s/(\b|-)e( |-|\.)?(\d+)( )?([a-z])??(i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xii|xiv|xv)?(\b|-)/$1 - e$3$5 - $7/ig;
	$text =~ s/(\b|-)e( |-|\.)?(\d+)( )?([a-z])?(i|ii|iii|iv|v|vi|vii|viii|ix|x|xi|xii|xii|xiv|xv)?(\b|-)/$1 - e$3$5 - $7/ig;
	# ! caramel E150d -> caramel - E150d -> e150a - e150d ...
	$text =~ s/(caramel|caramels)(\W*)e150/e150/ig;
	# e432 et lécithines -> e432 - et lécithines
	$text =~ s/ - et / - /ig;
	
	# stabilisant e420 (sans : )
	$text =~ s/(conservateur|acidifiant|stabilisant|colorant|antioxydant|antioxygène|antioxygene|edulcorant|édulcorant|d'acidité|d'acidite|de goût|de gout|émulsifiant|emulsifiant|gélifiant|gelifiant|epaississant|épaississant|à lever|a lever|de texture|propulseur|emballage|affermissant|antiagglomérant|antiagglomerant|antimoussant|de charges|de fonte|d'enrobage|humectant|sequestrant|séquestrant|de traitement)(s)?(\s)?(:)?/ : /ig;
	
	# mono-glycéride -> monoglycérides
	$text =~ s/(mono|di)-([a-z])/$1$2/ig;
	$text =~ s/\bmono /mono- /ig;
	# acide gras -> acides gras
	$text =~ s/acide gras/acides gras/ig;
	$text =~ s/glycéride /glycérides /ig;
	
	# !! mono et diglycérides ne doit pas donner mono + diglycérides : keep the whole version too.
	# $text =~ s/(,|;|:|\)|\(|( - ))(.+?)( et )(.+?)(,|;|:|\)|\(|( - ))/$1$3_et_$5$6 , $1$3 et $5$6/ig;
	
	# print STDERR "additives: $text\n\n";

		
	my @ingredients = split(/,|;|:|\)|\(|( - )/i,$text);
	
	# huiles de palme et de
	
	
	foreach my $ingredient (@ingredients) {
		if ($ingredient =~ / et (de )?/i) {
			push @ingredients, $`;
			push @ingredients, $';
		}
	}
	
	my @ingredients_ids = ();
	foreach my $ingredient (@ingredients) {
			
		my $ingredientid = get_fileid($ingredient);
		if ((defined $ingredientid) and ($ingredientid ne '')) {
			push @ingredients_ids, $ingredientid;
		}
	}
	
	my $with_sweeteners;
	
	my %all_seen = (); # used to not tag "huile végétale" if we have seen "huile de palme" already
	
	
	# Additives using new global taxonomy
	
	$product_ref->{new_additives_debug} = "lc: " . $product_ref->{lc} . " - ";
	
	foreach my $tagtype ('additives') {
		
		$product_ref->{'new_' . $tagtype . '_tags'} = [];		
		my $class = $tagtype;		
		
			my %seen = ();

			foreach my $ingredient_id (@ingredients_ids) {
			
				my $canon_ingredient = canonicalize_taxonomy_tag($product_ref->{lc}, $tagtype, $ingredient_id);
				
				$product_ref->{new_additives_debug} .= " [ $ingredient_id -> $canon_ingredient ";
				
				if ((not defined $seen{$canon_ingredient}) and (exists_taxonomy_tag($tagtype, $canon_ingredient))) {
					push @{$product_ref->{"new_" . $tagtype . '_tags'}}, $canon_ingredient;
					$seen{$canon_ingredient} = 1;
					$product_ref->{new_additives_debug} .= " -> exists ";
				}						
				$product_ref->{new_additives_debug} .= " ] ";
			}
		
		
		# No ingredients?
		if ($product_ref->{ingredients_text} eq '') {
			delete $product_ref->{"new_" .$class . '_n'};
		}
		else {
			if (defined $product_ref->{'new_' . $tagtype . '_tags'}) {
				$product_ref->{"new_" .$class . '_n'} = scalar @{$product_ref->{'new_' . $tagtype . '_tags'}};
			}
			else {
				delete $product_ref->{"new_" .$class . '_n'};
			}
		}	
	}
	
	
	
	
	foreach my $class (sort keys %ingredients_classes) {
		
		$product_ref->{$class . '_tags'} = [];		
				
		# skip palm oil classes if there is a palm oil free label
		if (($class =~ /palm/) and (get_fileid($product_ref->{labels}) =~ /sans-huile-de-palme/)) {
			
		}
		else {
		
			my %seen = ();

			foreach my $ingredient_id (@ingredients_ids) {
			
			
				if ((defined $ingredients_classes{$class}{$ingredient_id}) and (not defined $seen{$ingredients_classes{$class}{$ingredient_id}{id}})) {
				
					next if (($ingredients_classes{$class}{$ingredient_id}{id} eq 'huile-vegetale') and (defined $all_seen{"huile-de-palme"}));
				
					push @{$product_ref->{$class . '_tags'}}, $ingredients_classes{$class}{$ingredient_id}{id};
					$seen{$ingredients_classes{$class}{$ingredient_id}{id}} = 1;
					$all_seen{$ingredients_classes{$class}{$ingredient_id}{id}} = 1;
					
					($product_ref->{code} eq '3245414658769') and print STDERR "extract_ingredient_classes 1 : ingredient_id: $ingredient_id - id/id: $ingredients_classes{$class}{$ingredient_id}{id}\n";
				}
				else {
					foreach my $id (@{$ingredients_classes_sorted{$class}}) {
						if (($ingredient_id =~ /^$id\b/) and (not defined $seen{$ingredients_classes{$class}{$id}{id}})) {
						
							next if (($ingredients_classes{$class}{$id}{id} eq 'huile-vegetale') and (defined $all_seen{"huile-de-palme"}));
						
							push @{$product_ref->{$class . '_tags'}}, $ingredients_classes{$class}{$id}{id};
							$seen{$ingredients_classes{$class}{$id}{id}} = 1;	
							$all_seen{$ingredients_classes{$class}{$id}{id}} = 1;				

							($product_ref->{code} eq '3245414658769') and print STDERR "extract_ingredient_classes 2 : id: $id - id/id: $ingredients_classes{$class}{$id}{id}\n";
							
						}
					}
				}						
			}
		}
				
		# No ingredients?
		if ($product_ref->{ingredients_text} eq '') {
			delete $product_ref->{$class . '_n'};
		}
		else {
			$product_ref->{$class . '_n'} = scalar @{$product_ref->{$class . '_tags'}};
		}	
	}
	
	for (my $i = 0; $i < (scalar @{$product_ref->{additives_tags}}); $i++) {
		$product_ref->{additives_tags}[$i] = 'en:' . $product_ref->{additives_tags}[$i];
	}
	
	$product_ref->{old_additives_tags} = $product_ref->{additives_tags};
	
	# keep the old additives for France until we can fix the new taxonomy matching to support all special cases
	# e.g. lecithine de soja
	if ($product_ref->{lc} ne 'fr') {
		$product_ref->{additives_tags} = $product_ref->{new_additives_tags};
		$product_ref->{additives_tags_n} = $product_ref->{new_additives_tags_n};
	}
	
	
	
	
	if ((defined $product_ref->{ingredients_that_may_be_from_palm_oil_n}) or (defined $product_ref->{ingredients_from_palm_oil_n})) {
		$product_ref->{ingredients_from_or_that_may_be_from_palm_oil_n} = $product_ref->{ingredients_that_may_be_from_palm_oil_n} + $product_ref->{ingredients_from_palm_oil_n};
	}
	
	
	delete $product_ref->{with_sweeteners};
	foreach my $additive (@{$product_ref->{'additives_tags'}}) {
		my $e = $additive;
		$e =~ s/\D//g;
		if (($e >= 950) and ($e <= 968)) {
			$product_ref->{with_sweeteners} = 1;
			last;
		}
	}
}

1;