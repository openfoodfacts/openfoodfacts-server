#!/usr/bin/perl

use Modern::Perl '2012';
use utf8;

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:cgi :form escapeHTML/;
use Encode;
use JSON::PP;

my $debug = 0;

my $code = decode utf8=>param('code');
my $product = decode utf8=>param('product');
my $name = decode utf8=>param('name');
my $answer = decode utf8=>param('answer');
my $actual = decode utf8=>param('actual');
my $points = decode utf8=>param('points');

open (my $OUT, ">>" , "/home/sugar/logs/sugar_log");
print $OUT remote_addr() . "\t" . time() . "\t" . $product . "\t" . $code . "\t" . $actual . "\t" . $answer . "\t" . $points . "\n";
close $OUT;


print "Content-Type: text/html; charset=UTF-8\r\n\r\n";
