#!/usr/bin/perl -w

# This file is part of Product Opener.
# 
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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

use Locale::PO;
use Encode;


defined $ARGV[0] or die "Usage: po2jqueryi18n [.po file]\n";

foreach my $file (@ARGV) {

	next if $file !~ /\.po$/;

	my $aref = Locale::PO->load_file_asarray($file, "UTF-8");
	
	my $lang = $file;
	$lang =~ s/^(.*)-//;
	$lang =~ s/\.po//;
	
	my $json_file = "i18n-$lang.json";
	
	my $lc = $lang;
	$lc =~ s/_.*/\n/;
	
	print "converting $file to $json_file - lang: $lang lc: $lc\n";
	
	open (my $OUT, ">:encoding(UTF-8)", $json_file);

	my $json = "{\n";
	
	foreach my $ref (@{$aref}) {

		next if not defined $ref->{reference};
		
		# bogus example entry
		# $1 has $2 {{plural:$2|kitten|kittens}}. {{gender:$3|He|She}} loves to play with {{plural:$2|it|them}}.
		next if $ref->{reference} =~ /kittens/;
		
		my $msgstr = Encode::decode_utf8($ref->{msgstr});
		$msgstr =~ s/=http/=\\\"http/g;
		$msgstr =~ s/ target=_blank/\\\" target=\\\"_blank\\\"/;
		$msgstr =~ s/<img src=openfoodfacts-logo-(.+).png alt=Open Food Facts/<img src=\\\"openfoodfacts-logo-$lang.png\\\" alt=\\\"Open Food Facts\\\"/;
		$json .= "\t\"msg_" . $ref->{reference} . "\" : $msgstr,\n";
	}
	
	$json =~ s/,\n$//;
	
	$json .= "\n}\n";
	
	# change old en.openfoodfacts.org urls
	$json =~ s/en.openfoodfacts.org/world-$lc.openfoodfacts.org/g;

	print $OUT $json;

	close($OUT);
}
