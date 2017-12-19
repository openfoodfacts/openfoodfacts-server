package ProductOpener::Missions;

######################################################################
#
#	Package	Missions
#
#	Author:	Stephane Gigandet
#	Date:	05/04/12
#
######################################################################

use utf8;
use Modern::Perl '2012';
use Exporter    qw< import >;

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(
			&gen_missions_html
			&compute_missions
			&compute_missions_for_user
					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Store qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::MissionsConfig qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Tags qw/:all/;
use MongoDB;
use Tie::IxHash;


sub gen_missions_html() {

	my $missions_ref = retrieve("$data_root/missions.sto");
		
	foreach my $l (keys %Missions_by_lang) {
	
		$lang = $l;
	
		my $html = '<ul id="missions" style="list-style-type:none">';
	
		foreach my $mission_ref (@{$Missions_by_lang{$l}}) {
			my $n = 0;
			my $missionid = $mission_ref->{id};
			if (defined $missions_ref->{$missionid}) {
				$n = scalar keys %{$missions_ref->{$missionid}};
			}
			my $n_persons = '';
			if ($n > 0) {
				$n_persons = " &rarr; <a href=\"" . canonicalize_tag_link("missions", $missionid ) . "\" style=\"font-size:0.9em\">" . sprintf($Lang{mission_accomplished_by_n}{$lang}, $n) . "</a>";
				if ($n == 1) {
					$n_persons =~ s/s\.</.</;
				}
			}
			
			$html .=  "<li style=\"margin-bottom:10px;\"><img src=\"/images/misc/gold-star-32.png\" alt=\"Star\" style=\"float:left;margin-top:5px;margin-right:20px;\"/> <div>"
			. "<a href=\"" . canonicalize_tag_link("missions", $missionid) . "\" style=\"font-size:1.4em\">"
						. $Missions{$missionid}{name} . "</a><br/>" . $Missions{$missionid}{goal} . $n_persons . "</div></li>\n";
						
			# Generate mission page
			my $html2 = "<h1>$Missions{$missionid}{name}</h1>\n";
			
			if (defined $Missions{$missionid}{image}) {
				$html2 .= "<img id=\"og_image\" src=\"/images/misc/$Missions{$missionid}{image}\" alt=\"$Missions{$missionid}{name}\" style=\"float:left;margin-right:20px;margin-bottom:20px;\" />\n";
			}
			
			$html2 .= "<p id=\"description\"><b>$Lang{mission_goal}{$lang}</b> " . $Missions{$missionid}{goal} . "</p>";
			if (defined $Missions{$missionid}{description}) {
				$html2 .= "<p>$Missions{$missionid}{description}</p>";
			}
			if ($n == 0) {
				$html2 .= "<p>$Lang{mission_accomplished_by_nobody}{$lang}</p>";
			}
			elsif ($n > 0) {
				$html2 .= "<p>$Lang{mission_accomplished_by}{$lang}</p>";
				foreach my $userid (sort {$missions_ref->{$missionid}{$a} <=> $missions_ref->{$missionid}{$b} } keys %{$missions_ref->{$missionid}}) {
					$html2 .= "<a href=\"" . canonicalize_tag_link("users", get_fileid($userid)) . "\">$userid</a>, ";
				}
				$html2 =~ s/, $//;
			}
			
			if (defined $Missions{$missionid}{image_legend}) {
				$html2 .= "<p>$Missions{$missionid}{image_legend}</p>\n";
			}			
			
			$html2 .= "<p>&rarr; <a href=\"/" . get_fileid(lang("missions")) . "\">$Lang{all_missions}{$lang}</a></p>";			
			
			$missionid =~ s/(.*)\.//;
			(-e "$data_root/lang/$lang/missions") or mkdir("$data_root/lang/$lang/missions", 0755);
			open (my $OUT, ">:encoding(UTF-8)", "$data_root/lang/$lang/missions/$missionid.html");
			print $OUT $html2;
			close $OUT;			
		}
		
		$html .= "</ul>";
		
		 open (my $OUT, ">:encoding(UTF-8)", "$data_root/lang/$lang/texts/missions_list.html");
		 print $OUT $html;
		 close $OUT;	
	}
}


sub compute_missions() {

	opendir DH, "$data_root/users" or die "Couldn't open the current directory: $!";
	my @userids = sort(readdir(DH));
	closedir(DH);

	my $missions_ref = {};
	
	foreach my $userid (@userids)
	{
		next if $userid eq "." or $userid eq "..";
		next if $userid eq 'all';

		print STDERR "userid: $userid\n";

		
		$userid =~ s/\.sto$//;
		
		print STDERR "userid: $userid\n";

		my $user_ref = retrieve("$data_root/users/$userid.sto");
		
		compute_missions_for_user($user_ref);
		
		store("$data_root/users/$userid.sto", $user_ref);
		
		foreach my $missionid (keys %{$user_ref->{missions}}) {
			(defined $missions_ref->{$missionid}) or $missions_ref->{$missionid} = {};
			$missions_ref->{$missionid}{$userid} = $user_ref->{missions}{$missionid};
		}
	}

	store("$data_root/missions.sto", $missions_ref);
}


sub compute_missions_for_user($) {

	my $user_ref = shift;
	defined $user_ref->{missions} or $user_ref->{missions} = {};
	$user_ref->{missions} = {};
	
	my $m = 0;
	
	foreach my $l (keys %Missions_by_lang) {
	
		foreach my $mission_ref (@{$Missions_by_lang{$l}}) {
		
			# skip missions already complete
			next if (defined $user_ref->{missions}{$mission_ref->{id}});
			
			print STDERR "compute_missions: user_id: " . $user_ref->{userid} . " mission: $mission_ref->{id} ?\n";

			
			# {name=>'Serrés comme des sardines', description=>'Ajouter 2 boîtes de sardines en conserve', thanks=>'Merci pour les sardines !',
			# conditions=>[[2,{categories_tags=>'sardines', packaging_tags=>'conserve'}]]},
		
			my $complete = 1;
			my $i = 0;
		
			foreach my $condition_ref (@{$mission_ref->{conditions}}) {
			
				use Clone qw(clone);
				my $query_ref = clone($condition_ref->[1]);
				$query_ref->{creator} = $user_ref->{userid};
				$query_ref->{lc} = $l;
				# $query_ref->{complete} = 1;
				
				foreach my $field (keys %$query_ref) {
					next if $field eq 'creator';
					if ($query_ref->{$field} eq '<userid>') {
						$query_ref->{$field} = $user_ref->{userid};
						delete $query_ref->{creator};
					}
					
					my $tagtype = $field;
					$tagtype =~ s/_tags$//;
					
					print "field: $field - tagtype: $tagtype\n";
					
					
					if (defined $taxonomy_fields{$tagtype}) {
						my $tag = $query_ref->{$field};
						$tag = canonicalize_taxonomy_tag($l,$tagtype, $tag);
						my $tagid = get_taxonomyid($tag);
						print "compute_missions - taxonomy - $field - orig: $query_ref->{$field} - new: $tagid\n";
						$query_ref->{$field} = $tagid;				
					}
				}
				
				
				print STDERR "compute_missions: querying condition $i\n";

				
				my $cursor = $products_collection->query($query_ref)->fields({});
				my $count = $cursor->count();
				
				if ($count < $condition_ref->[0]) {
					$complete = 0;
					last;
				}
				$i++;
			
			}
			
			if ($complete) {
				$user_ref->{missions}{$mission_ref->{id}} = time();
				print STDERR "compute_missions: user_id: " . $user_ref->{userid} . " mission: $mission_ref->{id} complete!\n";
				$m++;
				sleep(1);
			}
		
		}
	}
	
	return $m;

}


1;
