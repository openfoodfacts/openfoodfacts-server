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

use 5.40.0;
use strict;
use warnings;
use feature ();
use utf8;

sub import {
	warnings->import;
	strict->import;
	feature->import(':5.40');
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
    use feature ':5.40';
    use utf8;

Note that it is deliberately not a replacement for "use v5.40": since Perl 5.40,
"use v5.40" also imports the builtin ':5.40' bundle, which makes the bare names
true and false available. We enable the features with feature->import() so that
we keep control over what is imported.

The builtin:: functions are available without any pragma, as long as they are
called with their full name, so builtin::true and builtin::false can be used
instead of !!1 and !!0. We deliberately never import them: the bare names true
and false would silently shadow the ones imported by the boolean module in the
24 files that still use it, and boolean::true is stored as a real MongoDB
boolean while builtin::true is stored as a double.

Most of this module's code has been copied from the Veure::Module
available on http://blogs.perl.org/users/ovid/2019/03/enforcing-simple-standards-with-one-module.html

Notes:
- the motivation for that module is to enable Perl's signatures: they are experimental since Perl 5.20
  and stable (ie. they no longer emit an experimental::signatures warning) since Perl 5.36. The :5.40
  bundle enables them, so nothing has to be silenced: perl keeps experimental::signatures only as a
  category that never fires
- 5.40 is the oldest Perl version we run, and it is the Perl version of Debian trixie, the image our
  Dockerfile is based on: we develop and run our tests with it
- since Perl 5.36, using @_ (or shift / pop without argument) inside a signatured subroutine emits the
  experimental::args_array_with_signatures warning category, which experimental::signatures does not
  cover. We deliberately do not silence it: our subs use their named arguments
- the builtin module exists since Perl 5.36 and is no longer experimental since Perl 5.40, so the
  builtin::true and builtin::false that we use do not warn anymore. A few of its functions (inf, nan,
  is_bool, created_as_string, created_as_number, stringify, export_lexically and load_module) are still
  experimental in Perl 5.40: we deliberately do not silence experimental::builtin, so that we are
  warned if we start using one of them
- this module replaces Modern::Perl, which we used before: "use Modern::Perl '2025'" would enable the
  same :5.40 feature bundle plus signatures, but it does not enable the utf8 pragma
