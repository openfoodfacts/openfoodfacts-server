#!/usr/bin/perl -w

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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

use Modern::Perl '2012';
use utf8;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Images qw/:all/;
use ProductOpener::Users qw/:all/;
use ProductOpener::Mail qw/:all/;
use ProductOpener::Lang qw/:all/;

use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Encode;

ProductOpener::Display::init();

my $type = param('type') || 'edit';
my $action = param('action') || 'display';

my $blogid = param('blogid');

if ((not defined $blogid) and (defined $User_id)) {
	$blogid = $User_id;
}

# Make sure we are passed a valid blogid (and not something like ../ etc.)
$blogid = get_fileid($blogid);

my $html = '';

my $blog_ref = {};
my $user_ref = {};

my $blogs_dir = 'blogs';

$blog_ref = retrieve("$data_root/index/$blogs_dir/$blogid/blog.sto");
if ((not defined $blog_ref) and (defined param('blogid'))) {
	display_error($Lang{error_invalid_blog}{$lang}, 404);
}

if ((not defined $blog_ref) and not (defined param('blogid'))) {
	$blog_ref = { blogid=>$blogid, userid=>$blogid, user_name=>$User{name}, title=>$User{name} };
}
not defined $blog_ref->{userid} and $blog_ref->{userid} = $User_id;

if (($type eq 'delete')  and not $admin) {
	display_error($Lang{error_no_permission}{$lang}, 403);
}

my $oldblogid = $blogid;
my $old_blog_ref = $blog_ref;
if (($admin) and ($type ne 'suggest') and (defined param('newblogid')) and (param('newblogid') =~ /^([a-z0-9-]+)$/)) {
	$old_blog_ref = retrieve("$data_root/index/$blogs_dir/$blogid/blog.sto");
	$blogid = param('newblogid');
}

if ($type eq 'edit') {
	# Check that only the owner is editing the blog
	if (not ($admin or ($User_id eq $blog_ref->{userid}))) {
		print STDERR "blog.pl - disallowed edit for user: $User_id, blog: $blogid, owner: $blog_ref->{userid}\n";
		display_error($Lang{error_signin_to_edit_your_blog}{$lang}, 403);
	}
}

print STDERR "blog.pl - type: $type - blogid: $blogid / $blog_ref->{blogid}\n";

my @errors = ();

if ($action eq 'process') {

	if (($type eq 'edit')) {
		if (param('delete') eq 'on') {
			if ($admin) {
				$type = 'delete';
			}
			else {
				display_error($Lang{error_no_permission}{$lang}, 403);
			}
		}
	}

	$blog_ref->{blogid} = $blogid;
	$blog_ref->{title} = remove_tags_and_quote(decode utf8=>param('title'));
	$blog_ref->{url} = remove_tags_and_quote(decode utf8=>param('url'));
	$blog_ref->{about} = remove_tags_except_links(decode utf8=>param('about'));
	$blog_ref->{localisation} = remove_tags_and_quote(decode utf8=>param('localisation'));
	$blog_ref->{banner_alt} = remove_tags_except_links(decode utf8=>param('banner_alt'));
	
	if ((length($blog_ref->{url}) > 5) and ($blog_ref->{url} !~ /^http/i)) {
		$blog_ref->{url} = "http://" . $blog_ref->{url};
	}
	
	$blog_ref->{color} = decode utf8=>param('color');
	
	if (defined param('banner_has_text')) {
		$blog_ref->{banner_has_text} = param('banner_has_text');
	}
	
	if ($admin) {
		delete $blog_ref->{manual_awards};
		if ((defined param('manual_awards')) and (param('manual_awards') ne '')) {
			$blog_ref->{manual_awards} = {};
			my $manual_awards = param('manual_awards');
			while ($manual_awards =~ /(\S*)\.(\S*)/) {
				$blog_ref->{manual_awards}{$1} = $2;
				$manual_awards = $';
			}
		}
	}
	
	# Check input parameters, redisplay if necessary
	print STDERR "blog.pl User_id: $User_id \n";

	
	if (length($blog_ref->{title}) < 3) {
		push @errors, $Lang{error_blog_title_too_short}{$lang};
	}
	
	if ($blog_ref->{blogid} !~ /^[a-z0-9]+[a-z0-9\-]*[a-z0-9]+$/) {
		push @errors, $Lang{error_invalid_blogid}{$lang};
	}
	
	if ($#errors >= 0) {
		$action = 'display';
	}	
}


if ($action eq 'display') {

	if (defined $Strings{"edit_profile_msg"}) {
		$html .= $Strings{"edit_profile_msg"};
	}
	
	$scripts .= <<SCRIPT
<script type="text/javascript" src="/js/mColorPicker_min.js"  charset="UTF-8"></script>
SCRIPT
;

	if ($#errors >= 0) {
		$html .= "<p><b>$Lang{correct_the_following_errors}{$lang}</b></p><ul>\n";
		foreach my $error (@errors) {
			$html .= "<li class=\"error\">$error</li>\n";
		}
		$html .= "</ul>\n";
	}
	
	$html .= start_multipart_form()
	. "<table class=\"form\">";
	
	if (not defined $User_id) {
		$html .= "<tr><td colspan=\"2\">$Lang{signin_before_submit}{$lang}</td></tr>\n";
		$html .= ProductOpener::Users::display_user_form($user_ref,\$scripts);
	}
	
	if (not defined $blog_ref->{title}) {
		$blog_ref->{title} = $User{name};
	}
	

	$html .= "\n<tr><td>$Lang{name}{$lang}</span></td><td>"
	. textfield(-name=>'title', -value=>$blog_ref->{title}, -size=>40, -override=>1) . "</td></tr>";
	
	if (($admin) and ($type ne 'suggest')) {
		$html .= "\n<tr><td>Changement d'identifiant (à éviter, sauf lors de la validation)</td><td>"
	. textfield(-name=>'newblogid', -value=>$blogid, -size=>40, -override=>1) . "</td></tr>";
	}
	
	
	$html .= "\n<tr><td>$Lang{website}{$lang}</td><td>"	
	. textfield(-name=>'url', -value=>$blog_ref->{url}, -size=>80, -override=>1) . "</td></tr>"
	. "\n<tr><td>$Lang{localisation}{$lang}</td><td>"	
	. textfield(-name=>'localisation', -value=>$blog_ref->{localisation}, -size=>80, -override=>1) . "</td></tr>"
	. "\n<tr><td colspan=\"2\">$Lang{about}{$lang}<br />"
	. textarea(-id=>'about', -name=>'about', -value=>$blog_ref->{about}, -cols=>80, -rows=>5, -override=>1) . "</td></tr>"
	."\n<tr><td>$Lang{banner_image}{$lang}<br><span class=\"info\">(minimum $banner_source_geometry pixels)</span></td><td>"
	. filefield(-id=>'banner', -name=>'banner') . "</td></tr>"
	. "\n<tr><td>$Lang{banner_alt}{$lang}</td><td>"	
	. textfield(-name=>'banner_alt', -value=>$blog_ref->{banner_alt}, -size=>80, -override=>1) . "</td></tr>"
	. "\n<tr><td>$Lang{banner_color}{$lang}</td><td>"
	. "<input type=\"color\" name=\"color\" id=\"color\" value=\"$blog_ref->{color}\" data-hex=\"true\" /></td></tr>"		
	;
	
	if ((not defined $User_id) ) {
		$html .= ProductOpener::Users::display_user_form_optional($user_ref);
	}
	
	if ($admin) {
		$html .= "\n<tr><td colspan=\"2\">" . checkbox(-name=>'delete', -label=>'Effacer le blog') . "</td></tr>";
		my $manual_awards = '';
		if (defined $blog_ref->{manual_awards}) {
			foreach my $award (keys %{$blog_ref->{manual_awards}}) {
				$manual_awards .= $award . "." . $blog_ref->{manual_awards}{$award} . " ";
			}
		}
		$html .= "\n<tr><td>Médailles</td><td>" . textfield(-id=>"manual_awards", -name=>"manual_awards", -value=>$manual_awards, -size=>120, -ovveride=>1) . "</td></tr>";
	}
	
	$html .= "\n<tr><td>"
	. hidden(-name=>'action', -value=>'process', -override=>1)
	. hidden(-name=>'type', -value=>$type, -override=>1)
	. hidden(-name=>'blogid', -value=>$blogid, -override=>1)
	. submit()
	. "</td></tr>\n</table>"
	. end_form();

}
elsif ($action eq 'process') {

	if ($type eq 'add') {
		mkdir("$data_root/index/blogs/$blogid", 0705);
		$blog_ref->{status} = 'ok';
		$type = 'edit';
	}
	elsif ($type eq 'edit') {
		$blog_ref->{edited_t} = time();
	}
	elsif ($type eq 'delete') {
		my $deleted_blogs_dir = "deleted-" . $blogs_dir;
		my $deleted_blogid = $blogid;
		my $i = 1;
		while (-e "$data_root/index/$deleted_blogs_dir/$deleted_blogid") {
			$i++;
			$deleted_blogid = $blogid . '.' . $i;
		}
		
		# Desindex all news
		
		if (-e "$data_root/index/blogs/$blogid/news") {
			opendir DH, "$data_root/index/blogs/$blogid/news" or die "Couldn't open $data_root/index/blogs/$blogid/news : $!";
			my @newsids = sort(readdir(DH));
			closedir(DH);
			
			foreach my $newsid (@newsids) {
				next if $newsid eq '.';
				next if $newsid eq '..';
				$newsid =~ s/\..*//; # remove .sto
				desindex_news($old_blog_ref, $newsid);
			}
		}
				
		$blog_ref->{status} = 'deleted';
		$blog_ref->{deleted_t} = time();
		store("$data_root/index/$blogs_dir/$blogid/blog.sto", $blog_ref);
		File::Copy::move("$data_root/index/$blogs_dir/$blogid", "$data_root/index/$deleted_blogs_dir/$deleted_blogid");
		File::Copy::move("$data_root/html/images/$blogid", "$data_root/index/$deleted_blogs_dir/$deleted_blogid/images");
		
	}

	
	# Update user
	
	my $userid = $blog_ref->{userid};
		
	$user_ref = retrieve("$data_root/users/$userid.sto");
	
	defined $user_ref->{blogs} or $user_ref->{blogs} = {};
	
	$user_ref->{blogs}{$blogid} = {
				title=>$blog_ref->{title},
				url=>$blog_ref->{url},
				status=>$blog_ref->{status},
	};
	
	if ($type eq 'delete') {
		delete $user_ref->{blogs}{$blogid};
	}
	
	
	# Change of blogid
	
	if (($type ne 'validate') and ($oldblogid ne $blogid)) {	
		delete $user_ref->{blogs}{$oldblogid};
		
		# Go through all the news, desindex them, move the files, then reindex them..
		
		print STDERR "blog.pl - move - reading newsids\n";
		
		opendir DH, "$data_root/index/blogs/$oldblogid/news" or die "Couldn't open $data_root/index/blogs/$oldblogid/news : $!";
		my @newsids = sort(readdir(DH));
		closedir(DH);
		
		print STDERR "blog.pl - move - desindexing news from $blog_ref->{blogid}\n";
		
		foreach my $newsid (@newsids) {
			next if $newsid eq '.';
			next if $newsid eq '..';
			$newsid =~ s/\..*//; # remove .sto
			print STDERR "blog.pl - move - desindexing blogid: $old_blog_ref->{blogid} news: $newsid\n";
			desindex_news($old_blog_ref, $newsid);
		}
		
		print STDERR "blog.pl - move - moving from $oldblogid to $blogid\n";
		
		File::Copy::move("$data_root/index/$blogs_dir/$oldblogid", "$data_root/index/$blogs_dir/$blogid");
		File::Copy::move("$data_root/html/images/blogs/$oldblogid", "$data_root/html/images/blogs/$blogid");		
		
		$blog_ref = retrieve("$data_root/index/$blogs_dir/$blogid/blog.sto");
		
		$blog_ref->{blogid} = $blogid;
		
		print STDERR "blog.pl - move - reindexing news to $blog_ref->{blogid}\n";
		
		foreach my $newsid (@newsids) {
			next if $newsid eq '.';
			next if $newsid eq '..';
			$newsid =~ s/\..*//; # remove .sto
			my $news_ref = retrieve("$data_root/index/blogs/$blogid/news/$newsid.sto");
			print STDERR "blog.pl - move -  indexing blogid: $blog_ref->{blogid} news: $newsid / $news_ref->{id} ($data_root/index/blogs/$blogid/news/$newsid/news.sto)\n";
			index_news($blog_ref, $news_ref);
		}		
		
		print STDERR "blog.pl - move - done\n";
	}
	
	store("$data_root/users/$userid.sto", $user_ref);
	

	if ($type ne 'delete') {
	
		# Uploaded banner?
		my $file = undef;
		if ($file = param("banner")) {
			if ($file =~ /\.(gif|jpeg|jpg|png)$/i) {
				my $extension = lc($1) ;
				my $filename = "banner_source";

				open (my $FILE, q{>}, "$data_root/index/$blogs_dir/$blogid/$filename.$extension") ;
				while (<$file>) {
					print $FILE;
				}
				close ($FILE);
				
				$blog_ref->{'banner_source'} = "index/$blogs_dir/$blogid/$filename.$extension";
			}
		}
		
		# Store before generating the banner, in case it fails...
		store("$data_root/index/$blogs_dir/$blogid/blog.sto", $blog_ref);
		
		generate_banner($blog_ref);
	
		store("$data_root/index/$blogs_dir/$blogid/blog.sto", $blog_ref);
		
		# update cache
		my $value_ref = {
						title => $blog_ref->{title},
						color => $blog_ref->{color2},
						url => $blog_ref->{url}
		};
		$memd->set("$server_domain/blogs/$blogid", $value_ref);
	}
	
	$html .= $Strings{$type . "_blog_confirm"};
	
	my $blog_title = $blog_ref->{title};
	$html =~ s/<BLOG_TITLE>/$blog_title/g;
	
	if ($type ne 'delete') {
		$html .= "<p>&rarr; <a href=\"/$by/$blogid\">$blog_ref->{title}</a></p>";
	}


}


my $display_blog_ref = undef;
if (($type eq 'edit') or ($type eq 'validate') or (($type eq 'process') and ($type ne 'delete'))) {
	$display_blog_ref = $blog_ref;
}

display_new( {
	blogid => $blogid,
	blog_ref=>$display_blog_ref,
	title=> $Strings{'edit_profile'},
	content_ref=>\$html,
	full_width=>1,
});

