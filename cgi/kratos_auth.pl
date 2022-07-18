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

use LWP::UserAgent;
use JSON;
use Log::Any qw($log);

my $kratos_cookie = cookie('ory_kratos_session');
log->debug($kratos_cookie);

if(defined $kratos_cookie){
    my $url = "http://kratos.openfoodfacts.localhost:4433/sessions/whoami";

    my $ua = LWP::UserAgent->new;

    # set custom HTTP request header fields, must include cookie for /session/whoami
    my $req = HTTP::Request->new(GET => $url);
    $req->header('content-type' => 'application/json');
    $req->header('Cookie' => $kratos_cookie);

    my $resp = $ua->request($req);

    if ($resp->is_success) {
        my $json = $resp->decoded_content;
        log->debug($json);
    }
    else {
        log->debug("HTTP GET error code: ", $resp->code, "n");
        log->debug("HTTP GET error message: ", $resp->message, "n");
    }
}

#Below code is test code for json hash to get UserID
# my $json = '';

# my $content = decode_json($json);
# my %contentdecoded = %$content;

# my $UserID = $contentdecoded{identity}{traits}{UserID};

# $log->debug("User ID: ", $UserID);






