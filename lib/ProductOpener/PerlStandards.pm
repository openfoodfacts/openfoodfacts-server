# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
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

use 5.36.0;
use strict;
use warnings;
use builtin ();
use feature ();
use utf8;

sub import {
	warnings->import;
	warnings->unimport('experimental::signatures', 'experimental::builtin');
	strict->import;
	feature->import(qw/signatures :5.36/);
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
    use v5.36;
    use feature 'signatures';
    no warnings 'experimental::signatures';
    use utf8;

It also makes the builtin:: functions available, so that builtin::true and
builtin::false can be used instead of !!1 and !!0. They must be called with
their full name: we deliberately do not "use builtin qw/true false>" here,
because the bare names true and false would then silently shadow the ones
imported by the boolean module in the 24 files that still use it, and
boolean::true is stored as a real MongoDB boolean while builtin::true is
stored as a double.

Most of this module's code has been copied from the Veure::Module
available on http://blogs.perl.org/users/ovid/2019/03/enforcing-simple-standards-with-one-module.html

Notes:
- the motivation for that module is to enable Perl's signatures: they are experimental since Perl 5.20
  and stable (ie. they no longer emit an experimental::signatures warning) since Perl 5.36
- 5.36 is the oldest Perl version we run in production (Debian bookworm), while we develop and run
  our tests with Debian trixie and Perl 5.40: see the Dockerfile
- this module replaces Modern::Perl, which we used before: "use Modern::Perl '2023'" would enable the
  same :5.36 feature bundle plus signatures, but it does not enable the utf8 pragma
- the builtin:: functions exist since Perl 5.36 and are called experimental until Perl 5.40,
  so we disable the experimental::builtin warnings category like the one for signatures
