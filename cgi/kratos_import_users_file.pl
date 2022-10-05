#!/usr/bin/perl -w

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

use Modern::Perl '2017';
use utf8;

use ProductOpener::Users qw/:all/;
use ProductOpener::Config qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Text qw/:all/;

use Storable qw(store retrieve freeze thaw dclone);

use LWP::UserAgent;
use JSON;
use Log::Any qw($log);
use CGI qw(:standard);

#get all users files and put in array
my $dir = "$data_root/users/";
opendir DIR,$dir;
my @dir = readdir(DIR);
close DIR;
# $log->debug(@dir)

#open or create users.txt to write
open (my $fh, ">", "users.txt");

#for each in array open user file
for my $el (@dir){
    $log->debug($el, "\n");

    #if string does not contain .sto or only contains sto next iteration
    if (($el !~ /.sto/) or ($el eq ".sto")){
        next;
    }  

    #open user file
    my $user_file = "$data_root/users/" . $el;
    my $user_ref = retrieve($user_file);

    #get user info from sto file
    my $userid = $user_ref->{userid};
    my $email = $user_ref->{email};
    my $name = $user_ref->{name};
    my $display_barcode = $user_ref->{display_barcode};
    my $edit_link = $user_ref->{display_barcode};
    my $newsletter = $user_ref->{newsletter};
    my $pro_account = $user_ref->{pro_id};
    my $password = $user_ref->{encrypted_password};

    next if($password eq "");

    # SCRYPT:16384:8:1:3DVFqZOg9pBNzFbQz4WKoX0oBevSIJijWey1OAi824g=:if6QtOUcX7TcbRmLxONgm+a8o4A5+j3swcPLi74bMok=
    # to 
    # $scrypt$ln=16384,r=8,p=1$3DVFqZOg9pBNzFbQz4WKoX0oBevSIJijWey1OAi824g=$if6QtOUcX7TcbRmLxONgm+a8o4A5+j3swcPLi74bMok=
    my @spl = split(':', $password);
    my $kratos_password ="\$scrypt\$ln=$spl[1],r=$spl[2],p=$spl[3]\$$spl[4]\$$spl[5]"; 

    #create json to post
    my $post_json = JSON->new;

    my $data_to_json = {
        'credentials' => {
            'password' => {
                'config' => {
                    'password' => $kratos_password
                }
            }
        },
        'traits' => {
            'UserID' => $userid,
            'email' => $email,
            'name' => $name
        }
    };
    $log->debug("pro_account: ", $pro_account);


    if($pro_account ne ""){
        $data_to_json->{traits}{professional_account} = $pro_account;
    }

    if($display_barcode ne ""){
        $data_to_json->{traits}{"Display Barcode"} = JSON::true;
    }

    if($edit_link ne ""){
        $data_to_json->{traits}{"Add Edit Link"} = JSON::true;
    }

    if($newsletter ne ""){
        $data_to_json->{traits}{"newsletter"} = JSON::true;
    }

    my $str = encode_json($data_to_json);

    $log->debug("json: ", $str);
    
    #print json to line with new line
    print $fh $str;
    print $fh "\n";
}
close $fh;