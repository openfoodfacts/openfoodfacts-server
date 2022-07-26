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

#Retrieve ory_kratos_session cookie 
my $kratos_cookie = "ory_kratos_session=".cookie('ory_kratos_session');
$log->debug($kratos_cookie);

if(defined $kratos_cookie){
    my $url = "http://kratos.openfoodfacts.localhost:4433/sessions/whoami";

    my $ua = LWP::UserAgent->new;

    # set custom HTTP request header fields, must include cookie for /session/whoami
    my $req = HTTP::Request->new(GET => $url);
    $req->header('content-type' => 'application/json');
    $req->header('Cookie' => $kratos_cookie);

    my $resp = $ua->request($req);

    if ($resp->is_success) {
        #decode json to a hash
        my $json = $resp->decoded_content;
        my $content_ref = decode_json($json);

        #get user info from kratos json hash
        my $UserID = $content_ref->{identity}{traits}{UserID};
        my $name_kratos = $content_ref->{identity}{traits}{name};
        my $email_kratos = $content_ref->{identity}{traits}{email};
        my $newsletter_kratos = $content_ref->{identity}{traits}{newsletter};
        my $edit_link_kratos = $content_ref->{identity}{traits}{"Add Edit Link"};
        my $display_barcode_kratos = $content_ref->{identity}{traits}{"Display Barcode"};
        my $team_1_kratos = $content_ref->{identity}{traits}{Teams}{"Team 1"};
        my $team_2_kratos = $content_ref->{identity}{traits}{Teams}{"Team 2"};
        my $team_3_kratos = $content_ref->{identity}{traits}{Teams}{"Team 3"};

        #retrieve users storable file
        my $user_file = "$data_root/users/" . get_string_id_for_lang("no_language", $UserID) . ".sto";
        my $user_ref = retrieve($user_file);

        $user_ref->{userid} => $UserID;
        $user_ref->{email} => $email_kratos;
        $user_ref->{name} => $name_kratos;

        #updating users info
        if($newsletter_kratos == 0){
            $user_ref->{newsletter} = '';
        }
        else{
            $user_ref->{newsletter} = 'on';
        }

        if($edit_link_kratos == 0){
            $user_ref->{edit_link} = '';
        }
        else{
            delete $user_ref->{edit_link};
        }

        if($display_barcode_kratos == 0){
            $user_ref->{display_barcode} = '';
        }
        else{
            delete $user_ref->{display_barcode};
        }

        if($team_1_kratos eq ''){
            $user_ref->{team_1} = '';
        }
        else{
            $user_ref->{team_1} = $team_1_kratos;
        }

        if($team_2_kratos eq ''){
            $user_ref->{team_2} = '';
        }
        else{
            $user_ref->{team_2} = $team_2_kratos;
        }

        if($team_3_kratos eq ''){
            $user_ref->{team_3} = '';
        }
        else{
            $user_ref->{team_3} = $team_3_kratos;
        }

        #store the updated sto file
        store($user_ref, $user_file);
    }
    else {
        $log->debug("HTTP GET error code: ", $resp->code, "n");
        $log->debug("HTTP GET error message: ", $resp->message, "n");
    }
}