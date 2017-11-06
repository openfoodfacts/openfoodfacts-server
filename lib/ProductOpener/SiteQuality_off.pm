package ProductOpener::SiteQuality;

######################################################################
#
#	Package	SiteQuality
#
#	Author:	Stephane Gigandet
#	Date:	23/01/2015
#
######################################################################

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();	# symbols to export by default
	@EXPORT_OK = qw(
	
			
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

sub check_ingredients($) {

	my $product_ref = shift;
	
	
	
	if (defined $product_ref->{ingredients_tags}) {	
		
		my $max_length = 0;
		
		foreach my $ingredient_tag (@{$product_ref->{ingredients_tags}}) {
			my $length = length($ingredient_tag);
			$length > $max_length and $max_length = $length;	
		}
	
		foreach my $max_length_threshold (50, 100, 200, 500, 1000) {
		
			if ($max_length > $max_length_threshold) {
			
				push $product_ref->{quality_tags}, "ingredients-ingredient-tag-length-greater-than-" . $max_length_threshold;
			
			}
		}
	}
	
	
	if (defined $product_ref->{languages_codes}) {
	
		foreach my $display_lc (keys %{$product_ref->{languages_codes}}) {
		
			my $ingredients_text_lc = "ingredients_text_" . ${display_lc};
			
			if (defined $product_ref->{$ingredients_text_lc}) {
			
				#print STDERR "quality:" .  $product_ref->{$ingredients_text_lc} . "\n";
			
				if ($product_ref->{$ingredients_text_lc} =~ /,(\s*)$/is) {
			
					push $product_ref->{quality_tags}, "ingredients-" . $display_lc . "-ending-comma";
				}
				
				if ($product_ref->{$ingredients_text_lc} =~ /[aeiouy]{5}/is) {
			
					push $product_ref->{quality_tags}, "ingredients-" . $display_lc . "-5-vowels";
				}
				
				if ($product_ref->{$ingredients_text_lc} =~ /[bcdfghjklmnpqrstvwxz]{4}/is) {
			
					push $product_ref->{quality_tags}, "ingredients-" . $display_lc . "-4-consonants";
				}				

				if ($product_ref->{$ingredients_text_lc} =~ /(.)\1{4,}/is) {
			
					push $product_ref->{quality_tags}, "ingredients-" . $display_lc . "-4-repeated-chars";
				}	

				if ($product_ref->{$ingredients_text_lc} =~ /[\$\€\£\¥\₩]/is) {
			
					push $product_ref->{quality_tags}, "ingredients-" . $display_lc . "-unexpected-chars-currencies";
				}		

				if ($product_ref->{$ingredients_text_lc} =~ /[\@]/is) {
			
					push $product_ref->{quality_tags}, "ingredients-" . $display_lc . "-unexpected-chars-arobase";
				}

				if ($product_ref->{$ingredients_text_lc} =~ /[\!]/is) {
			
					push $product_ref->{quality_tags}, "ingredients-" . $display_lc . "-unexpected-chars-exclamation-mark";
				}					
				
				if ($product_ref->{$ingredients_text_lc} =~ /[\?]/is) {
			
					push $product_ref->{quality_tags}, "ingredients-" . $display_lc . "-unexpected-chars-question-mark";
				}					
				
				
				# French specific
				#if ($display_lc eq 'fr') {
				
					if ($product_ref->{$ingredients_text_lc} =~ /kcal|glucides|(dont sucres)|(dont acides gras)|(valeurs nutri)/is) {
			
						push $product_ref->{quality_tags}, "ingredients-" . $display_lc . "-includes-fr-nutrition-facts";
					}			

					if ($product_ref->{$ingredients_text_lc} =~ /(à conserver)|(conditions de )|(à consommer )|(plus d'info)|consigne/is) {
			
						push $product_ref->{quality_tags}, "ingredients-" . $display_lc . "-includes-fr-instructions";
					}					
				#}
			}
		
		}
	
	}	

}



# Run site specific quality checks

sub check_quality($) {

	my $product_ref = shift;

	$product_ref->{quality_tags} = [];
	
	check_ingredients($product_ref);
}





1;
