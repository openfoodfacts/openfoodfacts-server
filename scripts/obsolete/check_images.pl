#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

 use Image::Magick;

 my $dir = $ARGV[0] or die "Usage: $0 directory\n";

 opendir my $dh, $dir or die "Could not open '$dir' for reading: $!\n";

 my @files = grep { /\.jpg$/ } sort readdir $dh;

 closedir $dh;

 my $images = Image::Magick->new;

 foreach my $file (@files) {
 	my $image = Image::Magick->new;
 		my $error = $image->Read("$dir/$file");
 			die "Could not read '$dir/$file': $error" if $error;
 				my ($width, $height) = $image->Get('width', 'height');
 					say "$file: $width x $height";
 					}



 					exit(0);
