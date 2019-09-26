# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2019 Association Open Food Facts
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

=head1 NAME

ProductOpener::Export - export products data in a CSV file

=head1 SYNOPSIS

C<ProductOpener::Export> is used to export in a CSV file all populated fields
of products matching a given MongoDB search query.

    use ProductOpener::Export qw/:all/;
	export_csv_file($file, { countries_tags=>"en:france", labels_tags=>"en:organic" });

Only columns that are not completely empty will be included in the resulting CSV file.
This is to avoid generating CSV files with thousands of empty columns (e.g. all possible
nutrients and all the language specific fields like ingredients_text_[language code] for
all the hundreds of possible languages.

Fields that are computed from other fields are not directly provided by users or producers
are not included by default. They can be included by passing an optional additional options
parameter:

	export_csv_file($file, { ingredients_tags=>"en:palm-oil" }, {
		extra_fields=>[qw(nova_group nutrition_grade_fr)],
	});

It is also possible to specify to export only some fields:

	export_csv_file($file, { ingredients_tags=>"en:palm-oil" }, {
		fields=>[qw(code product_name_en nova_group)],
	});

This module is used in particular to export product data provided by manufacturers on
the producers platform so that it can then be imported in the public database.

In the producers platform, the C<export_csv_file> function is executed through a Minion worker.

It is also used in the C<scripts/export_csv_file.pl> script.


=head1 DESCRIPTION

Use the list of fields from C<Product::Opener::Config::options{import_export_fields_groups}>
and the list of nutrients from C<Product::Opener::Food::nutriments_tables> to list fields
that need to be exported.

The results of the query are scanned a first time to compute the list of non-empty columns,
unless the options parameter specifies C<<include_other_fields=>0>> in which case only
the fields specified through the C<fields> options parameter are included.

The results of the query are scanned a second time to output the CSV file.

This 2 phases approach is done to avoid having to store all the products data in memory.

=cut

package ProductOpener::Export;

use utf8;
use Modern::Perl '2017';
use Exporter    qw< import >;

use Log::Any qw($log);

BEGIN
{
	use vars       qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@EXPORT = qw();            # symbols to export by default
	@EXPORT_OK = qw(

		&export_csv_file

					);	# symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK ;

use ProductOpener::Config qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Products qw/:all/;
use ProductOpener::Data qw/:all/;

use Text::CSV;


=head1 FUNCTIONS

=head2 export_csv_file( FILENAME, QUERY[, OPTIONS ] )

C<export_csv_file()> creates a CSV file with data for products matching a query.

Only non empty columns are included. By default, fields that are computed from other fields
are not included, but extra fields can be exported using the third OPTIONS argument.

=head3 Arguments

=head4 FILENAME - Path and name of the CSV file to be created

If the file already exists, it will be overwritten.

=head4 QUERY - MongoDB Query

The second argument is a hash ref that specifies the query that will be passed to MongoDB.
Each key value pair will be used to filter products with matching field values.

   export_csv_file($file, { categories_tags => "en:beers", ingredients_tags => "en:wheat" });

=head4 OPTIONS - Options

The optional third argument allows to specify which fields to export, including fields
that are computed from other fields such as the NOVA group or the Nutri-Score nutritional grade.

The OPTIONS argument is a hash ref that contains either a C<extra_fields> or C<fields> key
with a value that is a reference to a list of fields.

To add fields in addition to the fields exported by default (all fields that have been
supplied by users or producers), use the C<extra_fields>:

	export_csv_file($file, { ingredients_tags=>"en:palm-oil" }, {
		extra_fields=>[qw(nova_group nutrition_grade_fr)],
	});

To specify to only export certain fields, use the C<fields>:

	export_csv_file($file, { ingredients_tags=>"en:palm-oil" }, {
		fields=>[qw(code product_name_en nova_group)],
	});

=cut

sub export_csv_file() {

	my $file = shift;
	my $query_ref = shift;
	my $options_ref = shift;

	# To be implemented
}



1;

