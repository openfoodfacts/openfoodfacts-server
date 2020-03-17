#!/usr/bin/perl -w

=head1 NAME

generate_perl_html_doc_from_pod.pl scans the Perl source code of Product Opener
for documentation in POD format to generate documentation in HTML files.

=head1 SYNOPSYS

The script needs to be run from the root of the Product Opener installation
(e.g. /srv/off/)

    ./scripts/generate_perl_html_doc_from_pod.pl

=cut

use Pod::Simple::HTMLBatch;

my $batchconv = Pod::Simple::HTMLBatch->new;

$batchconv->batch_convert( ["cgi", "scripts", "lib"] , "html/files/doc/perl");
