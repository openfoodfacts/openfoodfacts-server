#!/usr/bin/perl -w

# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2023 Association Open Food Facts
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

=head1 NAME

generate_perl_html_doc_from_pod.pl scans the Perl source code of Product Opener
for documentation in POD format to generate documentation in HTML files.

=head1 SYNOPSIS

The script needs to be run from the root of the Product Opener installation
(e.g. /srv/off/)

    ./scripts/generate_perl_html_doc_from_pod.pl

=cut

use Modern::Perl '2017';
use utf8;

use Pod::Simple::HTMLBatch;

my $batchconv = Pod::Simple::HTMLBatch->new;

$batchconv->add_css("simple.min.css");
$batchconv->contents_page_start('
<html>
<head>
<title>Product Opener Perl Documentation</title>
</head>
<body class="contentspage">
<h1>Product Opener Perl Documentation</h1>
<p><a href="https://github.com/openfoodfacts/openfoodfacts-server">github repository</a></p>
');
$batchconv->css_flurry(0);
$batchconv->javascript_flurry(0);
$batchconv->batch_convert(["cgi", "scripts", "lib"], "html/files/doc/perl");
