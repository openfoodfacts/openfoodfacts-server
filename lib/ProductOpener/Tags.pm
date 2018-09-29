# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2018 Association Open Food Facts
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

package ProductOpener::Tags;

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(

					&canonicalize_tag2
					&canonicalize_tag_link
					
					&has_tag
					&add_tag
					&remove_tag
	
					%canon_tags
					%tags_images
					%tags_texts
					%tags_levels
					%levels
					%special_tags
					
					&get_taxonomyid
					&get_taxonomyurl
					
					&gen_tags_hierarchy
					&gen_tags_hierarchy_taxonomy
					&gen_ingredients_tags_hierarchy_taxonomy
					&display_tags_hierarchy_taxonomy
					&build_tags_taxonomy
					
					&canonicalize_taxonomy_tag
					&canonicalize_taxonomy_tag_link
					&canonicalize_taxonomy_2tag_link
					&exists_taxonomy_tag
					&display_taxonomy_tag
					&display_taxonomy_tag_link
					
					&spellcheck_taxonomy_tag
					
					&get_tag_css_class
					
					&display_tag_link
					&display_tags_list
					&display_tag_and_parents
					&display_parents_and_children
					&display_tags_hierarchy
					&export_tags_hierarchy
					
					&compute_field_tags

					&get_city_code
					%emb_codes_cities
					%emb_codes_geo
					%cities
					
					%tags_fields
					%hierarchy_fields
					%taxonomy_fields
					@drilldown_fields
					%language_fields
					
					%properties
					
					%language_codes
					%language_codes_reverse
					
					%country_names
					%country_codes
					%country_codes_reverse
					%country_languages
					
					%loaded_taxonomies
					
					%just_synonyms
					%translations_from
					%translations_to
					
					%Languages
					
					&init_select_country_options
					
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::TagsEntries qw/:all/;
use ProductOpener::Food qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Text qw/:all/;
use Clone qw(clone);

use URI::Escape::XS;
use Log::Any qw($log);

use GraphViz2;
use JSON::PP;




%tags_fields = (packaging => 1, brands => 1, categories => 1, labels => 1, origins => 1, manufacturing_places => 1, emb_codes => 1, allergens => 1, traces => 1, purchase_places => 1, stores => 1, countries => 1, states=>1, codes=>1, debug => 1);
%hierarchy_fields = ();

%taxonomy_fields = (); # populated by retrieve_tags_taxonomy



# Fields that can have different values by language
%language_fields = (
front_image => 1,
ingredients_image => 1,
nutrition_image => 1,
product_name => 1,
generic_name => 1,
ingredients_text => 1,
);


%canon_tags = ();

my %tags_level = ();
my %tags_direct_parents = ();
my %tags_direct_children = ();
my %tags_all_parents = ();

my %stopwords = ();
%just_synonyms = ();
my %just_tags = ();	# does not include synonyms that are only synonyms
my %synonyms = ();
my %synonyms_for = ();
my %synonyms_for_extended = ();
%translations_from = ();
%translations_to = ();
my %level = ();
my %direct_parents = ();
my %direct_children = ();
my %all_parents = ();


%properties = ();


%tags_images = ();
%tags_levels = ();
%tags_texts = ();

my $logo_height = 90;


sub has_tag($$$) {

	my $product_ref = shift;
	my $tagtype = shift;
	my $tagid = shift;
	
	my $return = 0;
	
	if (defined $product_ref->{$tagtype . "_tags"}) {
	
		foreach my $tag (@{$product_ref->{$tagtype . "_tags"}}) {
			if ($tag eq $tagid) {
				$return = 1;
				last;
			}
		}
	}
	return $return;
}


sub add_tag($$$) {

	my $product_ref = shift;
	my $tagtype = shift;
	my $tagid = shift;
	
	push @{$product_ref->{$tagtype . "_tags"}}, $tagid; 
}

sub remove_tag($$$) {

	my $product_ref = shift;
	my $tagtype = shift;
	my $tagid = shift;
	
	my $return = 0;
	
	if (defined $product_ref->{$tagtype . "_tags"}) {
	
		$product_ref->{$tagtype . "_tags_new"} = [];
		foreach my $tag (@{$product_ref->{$tagtype . "_tags"}}) {
			if ($tag ne $tagid) {
				push @{$product_ref->{$tagtype . "_tags_new"}}, $tag;
			}
		}
		$product_ref->{$tagtype . "_tags"} = $product_ref->{$tagtype . "_tags_new"};
		delete $product_ref->{$tagtype . "_tags_new"};
	}
	return $return;
}



sub load_tags_images($$) {
	my $lc = shift;
	my $tagtype = shift;
	
	defined $tags_images{$lc} or $tags_images{$lc} = {};
	defined $tags_images{$lc}{$tagtype} or $tags_images{$lc}{$tagtype} = {};	
	
	if (opendir (DH2, "$www_root/images/lang/$lc/$tagtype")) {
		foreach my $file (readdir(DH2)) {
			if ($file =~ /^((.*)\.\d+x${logo_height}.(png|svg))$/) {
				if ((not defined $tags_images{$lc}{$tagtype}{$2}) or ($3 eq 'svg')) {
					$tags_images{$lc}{$tagtype}{$2} = $1;
					# print STDERR "load_tags_images - tags_images - lc: $lc - tagtype: $tagtype - tag: $2 - img: $1 - ext: $3 \n";
					# print "load_tags_images - tags_images - loading lc: $lc - tagtype: $tagtype - tag: $2 - img: $1 - ext: $3 \n";
				}
			}
		}
		closedir DH2;
	}
}	
	

sub load_tags_hierarchy($$) {
	my $lc = shift;
	my $tagtype = shift;
	
	defined $canon_tags{$lc} or $canon_tags{$lc} = {};
	defined $canon_tags{$lc}{$tagtype} or $canon_tags{$lc}{$tagtype} = {};
	defined $tags_images{$lc} or $tags_images{$lc} = {};
	defined $tags_images{$lc}{$tagtype} or $tags_images{$lc}{$tagtype} = {};	
	defined $tags_level{$lc} or $tags_level{$lc} = {};
	defined $tags_level{$lc}{$tagtype} or $tags_level{$lc}{$tagtype} = {};
	defined $tags_direct_parents{$lc} or $tags_direct_parents{$lc} = {};
	defined $tags_direct_parents{$lc}{$tagtype} or $tags_direct_parents{$lc}{$tagtype} = {};
	defined $tags_direct_children{$lc} or $tags_direct_children{$lc} = {};
	defined $tags_direct_children{$lc}{$tagtype} or $tags_direct_children{$lc}{$tagtype} = {};
	defined $tags_all_parents{$lc} or $tags_all_parents{$lc} = {};
	defined $tags_all_parents{$lc}{$tagtype} or $tags_all_parents{$lc}{$tagtype} = {};
	defined $synonyms{$tagtype}{$lc} or $synonyms{$tagtype}{$lc} = {};
	defined $synonyms_for{$tagtype}{$lc} or $synonyms_for{$tagtype}{$lc} = {};

	
	if (open (my $IN, "<:encoding(UTF-8)", "$data_root/lang/$lc/tags/$tagtype.txt")) {
	
		my $current_tagid;
		my $current_tag;
		
		# print STDERR "Tags.pm - load_tags_hierarchy - lc: $lc - tagtype: $tagtype \n";
	

	
		while (<$IN>) {
		
			my $line = $_;
			chomp($line);
			$line =~ s/\s+$//;
			
			next if ($line =~ /^(\s*)$/);
			next if ($line =~ /^\#/);
			
# Nectars de fruits, nectar de fruits, nectars, nectar
# < Jus et nectars de fruits, jus et nectar de fruits
# > Nectars de goyave, nectar de goyave, nectar goyave
# > Nectars d'abricot, nectar d'abricot, nectars d'abricots, nectar 

			if ($line !~ /^(>|<)/) {
				my @tags = split(/,( )?/, $line);
				$current_tag = shift @tags;
				$current_tagid = get_fileid($current_tag);
				$canon_tags{$lc}{$tagtype}{$current_tagid} = $current_tag;
				foreach my $tag (@tags) {
					my $tagid = get_fileid($tag);
					next if $tagid eq '';
					$canon_tags{$lc}{$tagtype}{$tagid} = $current_tag;
					(defined $synonyms_for{$lc}{$current_tagid}) or $synonyms_for{$lc}{$current_tagid} = [];		
					push @{$synonyms_for{$lc}{$current_tagid}}, $tag;
					$synonyms{$lc}{$tagid} = $current_tagid;
				}				
			}
			elsif ($line =~ /^>( )?/) {
				$line = $';
				my @tags = split(/,( )?/, $line);
				my $child = shift(@tags);
				# print "line : $line\nchild: $child\n";
				my $childid = get_fileid($child);
				$canon_tags{$lc}{$tagtype}{$childid} = $child;
				defined $tags_direct_children{$lc}{$tagtype}{$current_tagid} or $tags_direct_children{$lc}{$tagtype}{$current_tagid} = {};
				$tags_direct_children{$lc}{$tagtype}{$current_tagid}{$childid} = 1;
				defined $tags_direct_parents{$lc}{$tagtype}{$childid} or $tags_direct_parents{$lc}{$tagtype}{$childid} = {};
				$tags_direct_parents{$lc}{$tagtype}{$childid}{$current_tagid} = 1;
				foreach my $tag (@tags) {
					my $tagid = get_fileid($tag);
					next if $tagid eq '';				
					$canon_tags{$lc}{$tagtype}{$tagid} = $child;
					(defined $synonyms_for{$lc}{$childid}) or $synonyms_for{$lc}{$childid} = [];		
					push @{$synonyms_for{$lc}{$childid}}, $tag;
					$synonyms{$lc}{$tagid} = $childid;
				}					
			}
			elsif ($line =~ /^<( )?/) {
				$line = $';
				my @tags = split(/,( )?/, $line);
				my $parent = shift(@tags);
				# print "line : $line\nparent: $parent\n";				
				my $parentid = get_fileid($parent);
				$canon_tags{$lc}{$tagtype}{$parentid} = $parent;
				defined $tags_direct_parents{$lc}{$tagtype}{$current_tagid} or $tags_direct_parents{$lc}{$tagtype}{$current_tagid} = {};
				$tags_direct_parents{$lc}{$tagtype}{$current_tagid}{$parentid} = 1;
				defined $tags_direct_children{$lc}{$tagtype}{$parentid} or $tags_direct_children{$lc}{$tagtype}{$parentid} = {};
				$tags_direct_children{$lc}{$tagtype}{$parentid}{$current_tagid} = 1;
				foreach my $tag (@tags) {
					my $tagid = get_fileid($tag);
					next if $tagid eq '';
					$canon_tags{$lc}{$tagtype}{$tagid} = $parent;
					(defined $synonyms_for{$lc}{$parentid}) or $synonyms_for{$lc}{$parentid} = [];		
					push @{$synonyms_for{$lc}{$parentid}}, $tag;
					$synonyms{$lc}{$tagid} = $parentid;					
				}					
			}				
		}
	
		close $IN;
		
		
		# Deal with simple singular and plurals, and other forms
		
		foreach my $tagid (keys %{$canon_tags{$lc}{$tagtype}}) {
	
			# Warning: it's possible that several forms (or multiple times the same form) exist in the @known_tags list
			# (e.g. tomates + tomate)
			# the first one should take precedence

			my @other_forms = ($tagid);
			
			if ($lc eq 'fr') {
				if ($tagid =~ /(s|x)(-(a-la|au|aux))-/) {
					push @other_forms, "$`$1-$'", "$`-$'", "$`$1-a-la-$'", "$`-a-la-$'", "$`$1-au-$'", "$`-au-$'", "$`$1-aux-$'", "$`-aux-$'";
				}			
			}
			
			my @all_other_forms = ();
			
			foreach my $other_form (@other_forms) {
				push @all_other_forms, $other_form;
				if ($other_form =~ /(s|x)$/) {
					push @all_other_forms, $`;
				}
				else {
					push @all_other_forms, $other_form . 's';
				}
			}
			
			foreach my $other_form (@all_other_forms) {
				if (not defined $canon_tags{$lc}{$tagtype}{$other_form}) {
					$canon_tags{$lc}{$tagtype}{$other_form} = $canon_tags{$lc}{$tagtype}{$tagid};
					#print STDERR "canon_tags: $tagid\t <-- $other_form\n";
				}
			}
			
		}
		
		
		# Compute all parents, breadth first
		
		# print STDERR "Tags.pm - load_tags_hierarchy - lc: $lc - tagtype: $tagtype - compute all parents breadth first\n";		
		
		my %longest_parent = ($lc => {});
		
		# foreach my $tagid (keys %{$tags_direct_parents{$lc}{$tagtype}}) {
		foreach my $tag (values %{$canon_tags{$lc}{$tagtype}}) {
		
			my $tagid = get_fileid($tag);
		
			print "Tags.pm - load_tags_hierarchy - lc: $lc - tagtype: $tagtype - compute all parents breadth first - tagid: $tagid\n";		
		
			$tags_all_parents{$lc}{$tagtype}{$tagid} = [];
			
			my @queue = (); 
			
			if (defined $tags_direct_parents{$lc}{$tagtype}{$tagid}) {
				@queue = keys %{$tags_direct_parents{$lc}{$tagtype}{$tagid}};
			}
			
			if (not defined $tags_level{$lc}{$tagtype}{$tagid}) {
				$tags_level{$lc}{$tagtype}{$tagid} = 1;
				if (defined $tags_direct_parents{$lc}{$tagtype}{$tagid}) {
					$longest_parent{$lc}{$tagid} = (keys %{$tags_direct_parents{$lc}{$tagtype}{$tagid}})[0];
				}
			}
			
			my %seen = ();
		
			while ($#queue > -1) {
				my $parentid = shift @queue;
				#print "- $parentid\n";
				if (not defined $seen{$parentid}) {
					push @{$tags_all_parents{$lc}{$tagtype}{$tagid}}, $parentid;
					$seen{$parentid} = 1;
				
					if (not defined $tags_level{$lc}{$tagtype}{$parentid})  {
						$tags_level{$lc}{$tagtype}{$parentid} = 2;
						$longest_parent{$lc}{$tagid} = $parentid;
					}				
					
					if (defined $tags_direct_parents{$lc}{$tagtype}{$parentid}) {
						foreach my $grandparentid (keys %{$tags_direct_parents{$lc}{$tagtype}{$parentid}}) {
							push @queue, $grandparentid;
							if ((not defined $tags_level{$lc}{$tagtype}{$grandparentid}) or ($tags_level{$lc}{$tagtype}{$grandparentid} <= $tags_level{$lc}{$tagtype}{$parentid})) {
								$tags_level{$lc}{$tagtype}{$grandparentid} = $tags_level{$lc}{$tagtype}{$parentid} + 1;
								$longest_parent{$lc}{$parentid} = $grandparentid;
							}
						}
					}
				}
			}
		}
		
		# Compute all children, breadth first
		
		open (my $OUT, ">:encoding(UTF-8)", "$data_root/taxonomies/$tagtype.$lc.txt");
		
		foreach my $tagid (
			sort { ($tags_level{$lc}{$tagtype}{$b} <=> $tags_level{$lc}{$tagtype}{$a})
				|| ($longest_parent{$lc}{$a} cmp $longest_parent{$lc}{$b})
				|| ($a cmp $b)
				}
				keys %{$tags_level{$lc}{$tagtype}} ) {
			
			#print $OUT "$tagid - $tags_level{$lc}{$tagtype}{$tagid} - $longest_parent{$lc}{$tagid} \n";
			if (defined $tags_direct_parents{$lc}{$tagtype}{$tagid}) {
				#print "direct_parents\n";
				foreach my $parentid (sort keys %{$tags_direct_parents{$lc}{$tagtype}{$tagid}}) {
					print $OUT "< $lc:" . $canon_tags{$lc}{$tagtype}{$parentid} . "\n";
				}
				
			}
			print $OUT "$lc: " . $canon_tags{$lc}{$tagtype}{$tagid};
			if (defined $synonyms_for{$lc}{$tagid}) {
				print $OUT ", " . join(", ", @{$synonyms_for{$lc}{$tagid}});
			}
			print $OUT "\n\n" ;
		
		}
		
		close $OUT;
		
		
	}
}



sub remove_stopwords($$$) {

	my $tagtype = shift;
	my $lc = shift;
	my $tagid = shift;
	
	if (defined $stopwords{$tagtype}{$lc}) { 
		foreach my $stopword (@{$stopwords{$tagtype}{$lc}}) {
			$tagid =~ s/-${stopword}-/-/g;
			
			# some stopwords should not be removed at the start or end
			# this can cause issues with spellchecking tags like ingredients
			# e.g. purée d'abricot -> puree d' -> urée
			# ingredients: stopwords:fr:aux,au,de,le,du,la,a,et,avec,base,ou,en,proportion,variable, contient

			$tagid =~ s/^${stopword}-//g;

			if (not 
				(($lc eq 'fr') and not ($stopword =~ /^(en|proportion|proportions|variable|variables)$/))	# don't remove French stopwords at the end
				) {
				$tagid =~ s/-${stopword}$//g;
			}
		}
	}
	return $tagid;

}


sub remove_plurals($$) {

	my $lc = shift;
	my $tagid = shift;
	
	if ($lc eq 'en') {
		$tagid =~ s/s$//;
		$tagid =~ s/(s)-/-/g;		
	}	
	if ($lc eq 'fr') {
		$tagid =~ s/(s|x)$//;
		$tagid =~ s/(s|x)-/-/g;
	}
	if ($lc eq 'es') {
		$tagid =~ s/s$//;
		$tagid =~ s/(s)-/-/g;		
	}
	
	return $tagid;

}






sub build_tags_taxonomy($$) {

	my $tagtype = shift;
	my $publish = shift;

	defined $tags_images{$lc} or $tags_images{$lc} = {};
	defined $tags_images{$lc}{$tagtype} or $tags_images{$lc}{$tagtype} = {};	
	
	
	

	# Need to be initialized as a taxonomy is probably already loaded by Tags.pm
	$stopwords{$tagtype} = {};
	$synonyms{$tagtype} = {};
	$synonyms_for{$tagtype} = {};
	$synonyms_for_extended{$tagtype} = {};
	$translations_from{$tagtype} = {};
	$translations_to{$tagtype} = {};
	$level{$tagtype} = {};
	$direct_parents{$tagtype} = {};
	$direct_children{$tagtype} = {};
	$all_parents{$tagtype} = {};	
	
	$just_tags{$tagtype} = {};
	$just_synonyms{$tagtype} = {};
	$properties{$tagtype} = {};
	
		
	if (open (my $IN, "<:encoding(UTF-8)", "$data_root/taxonomies/$tagtype.txt")) {
	
		my $current_tagid;
		my $current_tag;
		my $canon_tagid;
		
		# print STDERR "Tags.pm - load_tags_taxonomy - tagtype: $tagtype \n";
	

		# 1st phase: read translations and synonyms
		
		while (<$IN>) {
		
			my $line = $_;
			chomp($line);

			$line =~ s/’/'/g;
			
			# assume commas between numbers are part of the name
			# e.g. en:2-Bromo-2-Nitropropane-1,3-Diol, Bronopol
			# replace by a lower comma ‚

			$line =~ s/(\d),(\d)/$1‚$2/g;
			
			# replace escaped comma \, by a lower comma ‚
			$line =~ s/\\,/‚/g;
			
			# fr:E333(iii), Citrate tricalcique
			# -> E333iii
			
			$line =~ s/\(((i|v|x)+)\)/$1/i;
			
			# replace parenthesis (they break regular expressions)
			
			#$line =~ s/\(/\\\(/g;
			#$line =~ s/\)/\\\)/g;
			
			#$line =~ s/\)/）/g;
			#$line =~ s/\(/（/g;
			#$line =~ s/\\/⁄/g;
			
			
			# just remove everything between parenthesis
			#$line =~ s/\([^\)]*\)/ /g;
			#$line =~ s/\([^\)]*\)/ /g;
			#$line =~ s/\([^\)]*\)/ /g;
			# 3 times for embedded parenthesis
			#$line =~ s/\(|\)/-/g;			
			
			$line =~ s/\s+$//;			
			
			if ($line =~ /^(\s*)$/) {
				$canon_tagid = undef;
				next;
			}
			
			next if ($line =~ /^\#/);
			
			#print "new_line: $line\n";
		
			if ($line =~ /^</) {
				# Parent
				# Ignore in first pass as it may be a synonym, or a translation, for the canonical parent
			}
			elsif ($line =~ /^stopwords:(\w\w):(\s*)/) {
				my $lc = $1;
				$stopwords{$tagtype}{$lc . ".orig"} .= "stopwords:$lc:$'\n";
				$line = $';
				$line =~ s/^\s+//;
				print "taxonomy - stopwords - tagtype: $tagtype - lc: $lc - $lc.orig: " . $stopwords{$tagtype}{$lc . ".orig"} . "\n";
				my @tags = split(/( )?,( )?/, $line);
				foreach my $tag (@tags) {
					my $tagid = get_fileid($tag);
					next if $tagid eq '';
					defined $stopwords{$tagtype}{$lc} or $stopwords{$tagtype}{$lc} = [];
					push @{$stopwords{$tagtype}{$lc}}, $tagid;
					print "taxonomy - stopwords - tagtype: $tagtype - lc: $lc - tagid: $tagid\n";
				}
			}
			elsif ($line =~ /^(synonyms:)?(\w\w):/) {
				my $synonyms = $1;
				my $lc = $2;
				$line = $';
				$line =~ s/^\s+//;
				my @tags = split(/( )?,( )?/, $line);
				
				$current_tag = $tags[0];
				$current_tag = ucfirst($current_tag);
				$current_tagid = get_fileid($current_tag);
				
				# check if we already have an entry listed for one of the synonyms
				# this is useful for taxonomies that need to be merged, and that are concatenated
				
				# should only be applied to ingredients (and not to additives)
				
				if ($tagtype eq 'ingredients') {
				
					foreach my $tag2 (@tags) {

						my $tag = $tag2;
					
						$tag =~ s/^\s+//;
						$tag = normalize_percentages($tag, $lc);
						my $tagid = get_fileid($tag);
						my $possible_canon_tagid = $synonyms{$tagtype}{$lc}{$tagid};
						if (not defined $possible_canon_tagid) {
							my $stopped_tagid = $tagid;
							$stopped_tagid = remove_stopwords($tagtype,$lc,$tagid);
							$stopped_tagid = remove_plurals($lc,$stopped_tagid);
							$possible_canon_tagid = $synonyms{$tagtype}{$lc}{$stopped_tagid};
						}
						if ((not defined $canon_tagid) and (defined $possible_canon_tagid)) {
							$canon_tagid = "$lc:" . $possible_canon_tagid;
							$current_tagid = $possible_canon_tagid;
							print "taxonomy - we already have a canon_tagid $canon_tagid for the tag $tag\n";
							last;
						}
					}
									
				
					# do we already have a translation from a previous definition?
					if (defined $translations_to{$tagtype}{$canon_tagid}{$lc}) {
						$current_tag = $translations_to{$tagtype}{$canon_tagid}{$lc};
						$current_tagid = get_fileid($current_tag);
					}
				
				}
				
				
				if (not defined $canon_tagid) {
					$canon_tagid = "$lc:$current_tagid";
					print STDERR "new canon_tagid: $canon_tagid\n";
					if ($synonyms eq 'synonyms:') {
						$just_synonyms{$tagtype}{$canon_tagid} = 1;
					}
				}

				if (not defined $translations_from{$tagtype}{"$lc:$current_tagid"}) {
					$translations_from{$tagtype}{"$lc:$current_tagid"} = $canon_tagid;
					print "taxonomy - translation_from{$tagtype}{$lc:$current_tagid} = $canon_tagid \n";
				}
				
				defined $translations_to{$tagtype}{$canon_tagid} or $translations_to{$tagtype}{$canon_tagid} = {};
				
				if (not defined $translations_to{$tagtype}{$canon_tagid}{$lc}) {
					$translations_to{$tagtype}{$canon_tagid}{$lc} = $current_tag;
					print "taxonomy - translations_to{$tagtype}{$canon_tagid}{$lc} = $current_tag \n";
				}
								
				
				# Include the main tag as a synonym of itself, useful later to compute other synonyms
				
				(defined $synonyms_for{$tagtype}{$lc}) or $synonyms_for{$tagtype}{$lc} = {};
				defined $synonyms_for{$tagtype}{$lc}{$current_tagid} or $synonyms_for{$tagtype}{$lc}{$current_tagid} = [];
				
				foreach my $tag (@tags) {
					my $tagid = get_fileid($tag);
					next if $tagid eq '';		
							
					if (defined $synonyms{$tagtype}{$lc}{$tagid}) {
						($synonyms{$tagtype}{$lc}{$tagid} eq $current_tagid) and next;
						# for additives, E101 contains synonyms that corresponds to E101(i) etc.   Make E101(i) override E101.
						if (not ($tagtype =~ /^additives/)) {
						($synonyms{$tagtype}{$lc}{$tagid} ne $current_tagid) and print "$tagid already is a synonym of $synonyms{$tagtype}{$lc}{$tagid} - cannot add $current_tagid\n";
						next;
						}
					}
							
					push @{$synonyms_for{$tagtype}{$lc}{$current_tagid}}, $tag;
					$synonyms{$tagtype}{$lc}{$tagid} = $current_tagid;
					print "taxonomy - synonyms - synonyms{$tagtype}{$lc}{$tagid} = $current_tagid \n";
				}					
				
			}
			else {
				$log->info("unrecognized line in taxonomy", { tagtype => $tagtype, line => $line }) if $log->is_info();
			}
		
		}
		
		close ($IN);
		
		# 2nd phase: compute synonyms
		# e.g.
		# en:yogurts, yoghurts
		# ..
		# en:banana yogurts
		#
		# --> also compute banana yoghurts
		
		#print "synonyms: initializing synonyms_for_extended - tagtype: $tagtype - lc keys: " . scalar(keys %{$synonyms_for{$tagtype}{$lc}}) . "\n";
		
		my %synonym_contains_synonyms = {};
		
		foreach my $lc (sort keys %{$synonyms_for{$tagtype}}) {
			$synonym_contains_synonyms{$lc} = {};
			foreach my $current_tagid (sort keys %{$synonyms_for{$tagtype}{$lc}}) {
				print "synonyms_for{$tagtype}{$lc} - $current_tagid - " . scalar(@{$synonyms_for{$tagtype}{$lc}{$current_tagid}}) . "\n";
				
				(defined $synonyms_for_extended{$tagtype}{$lc}) or $synonyms_for_extended{$tagtype}{$lc} = {};
				
				foreach my $tag (@{$synonyms_for{$tagtype}{$lc}{$current_tagid}}) {
					my $tagid = get_fileid($tag);
					(defined $synonyms_for_extended{$tagtype}{$lc}{$current_tagid}) or $synonyms_for_extended{$tagtype}{$lc}{$current_tagid} = {};
					$synonyms_for_extended{$tagtype}{$lc}{$current_tagid}{$tagid} = 1;
					print "synonyms_for_extended{$tagtype}{$lc}{$current_tagid}{$tagid} = 1 \n";
				}
			}
		}
		
		my $max_pass = 3;
		if ($tagtype =~ /^additives/) {
			$max_pass = 1;
		}
		
		for (my $pass = 1; $pass <= $max_pass; $pass++) {
		
		print "computing synonyms - $tagtype - pass $pass\n";
		
		foreach my $lc ( sort keys %{$synonyms{$tagtype}}) {
		
			my @smaller_synonyms = ();
			
			# synonyms don't support non roman languages at this point
			next if ($lc eq 'ar');
			next if ($lc eq 'he');
		
			foreach my $tagid (sort { length($a) <=> length($b) } keys %{$synonyms{$tagtype}{$lc}}) {

				my $max_length = length($tagid) - 3;
				$max_length > 40 and next; # don't lengthen already long synonyms
			
				# check if the synonym contains another small synonym
				
				my $tagid_c = $synonyms{$tagtype}{$lc}{$tagid};
				
				#print "computing synonyms for $tagid (canon: $tagid_c)\n";				
				
				# Does $tagid have other synonyms?
				if (scalar @{$synonyms_for{$tagtype}{$lc}{$tagid_c}} > 1) {
					if (length($tagid) < 20) {
						# limit length of synonyms for performance
						push @smaller_synonyms, $tagid;
						#print "$tagid (canon: $tagid_c) has other synonyms\n";
					}
				}
			
				foreach my $tagid2 (@smaller_synonyms) {
				
					last if length($tagid2) >  $max_length;
					
					# try to avoid looping:
					# e.g. bio, agriculture biologique, biologique -> agriculture bio -> agriculture agriculture biologique etc.
					
					my $tagid2_c = $synonyms{$tagtype}{$lc}{$tagid2};
										
					next if $tagid2_c eq $tagid_c;					
					# do not apply same synonym twice
					
					next if ((defined $synonym_contains_synonyms{$lc}{$tagid})
						and (defined $synonym_contains_synonyms{$lc}{$tagid}{$tagid2_c}));
										
					my $replace;
					my $before = '';
					my $after = '';
					
					# replace whole words/phrases only
					
					if ($tagid =~ /-${tagid2}-/) {
						$replace = "-${tagid2}-";
						$before = '-';
						$after = '-';
					}
					elsif ($tagid =~ /-${tagid2}$/) {
						$replace = "-${tagid2}\$";
						$before = '-';
					}
					elsif ($tagid =~ /^${tagid2}-/) {
						$replace = "^${tagid2}-";
						$after = '-';					
					}
					
					
					if (defined $replace) {
					
						#print "computing synonyms for $tagid ($tagid_c): replace: $replace \n";
					
						foreach my $tagid2_s (keys %{$synonyms_for_extended{$tagtype}{$lc}{$tagid2_c}}) {
						
							# don't replace a synonym by itself
							next if $tagid2_s eq $tagid2;
							
							# oeufs, oeufs frais -> oeufs frais frais -> oeufs frais frais frais
							# synonym already contained? skip if we are not shortening
							next if (($tagid =~ /${tagid2_s}/) and (length($tagid2_s) > length($tagid2)));
							next if ($tagid2_s =~ /$tagid/);
							
						
							my $tagid_new = $tagid;
							my $replaceby = "${before}${tagid2_s}${after}";
							$tagid_new =~ s/$replace/$replaceby/e;
							
							
							
							#print "computing synonyms for $tagid ($tagid0): replaceby: $replaceby - tagid4: $tagid4\n";
							
							if (not defined $synonyms_for_extended{$tagtype}{$lc}{$tagid_c}{$tagid_new}) {
								$synonyms_for_extended{$tagtype}{$lc}{$tagid_c}{$tagid_new} = 1;
								$synonyms{$tagtype}{$lc}{$tagid_new} = $tagid_c;
								if (defined $synonym_contains_synonyms{$lc}{$tagid_new}) {
									$synonym_contains_synonyms{$lc}{$tagid_new} = clone($synonym_contains_synonyms{$lc}{$tagid});
								}
								else {
									$synonym_contains_synonyms{$lc}{$tagid_new} = {};
								}
								$synonym_contains_synonyms{$lc}{$tagid_new}{$tagid2_c} = 1;
								print "synonyms_extended : synonyms{$tagtype}{$lc}{$tagid_new} = $tagid_c (tagid: $tagid - tagid2: $tagid2 - tagid2_c: $tagid2_c - tagid2_s: $tagid2_s - replace: $replace - replaceby: $replaceby)\n";
							}
						}
					}				
				
				}
			
			}
		
		}
		
		}
		
		
		# add more synonyms: remove stopwords and deal with simple plurals
		
		
		foreach my $lc (keys %{$synonyms{$tagtype}}) {
		
			foreach my $tagid (keys %{$synonyms{$tagtype}{$lc}}) {
			
				# stopwords
			
				my $tagid2 = remove_stopwords($tagtype,$lc,$tagid);
				$tagid2 = remove_plurals($lc,$tagid2);
				
				if (not defined $synonyms{$tagtype}{$lc}{$tagid2}) {
					$synonyms{$tagtype}{$lc}{$tagid2} = $synonyms{$tagtype}{$lc}{$tagid};
					print "taxonomy - more synonyms - tagid2: $tagid2 - tagid: $tagid\n";
				}	
				
			}
		}
		
		
		# 3rd phase: compute the hierarchy
		
			
# Nectars de fruits, nectar de fruits, nectars, nectar
# < Jus et nectars de fruits, jus et nectar de fruits
# > Nectars de goyave, nectar de goyave, nectar goyave
# > Nectars d'abricot, nectar d'abricot, nectars d'abricots, nectar 


		open (my $IN, "<:encoding(UTF-8)", "$data_root/taxonomies/$tagtype.txt");
	
		# print STDERR "Tags.pm - load_tags_taxonomy - tagtype: $tagtype - phase 3, computing hierarchy\n";
	

		my %parents = ();
		
		$canon_tagid = undef;
		
		while (<$IN>) {
		
			my $line = $_;
			chomp($line);
			$line =~ s/\s+$//;
			
			$line =~ s/’/'/g;
			
			# assume commas between numbers are part of the name
			# e.g. en:2-Bromo-2-Nitropropane-1,3-Diol, Bronopol
			# replace by a lower comma ‚

			$line =~ s/(\d),(\d)/$1‚$2/g;
						
			
			# replace escaped comma \, by a lower comma ‚
			$line =~ s/\\,/‚/g;
			
			# fr:E333(iii), Citrate tricalcique
			# -> E333iii
			
			$line =~ s/\(((i|v|x)+)\)/$1/i;
			
			# just remove everything between parenthesis
			#$line =~ s/\([^\)]*\)/ /g;
			#$line =~ s/\([^\)]*\)/ /g;
			#$line =~ s/\([^\)]*\)/ /g;
			# 3 times for embedded parenthesis
			
			$line =~ s/\(|\)/-/g;
			
			$line =~ s/\s+$//;				
			
			if ($line =~ /^(\s*)$/) {
				$canon_tagid = undef;
				%parents = ();
				print "taxonomy: next tag\n";
				next;
			}
			
			next if ($line =~ /^\#/);
				
			if ($line =~ /^<(\s*)(\w\w):/) {
				# Parent
				my $lc = $2;
				my $parent = $';
				$parent =~ s/^\s+//;
				$parent = normalize_percentages($parent, $lc);
				my $parentid = get_fileid($parent);
				my $canon_parentid = $synonyms{$tagtype}{$lc}{$parentid};
				if (not defined $canon_parentid) {
					my $stopped_parentid = $parentid;
					$stopped_parentid = remove_stopwords($tagtype,$lc,$parentid);
					$stopped_parentid = remove_plurals($lc,$stopped_parentid);
					$canon_parentid = $synonyms{$tagtype}{$lc}{$stopped_parentid};
					print "taxonomy : did not find parentid $parentid, trying stopped_parentid $stopped_parentid - result canon_parentid: $canon_parentid\n";
				}
				my $main_parentid = $translations_from{$tagtype}{"$lc:" . $canon_parentid};
				$parents{$main_parentid}++;
				# display a warning if the same parent is specified twice?
				print "taxonomy: tagtype: $tagtype - lc: $lc - parent: $parent - parentid: $parentid - canon_parentid: $canon_parentid - main_parentid: $main_parentid\n";
			}
			elsif ($line =~ /^(\w\w):/) {
				my $lc = $1;
				$line = $';
				$line =~ s/^\s+//;
				my @tags = split(/( )?,( )?/, $line);
				$current_tag = normalize_percentages($tags[0], $lc);
				$current_tagid = get_fileid($current_tag);
				
				if (not defined $canon_tagid) {
				
					$canon_tagid = "$lc:$current_tagid";
					
					
					# check if we already have an entry listed for one of the synonyms
					# this is useful for taxonomies that need to be merged, and that are concatenated
					
					# should only be applied to ingredients (and not to additives)
					
					if ($tagtype eq 'ingredients') {
										
					
					foreach my $tag2 (@tags) {
					
						my $tag = $tag2;

						$tag =~ s/^\s+//;
						$tag = normalize_percentages($tag, $lc);
						my $tagid = get_fileid($tag);
						my $possible_canon_tagid = $synonyms{$tagtype}{$lc}{$tagid};
						if (not defined $possible_canon_tagid) {
							my $stopped_tagid = $tagid;
							$stopped_tagid = remove_stopwords($tagtype,$lc,$tagid);
							$stopped_tagid = remove_plurals($lc,$stopped_tagid);
							$possible_canon_tagid = $synonyms{$tagtype}{$lc}{$stopped_tagid};
						}
						if ((not defined $canon_tagid) and (defined $possible_canon_tagid)) {
							$canon_tagid = "$lc:" . $possible_canon_tagid;
							print "taxonomy - we already have a canon_tagid $canon_tagid for the tag $tag\n";
							last;
						}
					}	
					
					}

			
				
					
					$just_tags{$tagtype}{$canon_tagid} = 1;
					foreach my $parentid (keys %parents) {
						defined $direct_parents{$tagtype}{$canon_tagid} or $direct_parents{$tagtype}{$canon_tagid} = {};
						$direct_parents{$tagtype}{$canon_tagid}{$parentid} = 1;
						defined $direct_children{$tagtype}{$parentid} or $direct_children{$tagtype}{$parentid} = {};
						$direct_children{$tagtype}{$parentid}{$canon_tagid} = 1;
						print "taxonomy: $parentid > $canon_tagid\n";
					}
				}
			}			
			elsif ($line =~ /^([a-z0-9_\-\.]+):(\w\w):(\s*)/) {
				my $property = $1;
				my $lc = $2;
				$line = $';
				$line =~ s/^\s+//;
				next if $property eq 'synonyms';
				next if $property eq 'stopwords';
				
				print "taxonomy - property - tagtype: $tagtype - lc: $lc - property: $property\n";
				defined $properties{$tagtype}{$canon_tagid} or $properties{$tagtype}{$canon_tagid} = {};
				$properties{$tagtype}{$canon_tagid}{"$property:$lc"} = $line;
			}
		}
		
	
		close $IN;
		
	
		
		
		# Compute all parents, breadth first
		
		# print STDERR "Tags.pm - load_tags_hierarchy - lc: $lc - tagtype: $tagtype - compute all parents breadth first\n";		
		
		my %longest_parent = ();
		
		# foreach my $tagid (keys %{$direct_parents{$tagtype}}) {   
		foreach my $tagid (keys %{$translations_to{$tagtype}}) {   
		
			# print STDERR "Tags.pm - load_tags_hierarchy - lc: $lc - tagtype: $tagtype - compute all parents breadth first - tagid: $tagid\n";		
		
			
			my @queue = ();
			
			if (defined $direct_parents{$tagtype}{$tagid}) {
				@queue = keys %{$direct_parents{$tagtype}{$tagid}};
			}			
			
			if (not defined $level{$tagtype}{$tagid}) {
				$level{$tagtype}{$tagid} = 1;
				if (defined $direct_parents{$tagtype}{$tagid}) {
					$longest_parent{$tagid} = (keys %{$direct_parents{$tagtype}{$tagid}})[0];
				}
			}
			
			my %seen = ();
		
			while ($#queue > -1) {
				my $parentid = shift @queue;
				#print "- $parentid\n";
				if (not defined $seen{$parentid}) {
					defined $all_parents{$tagtype}{$tagid} or $all_parents{$tagtype}{$tagid} = [];
					push @{$all_parents{$tagtype}{$tagid}}, $parentid;
					$seen{$parentid} = 1;
				
					if (not defined $level{$tagtype}{$parentid})  {
						$level{$tagtype}{$parentid} = 2;
						$longest_parent{$tagid} = $parentid;
					}				
					
					if (defined $direct_parents{$tagtype}{$parentid}) {
						foreach my $grandparentid (keys %{$direct_parents{$tagtype}{$parentid}}) {
							push @queue, $grandparentid;
							if ((not defined $level{$tagtype}{$grandparentid}) or ($level{$tagtype}{$grandparentid} <= $level{$tagtype}{$parentid})) {
								$level{$tagtype}{$grandparentid} = $level{$tagtype}{$parentid} + 1;
								$longest_parent{$parentid} = $grandparentid;
							}
						}
					}
				}
			}
		}
		
		# Compute all children, breadth first
		
		my %sort_key_parents = ();
		foreach my $tagid (keys %{$level{$tagtype}}) {
			my $key = '';
			if (defined $just_synonyms{$tagtype}{$tagid}) {
				$key = '! synonyms ';	# synonyms first
			}
			if (defined $all_parents{$tagtype}{$tagid}) {
				# sort parents according to level
				@{$all_parents{$tagtype}{$tagid}} = sort ( {$level{$tagtype}{$a} <=> $level{$tagtype}{$b} } @{$all_parents{$tagtype}{$tagid}} );
				$key .= '> ' . join((' > ', reverse @{$all_parents{$tagtype}{$tagid}})) . ' ';
			}
			$key .= '> ' . $tagid;
			$sort_key_parents{$tagid} = $key;
		}
				
		
		open (my $OUT, ">:encoding(UTF-8)", "$data_root/taxonomies/$tagtype.result.txt");
		
		
		# data structure to export the taxonomy to json format
		my %taxonomy_json = ();
		
		my $errors = '';
		
		foreach my $lc (keys %{$stopwords{$tagtype}}) {
			print $OUT $stopwords{$tagtype}{$lc . ".orig"};
		}
		print $OUT "\n\n";
		
		foreach my $tagid (
			sort { ($sort_key_parents{$a} cmp $sort_key_parents{$b})
				|| ($a cmp $b)
				}
				keys %{$level{$tagtype}} ) {
				
			$taxonomy_json{$tagid} = {name => {}};
			
			# print "taxonomy - compute all children - $tagid - level: $level{$tagtype}{$tagid} - longest: $longest_parent{$tagid} - syn: $just_synonyms{$tagtype}{$tagid} - sort_key: $sort_key_parents{$tagid} \n";
			if (defined $direct_parents{$tagtype}{$tagid}) {
				print "taxonomy - direct_parents\n";
				$taxonomy_json{$tagid}{parents} = [];
				foreach my $parentid (sort keys %{$direct_parents{$tagtype}{$tagid}}) {
					my $lc = $parentid;
					$lc =~ s/^(\w\w):.*/$1/;
					print $OUT "< $lc:" . $translations_to{$tagtype}{$parentid}{$lc} . "\n";
					push @{$taxonomy_json{$tagid}{parents}}, $parentid;
					print "taxonomy - parentid: $parentid > tagid: $tagid\n";
					if (not exists $translations_to{$tagtype}{$parentid}{$lc}) {
						$errors .= "ERROR - parent $parentid is not defined for tag $tagid\n";
					}
				}
			}
			
			if (defined $direct_children{$tagtype}{$tagid}) {
				print "taxonomy - direct_children\n";
				$taxonomy_json{$tagid}{children} = [];
				foreach my $childid (sort keys %{$direct_children{$tagtype}{$tagid}}) {
					my $lc = $childid;
					push @{$taxonomy_json{$tagid}{children}}, $childid;
				}
			}			
			
			my $main_lc = $tagid;
			$main_lc =~ s/^(\w\w):.*/$1/;
			
			my $i = 0;
			
			# print "taxonomy - compute all children - $tagid - translations \n";
			
			my $synonyms = '';
			if (defined $just_synonyms{$tagtype}{$tagid}) {
				$synonyms = "synonyms:";
				
				# remove synonyms that are also tags from just_synonyms
				if (defined $just_tags{$tagtype}{$tagid}) {
					delete $just_synonyms{$tagtype}{$tagid};
				}
			}
			
			foreach my $lc ($main_lc, sort keys %{$translations_to{$tagtype}{$tagid}}) {
				$i++;
				
				$taxonomy_json{$tagid}{name}{$lc} = $translations_to{$tagtype}{$tagid}{$lc};
				
				my $lc_tagid = get_fileid($translations_to{$tagtype}{$tagid}{$lc});
				
				# print "taxonomy - lc: $lc - tagid: $tagid - lc_tagid: $lc_tagid\n";
				if (defined $synonyms_for{$tagtype}{$lc}{$lc_tagid}) {
					if (not (($lc eq $main_lc) and ($i > 1))) {
						print $OUT "$synonyms$lc:" . join(", ", @{$synonyms_for{$tagtype}{$lc}{$lc_tagid}}) . "\n";
					}
					
					# additives has e-number as their name, and the first synonym is the additive name
					if (($tagtype eq 'additives') and (defined $synonyms_for{$tagtype}{$lc}{$lc_tagid}[1])) {
						$taxonomy_json{$tagid}{name}{$lc} .= " - " . $synonyms_for{$tagtype}{$lc}{$lc_tagid}[1];
					}
				}
			}
			
			if (defined $properties{$tagtype}{$tagid}) {
				
				foreach my $prop_lc (sort keys %{$properties{$tagtype}{$tagid}}) {
					print $OUT "$prop_lc: " . $properties{$tagtype}{$tagid}{$prop_lc} . "\n";
					if ($prop_lc =~ /^(.*):(\w\w)$/) {
						my $prop = $1;
						my $lc = $2;
						(defined $taxonomy_json{$tagid}{$prop}) or $taxonomy_json{$tagid}{$prop} = {};
						$taxonomy_json{$tagid}{$prop}{$lc} = $properties{$tagtype}{$tagid}{$prop_lc};
					}
					else {
						$taxonomy_json{$tagid}{$prop_lc} = $properties{$tagtype}{$tagid}{$prop_lc};
					}
				}
			}
			
			print $OUT "\n" ;
		
		}
		
		close $OUT;
		
		(-e "$www_root/data/taxonomies") or mkdir("$www_root/data/taxonomies", 0755);
		
		{
		binmode STDOUT, ":encoding(UTF-8)";
		open (my $OUT_JSON, ">", "$www_root/data/taxonomies/$tagtype.json");
		print $OUT_JSON encode_json(\%taxonomy_json);
		close ($OUT_JSON);
		# to serve pre-compressed files from Apache
		# nginx : needs nginx_static module
		# system("cp $www_root/data/taxonomies/$tagtype.json $www_root/data/taxonomies/$tagtype.json.json");
		# system("gzip $www_root/data/taxonomies/$tagtype.json");
		}
		
		$log->error("taxonomy errors", { errors => $errors }) if $log->is_error();
		
		my $taxonomy_ref = {
			stopwords => $stopwords{$tagtype},
			synonyms => $synonyms{$tagtype},
			just_synonyms => $just_synonyms{$tagtype},
			synonyms_for => $synonyms_for{$tagtype},
			synonyms_for_extended => $synonyms_for_extended{$tagtype},
			translations_from => $translations_from{$tagtype},
			translations_to => $translations_to{$tagtype},
			level => $level{$tagtype},
			direct_parents => $direct_parents{$tagtype},
			direct_children => $direct_children{$tagtype},
			all_parents => $all_parents{$tagtype},
			properties => $properties{$tagtype},
		};
		
		if ($publish) {
			store("$data_root/taxonomies/$tagtype.result.sto", $taxonomy_ref);
		}
		
	}
}


sub retrieve_tags_taxonomy {

	my $tagtype = shift;
	
	$taxonomy_fields{$tagtype} = 1;
	$tags_fields{$tagtype} = 1;
	
	# Check if we have a taxonomy for the previous or the next version
	if ($tagtype !~ /_(next|prev)/) {
		if (-e "$data_root/taxonomies/${tagtype}_prev.result.sto") {
			retrieve_tags_taxonomy("${tagtype}_prev");
		}
		if (-e "$data_root/taxonomies/${tagtype}_next.result.sto") {
			retrieve_tags_taxonomy("${tagtype}_next");
		}		
	}
	
	my $taxonomy_ref = retrieve("$data_root/taxonomies/$tagtype.result.sto");
	if (defined $taxonomy_ref) {
	
		$loaded_taxonomies{$tagtype} = 1;
		$stopwords{$tagtype} = $taxonomy_ref->{stopwords};
		$synonyms{$tagtype} = $taxonomy_ref->{synonyms};
		$synonyms_for{$tagtype} = $taxonomy_ref->{synonyms_for};
		$synonyms_for_extended{$tagtype} = $taxonomy_ref->{synonyms_for_extended};
		$just_synonyms{$tagtype} = $taxonomy_ref->{just_synonyms};
		# %just_synonyms was not included in taxonomies previously
		if (not exists $just_synonyms{$tagtype}) {
			$just_synonyms{$tagtype} = {};
		}
		$translations_from{$tagtype} = $taxonomy_ref->{translations_from};
		$translations_to{$tagtype} = $taxonomy_ref->{translations_to};
		$level{$tagtype} = $taxonomy_ref->{level};
		$direct_parents{$tagtype} = $taxonomy_ref->{direct_parents};
		$direct_children{$tagtype} = $taxonomy_ref->{direct_children};
		$all_parents{$tagtype} = $taxonomy_ref->{all_parents};
		$properties{$tagtype} = $taxonomy_ref->{properties};
	}
	
	$special_tags{$tagtype} = [];
	if (open (my $IN, "<:encoding(UTF-8)", "$data_root/taxonomies/special_$tagtype.txt")) {

		while (<$IN>) {
		
			my $line = $_;
			chomp($line);
			$line =~ s/\s+$//s;
			
			next if (($line =~ /^#/) or ($line eq ""));
			my $type = "with";
			if ($line =~ /^-/) {
				$type = "without";
				$line = $';
			}
			my $tag = canonicalize_taxonomy_tag("en", $tagtype, $line);
			my $tagid = get_taxonomyid($tag);		

			print "special_tag - line:<$line> - tag:<$tag> - tagid:<$tagid>\n";
			
			if ($tagid ne "") {
				push @{$special_tags{$tagtype}}, {
					tagid => $tagid,
					type => $type,
				};
			}
		}
	
		close ($IN);
	}
}

sub country_to_cc {
	my ($country) = @_;
	
	if ($country eq 'en:world') {
		return 'world';
	}
	elsif (defined $properties{countries}{$country}{"country_code_2:en"}) {
		return lc($properties{countries}{$country}{"country_code_2:en"});
	}
	
	return;
}

# load all tags hierarchies

# print STDERR "Tags.pm - loading tags hierarchies\n";
opendir DH2, "$data_root/lang" or die "Couldn't open $data_root/lang : $!";
foreach my $langid (readdir(DH2)) {
	next if $langid eq '.';
	next if $langid eq '..';
	# print STDERR "Tags.pm - reading tagtypes for lang $langid\n";
	next if ((length($langid) ne 2) and not ($langid eq 'other'));
	
	if (-e "$www_root/images/lang/$langid") {
		opendir DH, "$www_root/images/lang/$langid" or die "Couldn't open the current directory: $!";
		foreach my $tagtype (readdir(DH)) {
			next if $tagtype =~ /\./;
			# print STDERR "Tags: loading tagtype images $langid/$tagtype\n";			
			# print "Tags: loading tagtype images $langid/$tagtype\n";			
			load_tags_images($langid, $tagtype)
		}
		closedir(DH);	
	}
	
}
closedir(DH2);


foreach my $taxonomyid (@ProductOpener::Config::taxonomy_fields) {

	print "loading taxonomy $taxonomyid\n";
	retrieve_tags_taxonomy($taxonomyid);
	
}



# Build map of language codes and names

%language_codes = ();
%language_codes_reverse = ();

%Languages = (); # Hash of language codes, will be used to initialize %Lang::Langs

foreach my $language (keys %{$properties{languages}}) {

	my $lc = lc($properties{languages}{$language}{"language_code_2:en"});

	$language_codes{$lc} = $language;
	$language_codes_reverse{$language} = $lc;
	
	
	
	# %Languages will be passed to Lang::build_lang() to populate language names and 
	# to initialize to the English value all missing values for all the languages
	$Languages{$lc} = $translations_to{languages}{$language};
}


# Build map of local country names in official languages to (country, language)

$log->info("Building a map of local country names in official languages to (country, language)") if $log->is_info();

%country_names = ();
%country_codes = ();
%country_codes_reverse = ();
%country_languages = ();

foreach my $country (keys %{$properties{countries}}) {
	
	my $cc = country_to_cc($country);
	if (not (defined $cc)) {
		next;
	}
	
	$country_codes{$cc} = $country;
	$country_codes_reverse{$country} = $cc;

	$country_languages{$cc} = ['en'];
	if (defined $properties{countries}{$country}{"languages:en"}) {
		$country_languages{$cc} = [];
		foreach my $language (split(",", $properties{countries}{$country}{"languages:en"})) {
			$language = get_fileid($language);
			$language =~ s/-/_/;
			push @{$country_languages{$cc}}, $language;
			my $name = $translations_to{countries}{$country}{$language};
			my $nameid = get_fileid($name);
			if (not defined $country_names{$nameid}) {
				$country_names{$nameid} = [$cc, $country, $language];
				# print STDERR "country_names{$nameid} = [$cc, $country, $language]\n";
			}
		}
	}
}





sub init_select_country_options($) {

	# takes one minute to load

	my $Lang_ref = shift;
	
	# Build lists of countries and generate select button
	# <select data-placeholder="Choose a Country..." style="width:350px;" tabindex="1">
	#            <option value=""></option>
	#            <option value="United States">United States</option>
	#            <option value="United Kingdom">United Kingdom</option>

	$log->info("Buildin lists of countries and generate select button") if $log->is_info();

	foreach my $language (keys %Langs) {

		my $country_options = '';
		my $first_option = '';
			
		foreach my $country (sort {(get_fileid($translations_to{countries}{$a}{$language}) || get_fileid($translations_to{countries}{$a}{'en'}) )
			cmp (get_fileid($translations_to{countries}{$b}{$language}) || get_fileid($translations_to{countries}{$b}{'en'}))}
				keys %{$properties{countries}}
			) {
			
			my $cc = country_to_cc($country);
			if (not (defined $cc)) {
				next;
			}
			
			my $option = '<option value="' . $cc . '">' . display_taxonomy_tag($language,'countries',$country) . "</option>\n";
			
			if ($country ne 'en:world') {
				$country_options .= $option;
			}
			else {
				$first_option = $option;
			}
		}
		
		$Lang_ref->{select_country_options}{$language} = $first_option . $country_options;
		
	}
}




$log->info("Tags.pm - 1") if $log->is_info();

sub gen_tags_hierarchy($$) {

	my $tagtype = shift;
	my $tags_list = shift;	# comma-separated list of tags, not in a specific order
	
	if (not (defined $tags_all_parents{$lc}) and (defined $tags_all_parents{$lc}{$tagtype})) {
		return (split(/(\s*),(\s*)/, $tags_list));
	}
	
	my %tags = ();
	
	foreach my $tag2 (split(/(\s*),(\s*)/, $tags_list)) {
		my $tag = $tag2;
		$tag = canonicalize_tag2($tagtype, $tag);
		my $tagid = get_fileid($tag);
		next if $tagid eq '';
		$tags{$tag} = 1;
		if ((defined $tags_all_parents{$lc}) and (defined $tags_all_parents{$lc}{$tagtype}) and (defined $tags_all_parents{$lc}{$tagtype}{$tagid})) {
			foreach my $parentid (@{$tags_all_parents{$lc}{$tagtype}{$tagid}}) {
				$tags{canonicalize_tag2($tagtype, $parentid)} = 1;
			}
		}
	}
	
	if (0) {
	
		foreach my $tag (sort { $tags_level{$lc}{$tagtype}{get_fileid($b)} <=> $tags_level{$lc}{$tagtype}{get_fileid($a)} } keys %tags) {	
			my $tagid = get_fileid($tag);
			# print STDERR "hierarchy: tag: $tag - tagid: $tagid - tag_level: " . $tags_level{$lc}{$tagtype}{get_fileid($tag)} . " - tag_level2 : " . $tags_level{$lc}{$tagtype}{$tagid} . " \n";
		}
	
	}
	
	my @sorted_list = sort { $tags_level{$lc}{$tagtype}{get_fileid($b)} <=> $tags_level{$lc}{$tagtype}{get_fileid($a)} } keys %tags;
	return @sorted_list;
}


sub gen_tags_hierarchy_taxonomy($$$) {

	my $tag_lc = shift;
	my $tagtype = shift;
	my $tags_list = shift;	# comma-separated list of tags, not in a specific order
	
	if (not defined $all_parents{$tagtype}) {
		$log->warning("all_parents{\$tagtype} not defined", { tagtype => $tagtype }) if $log->is_warning();
		return (split(/(\s*),(\s*)/, $tags_list));
	}
	
	my %tags = ();
	
	foreach my $tag2 (split(/(\s*),(\s*)/, $tags_list)) {
		my $tag = $tag2;
		my $l = $tag_lc;
		if ($tag =~ /^(\w\w):/) {
			$l = $1;
			$tag = $';			
		}
		next if $tag eq '';
		$tag = canonicalize_taxonomy_tag($l,$tagtype, $tag);
		my $tagid = get_taxonomyid($tag);
		next if $tagid eq '';
		if ($tagid =~ /:$/) {
			#print STDERR "taxonomy - empty tag: $tag - l: $l - tagid: $tagid - tag_lc: >$tags_list< \n";
			next;
		}
		$tags{$tag} = 1;
		if (defined $all_parents{$tagtype}{$tagid}) {
			foreach my $parentid (@{$all_parents{$tagtype}{$tagid}}) {
				if ($parentid eq 'fr:') {
					$log->info("empty parent id for taxonmy", { parentid => $parentid, tagid => $tagid, tag_lc => $tags_list }) if $log->is_info();
					next;
				}			
				$tags{$parentid} = 1;				
			}
		}
	}
	
	my @sorted_list = sort { ($level{$tagtype}{$b} <=> $level{$tagtype}{$a}) || ($a cmp $b) } keys %tags;
	return @sorted_list;
}



sub gen_ingredients_tags_hierarchy_taxonomy($$) {

	# for ingredients, we should keep the order
	# question: what do do with parents?

	my $tag_lc = shift;
	my $tagtype = "ingredients";
	my $tags_list = shift;	# comma-separated list of tags, not in a specific order
	
	if (not defined $all_parents{$tagtype}) {
		$log->warning("all_parents{\$tagtype} not defined", { tagtype => $tagtype }) if $log->is_warning();
		return (split(/(\s*),(\s*)/, $tags_list));
	}
	
	my @tags = ();
	
	foreach my $tag2 (split(/(\s*),(\s*)/, $tags_list)) {
		my $tag = $tag2;
		my $l = $tag_lc;
		if ($tag =~ /^(\w\w):/) {
			$l = $1;
			$tag = $';			
		}
		next if $tag eq '';
		$tag = canonicalize_taxonomy_tag($l,$tagtype, $tag);
		my $tagid = get_taxonomyid($tag);
		next if $tagid eq '';
		if ($tagid =~ /:$/) {
			#print STDERR "taxonomy - empty tag: $tag - l: $l - tagid: $tagid - tag_lc: >$tags_list< \n";
			next;
		}
		push @tags, $tag;
		
		if (defined $all_parents{$tagtype}{$tagid}) {
			foreach my $parentid (@{$all_parents{$tagtype}{$tagid}}) {
				if ($parentid eq 'fr:') {
					$log->info("empty parent id for taxonmy", { parentid => $parentid, tagid => $tagid, tag_lc => $tags_list }) if $log->is_info();
					next;
				}			
				push @tags, $parentid;
			}
		}
	}
	
	return @tags;
}



sub get_city_code($) {

	my $tag = shift;
	my $city_code = uc(get_fileid($tag));
	$city_code =~ s/^(EMB|FR)/FREMB/i;
	$city_code =~ s/CE$//i;
	$city_code =~ s/-//g;
	$city_code =~ s/(\d{5})\d+/$1/;
	$city_code =~ s/[A-Z]+$//i;
	# print STDERR "get_city_code : tag: $tag - city_code: $city_code \n";
	return $city_code;
}

sub get_tag_css_class($$$) {
	my $target_lc = shift; $target_lc =~ s/_.*//;
	my $tagtype = shift;
	my $tag = shift;
	$tag = display_taxonomy_tag($target_lc,$tagtype, $tag);
	my $tagid = get_taxonomyid($tag);
	my $tagurl = get_taxonomyurl($tagid);

	my $canon_tagid = canonicalize_taxonomy_tag($target_lc, $tagtype, $tag);

	# Don't treat users as tags.
	if (($tagtype eq 'photographers') or ($tagtype eq 'editors') or ($tagtype eq 'informers') or ($tagtype eq 'correctors') or ($tagtype eq 'checkers')) {
		return "";
	}
	
	my $cssclass = "tag ";
	if (not exists_taxonomy_tag($tagtype, $canon_tagid)) {
		$cssclass .= "user_defined";
	}
	else {
		$cssclass .= "well_known";
	}

	return $cssclass;
}

sub display_tag_link($$) {

	my $tagtype = shift;
	my $tag = shift;
	$tag = canonicalize_tag2($tagtype, $tag);
	my $tagid = get_fileid($tag);
	my $tagurl = get_urlid($tagid);
	
	my $path = $tag_type_singular{$tagtype}{$lc};

	my $tag_lc;
	if ($tag =~ /^(\w\w):/) {
		$tag_lc = $1;
		$tag = $';
	}
	
	my $html;
	if ((defined $tag_lc) and ($tag_lc ne $lc)) {
		$html = "<a href=\"/$path/$tagurl\" lang=\"$tag_lc\">$tag</a>";
	}
	else {
		$html = "<a href=\"/$path/$tagurl\">$tag</a>";
	}
	
	if ($tagtype eq 'emb_codes') {
	
		my $city_code = get_city_code($tagid);
				
		if (defined $emb_codes_cities{$city_code}) {
			$html .= " - " . display_tag_link('cities', $emb_codes_cities{$city_code}) ;
		}
	}
	
	return $html;
}


sub canonicalize_taxonomy_tag_link($$$) {
	my $target_lc = shift; $target_lc =~ s/_.*//;
	my $tagtype = shift;
	my $tag = shift;
	$tag = display_taxonomy_tag($target_lc,$tagtype, $tag);
	my $tagurl = get_taxonomyurl($tag);
	
	my $path = $tag_type_singular{$tagtype}{$target_lc};
	
	return "/$path/$tagurl";
}



sub canonicalize_taxonomy_2tag_link($$$$$) {
	my $target_lc = shift; $target_lc =~ s/_.*//;
	my $tagtype = shift;
	my $tag = shift;
	my $tagtype2 = shift;
	my $tag2 = shift;	
	
	$tag = display_taxonomy_tag($target_lc,$tagtype, $tag);
	my $tagurl = get_taxonomyurl($tag);
	my $path = $tag_type_singular{$tagtype}{$target_lc};
	
	$tag2 = display_taxonomy_tag($target_lc,$tagtype2, $tag2);
	my $tagurl2 = get_taxonomyurl($tag2);
	my $path2 = $tag_type_singular{$tagtype2}{$target_lc};	
	
	return "/$path/$tagurl/$path2/$tagurl2";
}


sub display_taxonomy_tag_link($$$) {

	my $target_lc = shift; $target_lc =~ s/_.*//;
	my $tagtype = shift;
	my $tag = shift;
	$tag = display_taxonomy_tag($target_lc,$tagtype, $tag);
	my $tagid = get_taxonomyid($tag);
	my $tagurl = get_taxonomyurl($tagid);

	my $tag_lc;
	if ($tag =~ /^(\w\w):/) {
		$tag_lc = $1;
		$tag = $';
	}
	
	my $path = $tag_type_singular{$tagtype}{$target_lc};
	
	my $cssclass = get_tag_css_class($target_lc, $tagtype, $tag);

	my $html;
	if ((defined $tag_lc) and ($tag_lc ne $lc)) {
		$html = "<a href=\"/$path/$tagurl\" class=\"$cssclass\" lang=\"$tag_lc\">$tag</a>";
	}
	else {
		$html = "<a href=\"/$path/$tagurl\" class=\"$cssclass\">$tag</a>";
	}
	
	if ($tagtype eq 'emb_codes') {
	
		my $city_code = get_city_code($tagid);
				
		if (defined $emb_codes_cities{$city_code}) {
			$html .= " - " . display_tag_link('cities', $emb_codes_cities{$city_code}) ;
		}
	}
	
	return $html;
}


sub display_tags_list_orig($$) {

	my $tagtype = shift;
	my $tags_list = shift;
	my $html = join(', ', map { display_tag_link($tagtype, $_) } split(/,/, $tags_list));
	return $html;
}


sub display_tags_list($$) {

	my $tagtype = shift;
	my $tags_list = shift;
	my $html = '';
	my $images = '';
	foreach my $tag (split(/,/, $tags_list)) {
		$html .= display_tag_link($tagtype, $tag) . ", ";
		
		if (defined $tags_images{$lc}{$tagtype}{get_fileid($tag)}) {
			my $img = $tags_images{$lc}{$tagtype}{get_fileid($tag)};
			my $size = '';
			if ($img =~ /\.(\d+)x(\d+)/) {
				$size = " width=\"$1\" height=\"$2\"";
			}
			$images .= <<HTML
<img src="/images/lang/$lc/$tagtype/$img"$size/ style="display:inline"> 
HTML
;
		}
	}
	$html =~ s/, $//;
	if ($images ne '') {
		$html .= "<br />$images";
	}
	
	return $html;
}




sub display_tag_and_parents($$) {

	my $tagtype = shift;
	my $tagid = shift;
	
	my $html = '';
	
	if ((defined $tags_all_parents{$lc}) and (defined $tags_all_parents{$lc}{$tagtype}) and (defined $tags_all_parents{$lc}{$tagtype}{$tagid})) {
		foreach my $parentid (@{$tags_all_parents{$lc}{$tagtype}{$tagid}}) {
			$html = display_tag_link($tagtype, $parentid) . ', ' . $html;
		}
	}
	
	$html =~ s/, $//;

	return $html;
}		


sub display_tag_and_parents_taxonomy($$) {

	my $target_lc = $lc;
	my $tagtype = shift;
	my $tagid = shift;
	
	my $html = '';
	
	if ((defined $all_parents{$tagtype}) and (defined $all_parents{$tagtype}{$tagid})) {
		foreach my $parentid (@{$all_parents{$tagtype}{$tagid}}) {
			$html = display_taxonomy_tag_link($target_lc,$tagtype, $parentid) . ', ' . $html;
		}
	}
	
	$html =~ s/, $//;

	return $html;
}	


sub display_parents_and_children($$$) {

	my $target_lc = shift; $target_lc =~ s/_.*//;
	my $tagtype = shift;
	my $tagid = shift;

	my $html = '';
	
	if (defined $taxonomy_fields{$tagtype}) {
	
		# print STDERR "family - $target_lc - tagtype: $tagtype - tagid: $tagid - all_parents{$tagtype}{$tagid}: $all_parents{$tagtype}{$tagid} - direct_children{$tagtype}{$tagid}: $direct_children{$tagtype}{$tagid}\n";
	
		if ((defined $all_parents{$tagtype}) and (defined $all_parents{$tagtype}{$tagid})) {
			$html .= "<p>" . lang("tag_belongs_to") . "</p>\n";
			$html .= "<p>" . display_tag_and_parents_taxonomy($tagtype, $tagid) . "</p>\n";
		}
		
		if ((defined $direct_children{$tagtype}) and (defined $direct_children{$tagtype}{$tagid})) {
			$html .= "<p>" . lang("tag_contains") . "</p><ul>\n";
			foreach my $childid (sort keys %{$direct_children{$tagtype}{$tagid}}) {
				$html .= "<li>" . display_taxonomy_tag_link($target_lc,$tagtype, $childid) . "</li>\n";
			}		
			$html .= "</ul>\n";
		}	
	}
	else {
	
		if ((defined $tags_all_parents{$lc}) and (defined $tags_all_parents{$lc}{$tagtype}) and (defined $tags_all_parents{$lc}{$tagtype}{$tagid})) {
			$html .= "<p>" . lang("tag_belongs_to") . "</p>\n";
			$html .= "<p>" . display_tag_and_parents($tagtype, $tagid) . "</p>\n";
		}
		
		if ((defined $tags_direct_children{$lc}) and (defined $tags_direct_children{$lc}{$tagtype}) and (defined $tags_direct_children{$lc}{$tagtype}{$tagid})) {
			$html .= "<p>" . lang("tag_contains") . "</p><ul>\n";
			foreach my $childid (sort keys %{$tags_direct_children{$lc}{$tagtype}{$tagid}}) {
				$html .= "<li>" . display_tag_link($tagtype, $childid) . "</li>\n";
			}		
			$html .= "</ul>\n";
		}

	}
	
	return $html;
}




sub display_tags_hierarchy($$) {

	my $tagtype = shift;
	my $tags_ref = shift;
	
	my $html = '';
	my $images = '';
	if (defined $tags_ref) {
		foreach my $tag (@$tags_ref) {
			$html .= display_tag_link($tagtype, $tag) . ", ";
			
#			print STDERR "abbio - lc: $lc - tagtype: $tagtype - tag: $tag\n";
			
			if (defined $tags_images{$lc}{$tagtype}{get_fileid($tag)}) {
				my $img = $tags_images{$lc}{$tagtype}{get_fileid($tag)};
				my $size = '';
				if ($img =~ /\.(\d+)x(\d+)/) {
					$size = " width=\"$1\" height=\"$2\"";
				}
				# print STDERR "abbio - lc: $lc - tagtype: $tagtype - tag: $tag - img: $img\n";

				$images .= <<HTML
<img src="/images/lang/$lc/$tagtype/$img"$size/ style="display:inline"> 
HTML
;
			}
		}
		$html =~ s/, $//;
		if ($images ne '') {
			$html .= "<br />$images";
		}
	}
	return $html;
}


sub display_tags_hierarchy_taxonomy($$$) {

	my $target_lc = shift; $target_lc =~ s/_.*//;
	my $tag_lc = undef;
	my $tagtype = shift;
	my $tags_ref = shift;
	
	my $html = '';
	my $images = '';
	if (defined $tags_ref) {
		foreach my $tag (@$tags_ref) {
			$html .= display_taxonomy_tag_link($target_lc, $tagtype, $tag) . ", ";
			
			my $img;
			my $canon_tagid = canonicalize_taxonomy_tag($target_lc,$tagtype, $tag);
			my $target_title = display_taxonomy_tag($target_lc,$tagtype,$canon_tagid); 
			
			my $img_lc = $target_lc;
			
			my $lc_imgid = get_fileid($target_title);
			my $en_imgid = get_taxonomyid($canon_tagid);
			my $tag_lc = undef;
			if ($en_imgid =~ /^(\w\w):/) {
				$en_imgid = $';
				$tag_lc = $1;
			}
			
			if (defined $tags_images{$target_lc}{$tagtype}{$lc_imgid}) {
				$img = $tags_images{$target_lc}{$tagtype}{$lc_imgid};
			}
			elsif ((defined $tag_lc) and (defined $tags_images{$tag_lc}) and (defined $tags_images{$tag_lc}{$tagtype}{$en_imgid})) {
				$img = $tags_images{$tag_lc}{$tagtype}{$en_imgid};
				$img_lc = $tag_lc;
			}
			elsif (defined $tags_images{'en'}{$tagtype}{$en_imgid}) {
				$img = $tags_images{'en'}{$tagtype}{$en_imgid};
				$img_lc = 'en';
			}
			
			if ($tag =~ /certified|montagna/) {
				$log->debug("labels_logo", { lc_imgid => $lc_imgid, en_imgid => $en_imgid, canon_tagid => $canon_tagid, img => $img }) if $log->is_debug();
			}

			
			if ($img) {
				my $size = '';
				if ($img =~ /\.(\d+)x(\d+)/) {
					$size = " width=\"$1\" height=\"$2\"";
				}
				$images .= <<HTML
<img src="/images/lang/${img_lc}/$tagtype/$img"$size/ style="display:inline"> 
HTML
;
			}
		}
		$html =~ s/, $//;
		if ($images ne '') {
			$html .= "<br />$images";
		}
	}
	return $html;
}


sub canonicalize_saint($) {
	my $s = shift;
	return "Saint-" . ucfirst($s);
}


sub capitalize_tag($)
{
	my $tag = shift;
	$tag = ucfirst($tag);
	$tag =~ s/(?<= |_|')(\w)(?!')/uc($1)/eg;
	$tag =~ s/\b(de|du|des|au|aux|des|à|a|en|le|la|les)\b/lcfirst($1)/eig;
	$tag =~ s/(?<=_)(de|du|des|au|aux|des|à|a|en|le|la|les)(?=_)/lcfirst($1)/eig;
	return $tag;
}




sub canonicalize_tag2($$)
{
	my $tagtype = shift;
	my $tag = shift;
	#$tag = lc($tag);
	my $canon_tag = $tag;
	$canon_tag =~ s/^ //g;
	$canon_tag =~ s/ $//g;

	my $tagid = get_fileid($tag);
	if ((defined $canon_tags{$lc}) and (defined $canon_tags{$lc}{$tagtype}) and (defined $canon_tags{$lc}{$tagtype}{$tagid})) {
		$canon_tag = $canon_tags{$lc}{$tagtype}{$tagid};
	}
	elsif ($canon_tag eq $tagid) {
		$canon_tag =~ s/-/ /g;
		$canon_tag = ucfirst($tag);
	}
	
	#$canon_tag =~ s/(-|\'|_|\n)/ /g;	# - and ' might be added back

	$tag = $canon_tag;
	
	if (($tagtype ne "additives_debug") and ($tagtype =~ /^additives/)) {
	
		# e322-lecithines -> e322
		my $tagid = get_fileid($tag);
		$tagid =~ s/-.*//;
		my $other_name = $ingredients_classes{$tagtype}{$tagid}{other_names};
		$other_name =~ s/,.*//;
		if ($other_name ne '') {
			$other_name = " - " . $other_name;
		}
		$tag = ucfirst($tagid) . $other_name;
	}	
	
	elsif (($tagtype eq 'ingredients_from_palm_oil') or ($tagtype eq 'ingredients_that_may_be_from_palm_oil')) {
		my $tagid = get_fileid($tag);
		$tag = $ingredients_classes{$tagtype}{$tagid}{name};
	}
	
	elsif ($tagtype eq 'emb_codes') {
	
		$tag = uc($tag);
		
		if (1) {
			$tag = normalize_packager_codes($tag);
			if ($lc =~ /fr|es|it|pt/) {
				$tag =~ s/EC$/CE/;
			}
			elsif ($lc =~ /de|nl/) {
				$tag =~ s/EC$/EG/;
			}
		}
		else {
			# old, FR only
		$tag =~ s/([A-Z])-/$1 /g;
		$tag =~ s/-([A-Z])/ $1/g;
		$tag =~ s/(\d)-(\d)/$1.$2/g;
		}
	}
	
	elsif ($tagtype eq 'cities') {
		if (defined $cities{$tagid}) {
			$tag = $cities{$tagid};
		}
	}
	
	return $tag;
	
}

sub get_taxonomyid($) {

	my $tagid = shift;
	if ($tagid =~ /^(\w\w):/) {
		return lc($1) . ':' . get_fileid($');
	}
	else {
		return get_fileid($tagid);
	}
}

sub get_taxonomyurl($) {

	my $tagid = shift;
	if ($tagid =~ /^(\w\w):/) {
		return lc($1) . ':' . get_urlid($');
	}
	else {
		return get_urlid($tagid);
	}
}


sub canonicalize_taxonomy_tag($$$)
{
	my $tag_lc = shift;
	my $tagtype = shift;
	my $tag = shift;
	#$tag = lc($tag);
	$tag =~ s/^ //g;
	$tag =~ s/ $//g;		
	
	if (($tag =~ /^(\w+:\w\w):(.+)/) and (defined $properties{$tagtype})) {
		# Test for linked data, ie. wikidata:en:Q1234
		my $property_key = $1;
		my $property_value = $2;
		my $matched_tagid;
		foreach my $canon_tagid (keys %{$properties{$tagtype}}) {
			if ((defined $properties{$tagtype}{$canon_tagid}{$property_key}) and ($properties{$tagtype}{$canon_tagid}{$property_key} eq $property_value)) {
				if (defined $matched_tagid) {
					# Bail out on multiple matches for a single tag.
					undef $matched_tagid;
					last;
				}
				
				$matched_tagid = $canon_tagid;
			}
		}

		if (defined $matched_tagid) {
			return $matched_tagid;
		}
	}

	if ($tag =~ /^https?:\/\/.+/) {
		# Test for linked data URLs, ie. https://www.wikidata.org/wiki/Q1234
		my $matched_tagid;
		foreach my $property_key (keys %weblink_templates) {
			next if not defined $weblink_templates{$property_key}{parse};
			my $property_value = $weblink_templates{$property_key}{parse}->($tag);
			if (defined $property_value) {
				foreach my $canon_tagid (keys %{$properties{$tagtype}}) {
					if ((defined $properties{$tagtype}{$canon_tagid}{$property_key}) and ($properties{$tagtype}{$canon_tagid}{$property_key} eq $property_value)) {
						if (defined $matched_tagid) {
							# Bail out on multiple matches for a single tag.
							undef $matched_tagid;
							last;
						}
						
						$matched_tagid = $canon_tagid;
					}
				}
			}
		}

		if (defined $matched_tagid) {
			return $matched_tagid;
		}
	}
		
	if ($tag =~ /^(\w\w):/) {
		$tag_lc = $1;
		$tag = $';
	}

	$tag = normalize_percentages($tag, $tag_lc);
	my $tagid = get_fileid($tag);
	
	if ($tagtype =~ /^additives/) {
		# convert the E-number + name into just E-number (we get those in urls like /additives/e330-citric-acid)
		# check E + 1 digit in order to not convert Erythorbate-de-sodium to Erythorbate
		$tagid =~ s/^e(\d.*?)-(.*)$/e$1/i;
	}	

	
	if ((defined $synonyms{$tagtype}) and (defined $synonyms{$tagtype}{$tag_lc}) and (defined $synonyms{$tagtype}{$tag_lc}{$tagid})) {
		$tagid = $synonyms{$tagtype}{$tag_lc}{$tagid};
	}
	else {
		# try removing stopwords and plurals
		my $tagid2 = remove_stopwords($tagtype,$tag_lc,$tagid);
		$tagid2 = remove_plurals($tag_lc,$tagid2);
		
		# try to add / remove hyphens (e.g. antioxydant / anti-oxydant)
		my $tagid3 = $tagid2;
		my $tagid4 = $tagid2;
		$tagid3 =~ s/(anti)(-| )/$1/;
		$tagid4 =~ s/(anti)([a-z])/$1-$2/;
		
		if ((defined $synonyms{$tagtype}) and (defined $synonyms{$tagtype}{$tag_lc}) and (defined $synonyms{$tagtype}{$tag_lc}{$tagid2})) {
			$tagid = $synonyms{$tagtype}{$tag_lc}{$tagid2};
		}
		if ((defined $synonyms{$tagtype}) and (defined $synonyms{$tagtype}{$tag_lc}) and (defined $synonyms{$tagtype}{$tag_lc}{$tagid3})) {
			$tagid = $synonyms{$tagtype}{$tag_lc}{$tagid3};
		}
		if ((defined $synonyms{$tagtype}) and (defined $synonyms{$tagtype}{$tag_lc}) and (defined $synonyms{$tagtype}{$tag_lc}{$tagid4})) {
			$tagid = $synonyms{$tagtype}{$tag_lc}{$tagid4};
		}		
		elsif ($tag_lc ne 'en') {
			# try English
			# try removing stopwords and plurals
			my $tagid2 = remove_stopwords($tagtype,'en',$tagid);
			$tagid2 = remove_plurals('en',$tagid2);
			if ((defined $synonyms{$tagtype}) and (defined $synonyms{$tagtype}{'en'}) and (defined $synonyms{$tagtype}{'en'}{$tagid2})) {
				$tagid = $synonyms{$tagtype}{'en'}{$tagid2};
				$tag_lc = 'en';
			}			
			else {
				# try Latin
				if ((defined $synonyms{$tagtype}) and (defined $synonyms{$tagtype}{"la"}) and (defined $synonyms{$tagtype}{"la"}{$tagid})) {
					$tagid = $synonyms{$tagtype}{"la"}{$tagid};
					$tag_lc = 'la';
				}
			}		
		}
	}
	
	$tagid = $tag_lc . ':' . $tagid;
	
	if ((defined $translations_from{$tagtype}) and (defined $translations_from{$tagtype}{$tagid})) {
		$tagid = $translations_from{$tagtype}{$tagid};
	}
	else {
		# no translation available, tag is not in known taxonomy
		$tagid = $tag_lc . ':' . $tag;
	}
	
	return $tagid;
	
}


sub generate_spellcheck_candidates($) {

	my $tagid = shift;
	
	my @candidates = [$tagid];
	
	# https://norvig.com/spell-correct.html
	# "All edits that are one edit away from `word`."
    # letters    = 'abcdefghijklmnopqrstuvwxyz'
    # splits     = [(word[:i], word[i:])    for i in range(len(word) + 1)]
    # deletes    = [L + R[1:]               for L, R in splits if R]
    # transposes = [L + R[1] + R[0] + R[2:] for L, R in splits if len(R)>1]
    # replaces   = [L + c + R[1:]           for L, R in splits if R for c in letters]
    # inserts    = [L + c + R               for L, R in splits for c in letters]
	
	my $l = length($tagid);
	
	for (my $i = 0; $i <= $l; $i++) {
	
		my $left = substr($tagid, 0, $i);
		my $right = substr($tagid, $i);
		
		# delete
		if ($i < $l) {
			push @candidates, $left . substr($right, 1);
		}
		
		foreach my $c ("a".."z") {
		
			# insert
			push @candidates, $left . $c . $right;
			
			# replace
			if ($i < $l) {
				push @candidates, $left . $c . substr($right, 1);
			}
		}
		
		if (($i > 0) and ($i < $l)) {
			push @candidates, $left . "-" . $right;
			if ($i < ($l - 1)) {
				push @candidates, $left . "-" . substr($right, 1);
			}
		}		
	}
	
	return @candidates;
}


sub spellcheck_taxonomy_tag($$$)
{
	my $tag_lc = shift;
	my $tagtype = shift;
	my $tag = shift;
	#$tag = lc($tag);
	$tag =~ s/^ //g;
	$tag =~ s/ $//g;		

		
	if ($tag =~ /^(\w\w):/) {
		$tag_lc = $1;
		$tag = $';
	}

	$tag = normalize_percentages($tag, $tag_lc);
	my $tagid = get_fileid($tag);
	
	if ($tagtype =~ /^additives/) {
		# convert the E-number + name into just E-number (we get those in urls like /additives/e330-citric-acid)
		# check E + 1 digit in order to not convert Erythorbate-de-sodium to Erythorbate
		$tagid =~ s/^e(\d.*?)-(.*)$/e$1/i;
	}	

	my @candidates = ($tag);

	if (length($tag) > 6) {
		@candidates = generate_spellcheck_candidates($tag);
	}
	
	my $result;
	my $resultid;
	my $canon_resultid;
	my $correction;
	my $last_candidate;
	
	foreach my $candidate (@candidates) {
	
		$last_candidate = $candidate;
		$tagid = get_fileid($candidate);
	
		if ((defined $synonyms{$tagtype}) and (defined $synonyms{$tagtype}{$tag_lc}) and (defined $synonyms{$tagtype}{$tag_lc}{$tagid})) {
			$result = $synonyms{$tagtype}{$tag_lc}{$tagid};
			last;
		}
		else {
			# try removing stopwords and plurals
			# my $tagid2 = remove_stopwords($tagtype,$tag_lc,$tagid);
			# $tagid2 = remove_plurals($tag_lc,$tagid2);
			my $tagid2 = remove_plurals($tag_lc,$tagid);
			
			# try to add / remove hyphens (e.g. antioxydant / anti-oxydant)
			my $tagid3 = $tagid2;
			my $tagid4 = $tagid2;
			$tagid3 =~ s/(anti)(-| )/$1/;
			$tagid4 =~ s/(anti)([a-z])/$1-$2/;
			
			if ((defined $synonyms{$tagtype}) and (defined $synonyms{$tagtype}{$tag_lc}) and (defined $synonyms{$tagtype}{$tag_lc}{$tagid2})) {
				$result = $synonyms{$tagtype}{$tag_lc}{$tagid2};
				last;
			}
			if ((defined $synonyms{$tagtype}) and (defined $synonyms{$tagtype}{$tag_lc}) and (defined $synonyms{$tagtype}{$tag_lc}{$tagid3})) {
				$result = $synonyms{$tagtype}{$tag_lc}{$tagid3};
				last;
			}
			if ((defined $synonyms{$tagtype}) and (defined $synonyms{$tagtype}{$tag_lc}) and (defined $synonyms{$tagtype}{$tag_lc}{$tagid4})) {
				$result = $synonyms{$tagtype}{$tag_lc}{$tagid4};
				last;
			}		
		}	
	}
	
	
	if (defined $result) {
	
		$correction = $last_candidate;
		$tagid = $tag_lc . ':' . $result;
		$resultid = $tagid;
		
		if ((defined $translations_from{$tagtype}) and (defined $translations_from{$tagtype}{$tagid})) {
			$canon_resultid = $translations_from{$tagtype}{$tagid};
		}
	}

	return ($canon_resultid, $resultid, $correction);
	
}





sub exists_taxonomy_tag($$) {

	my $tagtype = shift;
	my $tagid = shift;

	return ((exists $translations_from{$tagtype}) and (exists $translations_from{$tagtype}{$tagid}));
}


sub display_taxonomy_tag($$$)
{
	my $target_lc = shift; $target_lc =~ s/_.*//;
	my $tagtype = shift;
	my $tag = shift;
	
	if (not defined $tag) {
		$log->warn("display_taxonomy_tag() called for undefined \$tag") if $log->is_warn();
		return "";
	}
	
	$tag =~ s/^ //g;
	$tag =~ s/ $//g;		
	
	if (not defined $taxonomy_fields{$tagtype}) {
		
		return canonicalize_tag2($tagtype,$tag);
	}
	
	my $tag_lc;
		
	if ($tag =~ /^(\w\w):/) {
		$tag_lc = $1;
		$tag = $';
	}
	else {
		# print STDERR "WARNING - display_taxonomy_tag - $tag has no language code, assuming lc: $lc\n";
		$tag_lc = $lc;
	}
	
	my $tagid = $tag_lc . ':' . get_fileid($tag);
	
	my $display = '';
	
	if ((defined $translations_to{$tagtype}) and (defined $translations_to{$tagtype}{$tagid}) and (defined $translations_to{$tagtype}{$tagid}{$target_lc})) {
		# we have a translation for the target language
		# print STDERR "display_taxonomy_tag - translation for the target language - translations_to{$tagtype}{$tagid}{$target_lc} : $translations_to{$tagtype}{$tagid}{$target_lc}\n";
		$display = $translations_to{$tagtype}{$tagid}{$target_lc};
	}	
	else {
		# use tag language
		if ((defined $translations_to{$tagtype}) and (defined $translations_to{$tagtype}{$tagid}) and (defined $translations_to{$tagtype}{$tagid}{$tag_lc})) {
			# we have a translation for the tag language
			# print STDERR "display_taxonomy_tag - translation for the tag language - translations_to{$tagtype}{$tagid}{$tag_lc} : $translations_to{$tagtype}{$tagid}{$tag_lc}\n";			
			if ($tag_lc eq 'en') {
				# for English, use English tag without prefix as it will be recognized
				$display = $translations_to{$tagtype}{$tagid}{$tag_lc};
			}
			else {
				$display = "$tag_lc:" . $translations_to{$tagtype}{$tagid}{$tag_lc};
			}
		}
		else {
			$display = $tag;
			$display = ucfirst($display);			
			if ($target_lc ne $tag_lc) {
				$display = "$tag_lc:$display";
			}
			# print STDERR "display_taxonomy_tag - no translation available for $tagtype $tagid in target language $lc or tag language $tag_lc - result: $display\n";						
		}
	}
	
	# for additives, add the first synonym
	if ($tagtype =~ /^additives/) {
		$tagid =~ s/.*://;
		if ((defined $synonyms_for{$tagtype}{$target_lc}) and (defined $synonyms_for{$tagtype}{$target_lc}{$tagid})
			and (defined $synonyms_for{$tagtype}{$target_lc}{$tagid}[1])) {
				$display .= " - " . ucfirst($synonyms_for{$tagtype}{$target_lc}{$tagid}[1]);
		}
	}
	
	return $display;
	
}



sub canonicalize_tag_link($$)
{
	my $tagtype = shift;
	my $tagid = shift;
	
	if (defined $taxonomy_fields{$tagtype}) {
		die "ERROR: canonicalize_tag_link called for a taxonomy tagtype: $tagtype - tagid: $tagid - $!";
	}
	
	my $tag_lc = $lc;
	
	if ($tagtype eq 'missions') {
		if ($tagid =~ /\./) {
			$tag_lc = $`;
			$tagid = $';			
		}
	}
	
	# Redirect photographers, informers, correctors, checkers to users page
	if (($tagtype eq 'photographers') or ($tagtype eq 'informers')
		or ($tagtype eq 'correctors') or ($tagtype eq 'checkers')) {
		
		$tagtype = 'users';
	}
		
		
	my $path = $tag_type_singular{$tagtype}{$lang};
	if (not defined $path) {
		$path = $tag_type_singular{$tagtype}{en};
	}
	
	
	my $link = "/$path/" . URI::Escape::XS::encodeURIComponent($tagid);
	
	#if ($tag_lc ne $lc) {
	#	my $test = '';
	#	if ($data_root =~ /-test/) {
	#		$test = "-test";
	#	}
	#	$link = "http://" . $tag_lc . $test . "." . $server_domain . $link;
	#}	
	
	#print STDERR "tagtype: $tagtype - $lc: $lc - lang: $lang - link: $link\n";
	
	return $link;
	
}


sub export_tags_hierarchy($$) {
	my $lc = shift;
	my $tagtype = shift;
	
	# GEXF graph file (gephi, sigma.js etc.)
	# GraphViz dot file / png / svg
	
	my $gexf_example = <<GEXF
<?xml version="1.0" encoding="UTF-8"?>
<gexf xmlns="http://www.gexf.net/1.2draft" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.gexf.net/1.1draft http://www.gexf.net/1.2draft/gexf.xsd" version="1.2">
    <graph>
        <nodes>
            <node id="a" label="cheese"/>
            <node id="b" label="cherry"/>
            <node id="c" label="cake">
                <parents>
                    <parent for="a"/>
                    <parent for="b"/>
                </parents>
            </node>
        </nodes>
		
		<edges>
            <edge id="0" source="0" target="1" />
        </edges>		
		
    </graph>
</gexf>
GEXF
;

	my $gexf = <<GEXF
<?xml version="1.0" encoding="UTF-8"?>
<gexf xmlns="http://www.gexf.net/1.2draft" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.gexf.net/1.1draft http://www.gexf.net/1.2draft/gexf.xsd" version="1.2">
    <graph>
        <nodes>
GEXF
;		
	my $edges = '';
	
	my $graph = GraphViz2->new(
		edge => { color => 'grey' },
		global => { directed => 1 },
		node => { shape => 'oval' },
	);
	
	if ((defined $tags_level{$lc}) and (defined $tags_level{$lc}{$tagtype})) {
	
		foreach my $tagid (keys %{$tags_level{$lc}{$tagtype}}) {
		
			$gexf .= "\t\t\t" . "<node id=\"$tagid\" label=\"" . canonicalize_tag2($tagtype, $tagid) . "\" ";
		
			$graph->add_node(name=>$tagid, label => canonicalize_tag2($tagtype, $tagid), URL => "http://$lc.openfoodfacts.org/" . $tag_type_singular{$tagtype}{$lc} . "/" . $tagid);
		
			if (defined $tags_direct_parents{$lc}{$tagtype}{$tagid}) {
				$gexf .= ">\n";
				$gexf .= "\t\t\t\t<parents>\n";
				foreach my $parentid (sort keys %{$tags_direct_parents{$lc}{$tagtype}{$tagid}}) {
					$gexf .= "\t\t\t\t\t<parent for=\"$parentid\"/>\n";
					$edges .= "\t\t\t<edge id=\"${parentid}_$tagid\" source=\"$parentid\" target=\"$tagid\" />\n";
					
					$graph->add_edge(from => $parentid, to => $tagid);
				}
				$gexf .= "\t\t\t\t<\/parents>\n" . "\t\t\t<\/node>\n";				
			}		
			else {
				$gexf .= "\/>\n";
			}
		}
	}	
	
	$gexf .= <<GEXF	
        </nodes>
		<edges>
			$edges
		</edges>
    </graph>
</gexf>
GEXF
;

	 # print STDERR "saving $www_root/data/$lc." . get_fileid(lang($tagtype . "_p")) . ".gexf" . "\n";
	 open (my $OUT, ">:encoding(UTF-8)", "$www_root/data/$lc." . get_fileid(lang($tagtype . "_p")) . ".gexf") or die("write error: $!\n");
	 print $OUT $gexf;
	 close $OUT;
	 
	 eval {
	 $graph-> run (format => 'svg', output_file => "$www_root/data/$lc." . get_fileid(lang($tagtype . "_p")) . ".svg");
	 };
	 eval {
	 $graph-> run (format => 'png', output_file => "$www_root/data/$lc." . get_fileid(lang($tagtype . "_p")) . ".png");
	 };
	
}





# Load cities for emb codes

$log->info("Loading cities for packaging codes") if $log->is_info();

# French departements

my %departements = ();

open (my $IN, "<:encoding(windows-1252)", "$data_root/emb_codes/france_departements.txt");
while (<$IN>) {
	chomp();
	my ($code, $dep) = split(/\t/);
	$departements{$code} = $dep;
}
close ($IN);


# France
# http://www.insee.fr/fr/methodes/nomenclatures/cog/telechargement/2012/txt/france2012.zip

	open ($IN, "<:encoding(windows-1252)", "$data_root/emb_codes/france2012.txt");

	my @th = split(/\t/, <$IN>);
	my %th = ();
	my $i = 0;
	foreach my $h (@th) {
		$th{$h} = $i;
		$i++;
	}
	
	while (<$IN>) {
		chomp();
		my @td = split(/\t/);
		
		my $dep = $td[$th{DEP}];
		if (length($dep) == 1) {
			$dep = '0' . $dep;
		}
		my $com = $td[$th{COM}];
		if (length($com) == 1) {
			$com = '0' . $com;
		}
		if ((length($dep) == 2) and (length($com) == 2)) {
			$com = '0' . $com;
		}
		
		$emb_codes_cities{'FREMB' . $dep . $com } = $td[$th{NCCENR}] . " ($departements{$dep}, France)";
		#print STDERR 'FR' . $dep . $com. ' =  ' . $td[$th{NCCENR}] . " ($departements{$dep}, France)\n";
		
		$cities{get_fileid($td[$th{NCCENR}] . " ($departements{$dep}, France)")} = $td[$th{NCCENR}] . " ($departements{$dep}, France)";
	}
	close($IN);

	open($IN, "<:encoding(windows-1252)", "$data_root/emb_codes/insee.csv");
	while (<$IN>) {
		chomp();
		my @td = split(/;/);
		my $postal_code = $td[1];
		my $insee = $td[3];
		$insee =~ s/(\r|\n)+$//;
		if (length($insee) == 4) {
			$insee = '0' . $insee;
		}
		if (defined $emb_codes_cities{'FREMB' . $insee}) {
			$emb_codes_cities{'FR' . $postal_code} = $emb_codes_cities{'FREMB' . $insee};  # not used...
		}
	}
	close($IN);
	
	# geo coordinates
	
	my @geofiles = ("villes-geo-france-galichon-20130208.csv", "villes-geo-france-complement.csv");
	

	foreach my $geofile (@geofiles) {
	
	print "Tags.pm - loading geofile $geofile\n";
		open (my $IN, "<:encoding(UTF-8)", "$data_root/emb_codes/$geofile");

		my @th = split(/\t/, <$IN>);
		my %th = ();
		
		my $i = 0;

		foreach my $h (@th) {
			$h =~ s/^\s+//;
			$h =~ s/\s+$//;
			$th{$h} = $i;
			$i++;
		}
		
		my $j = 0;
		while (<$IN>) {
			chomp();
			my @td = split(/\t/);
			
			my $insee = $td[$th{"Code INSEE"}];
			if (length($insee) == 4) {
				$insee = '0' . $insee;
			}		
			
			($td[$th{"Latitude"}] == 0) and $td[$th{"Latitude"}] = 0;  # - => 0
			($td[$th{"Longitude"}] == 0) and $td[$th{"Longitude"}] = 0;
			$emb_codes_geo{'FREMB' . $insee } = [$td[$th{"Latitude"}] , $td[$th{"Longitude"}]];
			
			$j++;
			# ($j < 10) and print STDERR "Tags.pm - geo - map - emb_codes_geo: FREMB$insee =  " . $td[$th{"Latitude"}] . " , " . $td[$th{"Longitude"}]. " \n";						

		}
		close($IN);
	}
	
	# print STDERR "Tags.pm - map - emb_codes_geo total: " . (scalar keys %emb_codes_geo) . "\n";				


# nutrient levels
 
foreach my $l (@Langs) {

	$lc = $l;
	$lang = $l;
	
	foreach my $nutrient_level_ref (@nutrient_levels) {
		my ($nid, $low, $high) = @$nutrient_level_ref;

		foreach my $level ('low', 'moderate', 'high') {
			my $fmt = lang("nutrient_in_quantity");
			my $nutrient_name = $Nutriments{$nid}{$lc};
			my $level_quantity = lang($level . "_quantity");
			if ((not defined $fmt) or (not defined $nutrient_name) or (not defined $level_quantity)) {
				next;
			}
			
			my $tag = sprintf($fmt, $nutrient_name, $level_quantity);
			my $tagid = get_fileid($tag);
			$canon_tags{$lc}{nutrient_levels}{$tagid} = $tag;
			# print "nutrient_levels : lc: $lc - tagid: $tagid - tag: $tag\n";
		}
	}
}

# load all tags texts

$log->info("loading tags texts") if $log->is_info();
opendir DH2, "$data_root/lang" or die "Couldn't open $data_root/lang : $!";
foreach my $langid (readdir(DH2)) {
	next if $langid eq '.';
	next if $langid eq '..';
	
	# print STDERR "Tags.pm - reading texts for lang $langid\n";
	next if ((length($langid) ne 2) and not ($langid eq 'other'));

	my $lc = $langid;
	
	defined $tags_texts{$lc} or $tags_texts{$lc} = {};
	defined $tags_levels{$lc} or $tags_levels{$lc} = {};		
	
	if (-e "$data_root/lang/$langid") {
		foreach my $tagtype (sort keys %tag_type_singular) {
		
			defined $tags_texts{$lc}{$tagtype} or $tags_texts{$lc}{$tagtype} = {};	
			defined $tags_levels{$lc}{$tagtype} or $tags_levels{$lc}{$tagtype} = {};		
		
			if (-e "$data_root/lang/$langid/$tagtype") {
				opendir DH, "$data_root/lang/$langid/$tagtype" or die "Couldn't open the current directory: $!";
				foreach my $file (readdir(DH)) {
					next if $file !~ /(.*)\.html/;
					my $tagid = $1;
					open(my $IN, "<:encoding(UTF-8)", "$data_root/lang/$langid/$tagtype/$file") or $log->error("cannot open file", { path => "$data_root/lang/$langid/$tagtype/$file", error => $! });

					my $text = join("",(<$IN>));
					close $IN;
					if ($text =~ /class="level_(\d+)"/) {
						$tags_levels{$lc}{$tagtype}{$tagid} = $1;
					}
					$text =~  s/class="(\w+)_level_(\d)"/class="$1_level_$2 level_$2"/g;
					$tags_texts{$lc}{$tagtype}{$tagid} = $text;
					
				}		
				closedir(DH);
			}
		}
	}
}
closedir(DH2);
	
	
sub compute_field_tags($$) {

	my $product_ref = shift;
	my $field = shift;
	
	# tags fields without hierarchy or taxonomy
	
	if (defined $tags_fields{$field}) {

		$product_ref->{$field . "_tags" } = [];
		if ($field eq 'emb_codes') {
			$product_ref->{"cities_tags" } = [];
		}
		foreach my $tag (split(',', $product_ref->{$field} )) {
			if (get_fileid($tag) ne '') {
				push @{$product_ref->{$field . "_tags" }}, get_fileid($tag);
				if ($field eq 'emb_codes') {
					my $city_code = get_city_code($tag);
					if (defined $emb_codes_cities{$city_code}) {
						push @{$product_ref->{"cities_tags" }}, get_fileid($emb_codes_cities{$city_code}) ;
					}
				}
			}
		}			
	}	
	
	# generate the hierarchy of tags from the field values
				
	if (defined $taxonomy_fields{$field}) {
		$product_ref->{$field . "_hierarchy" } = [ gen_tags_hierarchy_taxonomy($lc, $field, $product_ref->{$field}) ];
		$product_ref->{$field . "_tags" } = [];
		foreach my $tag (@{$product_ref->{$field . "_hierarchy" }}) {
			push @{$product_ref->{$field . "_tags" }}, get_taxonomyid($tag);
		}
	}		
	elsif (defined $hierarchy_fields{$field}) {
		$product_ref->{$field . "_hierarchy" } = [ gen_tags_hierarchy($field, $product_ref->{$field}) ];
		$product_ref->{$field . "_tags" } = [];
		foreach my $tag (@{$product_ref->{$field . "_hierarchy" }}) {
			if (get_fileid($tag) ne '') {
				push @{$product_ref->{$field . "_tags" }}, get_fileid($tag);
			}
		}
	}
	
	# special handling for allergens and traces: 
	# the allergens_tags and traces_tags fields will be overwritten by Ingredients::detect_allergens_from_text
	# regenerate allergens and traces from the allergens_tags field so that it is prefixed with the values in the
	# main language of the product (which may be different than the $lc language of the interface)
	
	if (($field eq 'allergens') or ($field eq 'traces')) {
		$product_ref->{$field . "_from_user"} = "($lc)" . $product_ref->{$field};
		$product_ref->{$field} = join(',', @{$product_ref->{$field . "_hierarchy" }});
	}
	
	# check if we have a previous or a next version and compute differences
	
	$product_ref->{$field . "_debug_tags"} = [];
	
	# previous version
	
	if (exists $loaded_taxonomies{$field . "_prev"}) {
		$product_ref->{$field . "_prev_hierarchy" } = [ gen_tags_hierarchy_taxonomy($lc, $field . "_prev", $product_ref->{$field}) ];
		$product_ref->{$field . "_prev_tags" } = [];
		foreach my $tag (@{$product_ref->{$field . "_prev_hierarchy" }}) {
			push @{$product_ref->{$field . "_prev_tags" }}, get_taxonomyid($tag);
		}
		
		# compute differences
		foreach my $tag (@{$product_ref->{$field . "_tags"}}) {
			if (not has_tag($product_ref,$field . "_prev",$tag)) {
				my $tagid = $tag;
				$tagid =~ s/:/-/;
				push @{$product_ref->{$field . "_debug_tags"}}, "added-$tagid";
			}
		}
		foreach my $tag (@{$product_ref->{$field . "_prev_tags"}}) {
			if (not has_tag($product_ref,$field,$tag)) {
				my $tagid = $tag;
				$tagid =~ s/:/-/;
				push @{$product_ref->{$field . "_debug_tags"}}, "removed-$tagid";
			}
		}			
	}
	else {
		delete $product_ref->{$field . "_prev_hierarchy" };
		delete $product_ref->{$field . "_prev_tags" };
	}	
	
	# next version
	
	if (exists $loaded_taxonomies{$field . "_next"}) {
		$product_ref->{$field . "_next_hierarchy" } = [ gen_tags_hierarchy_taxonomy($lc, $field . "_next", $product_ref->{$field}) ];
		$product_ref->{$field . "_next_tags" } = [];
		foreach my $tag (@{$product_ref->{$field . "_next_hierarchy" }}) {
			push @{$product_ref->{$field . "_next_tags" }}, get_taxonomyid($tag);
		}
		
		# compute differences
		foreach my $tag (@{$product_ref->{$field . "_tags"}}) {
			if (not has_tag($product_ref,$field . "_next",$tag)) {
				my $tagid = $tag;
				$tagid =~ s/:/-/;
				push @{$product_ref->{$field . "_debug_tags"}}, "will-remove-$tagid";
			}
		}
		foreach my $tag (@{$product_ref->{$field . "_next_tags"}}) {
			if (not has_tag($product_ref,$field,$tag)) {
				my $tagid = $tag;
				$tagid =~ s/:/-/;
				push @{$product_ref->{$field . "_debug_tags"}}, "will-add-$tagid";
			}
		}			
	}
	else {
		delete $product_ref->{$field . "_next_hierarchy" };
		delete $product_ref->{$field . "_next_tags" };
	}
	
}


$log->info("Tags.pm loaded") if $log->is_info();
	
1;
