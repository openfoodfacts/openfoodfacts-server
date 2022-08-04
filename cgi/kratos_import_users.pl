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

#input a userid
my $UserID = "testimport5";

#get user file
my $user_file = "$data_root/users/" . get_string_id_for_lang("no_language", $UserID) . ".sto";
my $user_ref = retrieve($user_file);

#get user info from sto file
my $userid = $user_ref->{userid};
my $email = $user_ref->{email};
my $name = $user_ref->{name};
my $password = $user_ref->{encrypted_password};

# $log->debug("userid: ", $userid);
# $log->debug("email: ", $email);
# $log->debug("name: ", $name);

#modify string to fit how kratos wants PBKDF2 password Example: $pbkdf2-sha256$i=100000,l=32$1jP+5Zxpxgtee/iPxGgOz0RfE9/KJuDElP1ley4VxXc$QJxzfvdbHYBpydCbHoFg3GJEqMFULwskiuqiJctoYpI
my $beginning_of_password = "\$pbkdf2-sha256\$i=100000,l=32";
my($scrypt, $cost, $block_size, $parallel_param, $salt, $password) = split /:/, $password;
$salt = "\$".$salt;
$password = "\$".$password;
chop($salt);
chop($password);

# $log->debug("salt: ", $salt);
# $log->debug("password: ", $password);

#combine salt and password to import to kratos
my $kratos_password = $beginning_of_password.$salt.$password;

# $log->debug("kratos_password: ", $kratos_password);

#create json to post
my $post_json = JSON->new;

my $data_to_json = {
    'traits' => {
        'UserID' => $userid,
        'email' => $email,
        'name' => $name
    },
    'credentials' => {
        'password' => {
            'config' => {
                'hashed_password' => $kratos_password
            }
        }
    }
};

my $str = encode_json($data_to_json);

$log->debug("json: ", $str);

my $ua = LWP::UserAgent->new;

#post request to create identity
my $post_req = HTTP::Request->new(POST => "http://kratos.openfoodfacts.localhost:4434/admin/identities");
$post_req->header('accept' => 'application/json');
$post_req->header('content-type' => 'application/json');
$post_req->content($str);

my $post_resp = $ua->request($post_req);

if($post_resp->is_success){
    $log->debug("User Created");
}
else{
    $log->debug("HTTP POST error code: ", $post_resp->code);
    $log->debug("HTTP POST error message: ", $post_resp->message);
}
