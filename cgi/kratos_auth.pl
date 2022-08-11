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

use LWP::UserAgent;
use JSON;
use Log::Any qw($log);
use CGI qw(:standard);

use Storable qw(store retrieve freeze thaw dclone);


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
        my $professional_account_kratos = $content_ref->{identity}{traits}{"professional_account"};
        
        # $log->debug($json);
        # $log->debug("User ID: ", $UserID);
        # $log->debug("Email: ", $email_kratos);
        # $log->debug("newsletter: ", $newsletter_kratos);
        # $log->debug("edit link: ", $edit_link_kratos);
        # $log->debug("display barcode: ", $display_barcode_kratos);

        #retrieve users storable file
        my $user_file = "$data_root/users/" . get_string_id_for_lang("no_language", $UserID) . ".sto";
        if (-e $user_file) {

            my $request_ref = ProductOpener::Display::init_request();   
            my $user_ref = retrieve($user_file) ;

            open_user_session($user_ref, $request_ref);
            display_page($request_ref);
        }
        else{
            #store user file in storable if user has no sto file

            #create hash for storable
            my $hash = {    
                userid => $UserID,
                email => $email_kratos,
                name => $name_kratos,
                initial_lc => $lc,
                initial_cc => $cc,
                initial_user_agent => user_agent(),
                ip => remote_addr(),
                discussion => ''
            };

            if($newsletter_kratos == 0){
                $hash->{newsletter} = '';
            }
            else{
                $hash->{newsletter} = 'on';
            }

            if($edit_link_kratos == 0){
                $hash->{edit_link} = '';
            }
            else{
                $hash->{edit_link} = 1;
            }

            if($display_barcode_kratos == 0){
                $hash->{display_barcode} = '';
            }
            else{
                $hash->{display_barcode} = 1;
            }

            if($team_1_kratos ne ''){
                $hash->{team_1} = $team_1_kratos;
            }

            if($team_2_kratos ne ''){
                $hash->{team_2} = $team_2_kratos;
            }

            if($team_3_kratos ne ''){
                $hash->{team_3} = $team_3_kratos;
            }

            if($professional_account_kratos ne ''){
                $hash->{org} = $professional_account_kratos;
                $hash->{org_id} = $professional_account_kratos;
                $hash->{pro} = 1;
            }

            store($hash, $user_file);

            my $request_ref = ProductOpener::Display::init_request();   
            my $user_ref = retrieve($user_file) ;

            open_user_session($user_ref, $request_ref);
            display_page($request_ref);
        }
    }
    else {
        $log->debug("HTTP GET error code: ", $resp->code, "n");
        $log->debug("HTTP GET error message: ", $resp->message, "n");
    }
}
