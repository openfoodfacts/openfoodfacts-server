#!/usr/bin/perl -w

# Check the local image paths that ProductOpener::Export::export_csv() writes when
# include_images_paths is set, as used by the producers platform to export products
# and their photos to the public platform.

use ProductOpener::PerlStandards;

use Test2::V0;
use Log::Any::Adapter 'TAP', filter => "info";

use Text::CSV;

use ProductOpener::Export qw/export_csv/;
use ProductOpener::Paths qw/%BASE_DIRS/;
use ProductOpener::Products qw/product_path/;

# Minimal stand-in for the MongoDB collection and cursor used by export_csv()

our @products;

{

	package Local::FakeCollection;

	sub new {return bless({}, 'Local::FakeCollection');}
	sub count_documents {return scalar @main::products;}
	sub find {return bless({i => 0}, 'Local::FakeCursor');}

	package Local::FakeCursor;

	sub immortal {return;}
	sub reset {my ($self) = @_; $self->{i} = 0; return;}

	sub next {
		my ($self) = @_;
		return $main::products[$self->{i}++];
	}
}

my $product_ref = {
	code => "5400119605465",
	lc => "en",
	product_name => "Test product",
	images => {
		uploaded => {
			1 => {imgid => 1},
			2 => {imgid => 2},
		},
		selected => {
			front => {
				en => {
					imgid => 1,
					generation => {angle => 0, x1 => -1, y1 => -1, x2 => -1, y2 => -1},
				},
			},
		},
	},
};

@products = ($product_ref);

my $csv_content = "";

{
	no warnings 'redefine';
	local *ProductOpener::Export::get_products_collection = sub {return Local::FakeCollection->new()};

	open(my $filehandle, ">:encoding(UTF-8)", \$csv_content) or die("Could not open in-memory filehandle: $!\n");
	export_csv({filehandle => $filehandle, filename => "test.csv", include_images_paths => 1, query => {}});
	close($filehandle);
}

my $csv = Text::CSV->new({binary => 1, sep_char => "\t"});
open(my $in, "<", \$csv_content) or die("Could not read in-memory CSV: $!\n");
my $header_ref = $csv->getline($in);
my $row_ref = $csv->getline($in);
close($in);

my %row;
@row{@$header_ref} = @$row_ref;

my $images_path = "$BASE_DIRS{PRODUCTS_IMAGES}/" . product_path($product_ref);

is($row{image_front_en_file}, "$images_path/1.jpg", "selected front image path is exported");
is($row{image_other_1_file}, "$images_path/2.jpg", "unselected image is exported as image_other_1_file");

done_testing();
