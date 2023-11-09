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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package ProductOpener::PerlStandards;

use 5.24.0;
use strict;
use warnings;
use feature ();
use utf8;

sub import {
	warnings->import;
	warnings->unimport('experimental::signatures');
	strict->import;
	feature->import(qw/signatures :5.24/);
	utf8->import;
	return;
}

sub unimport {
	warnings->unimport;
	strict->unimport;
	feature->unimport;
	utf8->unimport;
	return;
}

1;

__END__

=head1 NAME

ProductOpener::PerlStandards - Use modern Perl features

=head1 SYNOPSIS

    use ProductOpener::PerlStandards;

=head1 DESCRIPTION

This module is a replacement for the following:

    use strict;
    use warnings;
    use v5.24;
    use feature 'signatures';
    no warnings 'experimental::signatures';
    use utf8;

Most of this module's code has been copied from the Veure::Module
available on http://blogs.perl.org/users/ovid/2019/03/enforcing-simple-standards-with-one-module.html

Notes:
- the motivation for that module is to enable Perl's signatures that are experimental since Perl 5.24 and non-experimental in Perl 5.34
- we cannot use "use Modern::Perl '2022'" to activate signatures as we run Perl 5.24 in production today (July 2022)
