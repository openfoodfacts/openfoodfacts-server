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

use ProductOpener::PerlStandards;

use CGI::Carp qw(fatalsToBrowser);

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Lang qw/:all/;

use Apache2::Const -compile => qw(OK);
use CGI qw/:cgi :form escapeHTML/;
use URI::Escape::XS;
use Encode;
use Log::Any qw($log);

my $request_ref = ProductOpener::Display::init_request();

# Redirect the left to right or right to left CSS based on the subdomain
# This is useful for static HTML files (e.g. donation page translated by CrowdIn)

my $redirect
	= $static_subdomain
	. "/css/dist/app-"
	. lang('text_direction')
	. ".css?v="
	. $file_timestamps{'css/dist/app-' . lang('text_direction') . '.css'};

redirect_to_url($request_ref, 302, $redirect);
