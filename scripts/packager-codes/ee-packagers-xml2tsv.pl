#!/usr/bin/env perl
# ee-packagers-xml2tsv.pl

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2020 Association Open Food Facts
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

use v5.12;
use utf8;
use strict;
use warnings;
use warnings qw(FATAL utf8);
use open qw(:std :utf8);
use charnames qw(:full :short);

use LWP::Simple qw(get);
use XML::LibXML;
use XML::LibXSLT;
use Geo::Coder::Google v0.19.100;

my $APIKEY = undef;

# From load_xml() documentation:
# "Note that, due to a limitation in the underlying libxml2 library,
# this call does not recognize HTTPS-based URLs.
# (It will treat an HTTPS URL as a filename,
# likely throwing a "No such file or directory" exception.)"
# So we use LWP for downloading.
my $xml_doc
	= get
	'https://agri.ee/sites/default/files/opendata/toit/Toidukaitlejad.xml'
	or die "Error: Unable to get XML file.";

my $dom_ref
	= XML::LibXML->load_xml( string => ( \$xml_doc ), no_blanks => 1 );

foreach my $row_ref ( $dom_ref->findnodes('/v_toidukaitleja_avaandmed/row') )
{
	$row_ref->addNewChild( undef, 'lat' );
	$row_ref->addNewChild( undef, 'lng' );
}

# tunnustatud = approved
# tunnusnumber = approval number
my $approved_xpath_ref
	= XML::LibXML::XPathExpression->new(
	'//row[ tunnustatud = "true" and ./tunnusnumber/node() and ./tunnusnumber != "----" ]'
	);
my @approved_establs = $dom_ref->findnodes($approved_xpath_ref);

my $geocoder_ref = undef;
if ($APIKEY) {
	$geocoder_ref = Geo::Coder::Google->new(
		apikey => $APIKEY,
		host   => 'maps.google.ee',
		region => 'ee'
	);
}

if ($geocoder_ref) {
	foreach my $approved_establ_ref (@approved_establs) {
		my $address
			= $approved_establ_ref->findvalue('./tegevuskoha_aadress');
		my ($lat_node_ref) = $approved_establ_ref->findnodes('./lat[1]');
		my ($lng_node_ref) = $approved_establ_ref->findnodes('./lng[1]');
		next
			unless my $location_ref
			= $geocoder_ref->geocode( location => $address );
		$lat_node_ref->appendText( $location_ref->{geometry}{location}{lat} );
		$lng_node_ref->appendText( $location_ref->{geometry}{location}{lng} );
	}
}

my $xslt_ref      = XML::LibXSLT->new();
my $style_doc_ref = XML::LibXML->load_xml(
	location => 'toidukaitlejad-tsv.xsl',
	no_cdata => 1
);
my $stylesheet_ref = $xslt_ref->parse_stylesheet($style_doc_ref);

my $tsv_ref = $stylesheet_ref->transform($dom_ref);

$stylesheet_ref->output_file( $tsv_ref, 'EE-merge-UTF-8.tsv' );
