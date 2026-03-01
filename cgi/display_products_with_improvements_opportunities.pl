#!/usr/bin/perl -w

# This file is part of Product Opener.
# (License and use statements omitted for brevity)

use ProductOpener::PerlStandards;
use CGI::Carp qw(fatalsToBrowser);
use ProductOpener::Config qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::Lang qw/:all/;
use ProductOpener::Data qw/:all/;
use ProductOpener::Users qw/$User_id %User/;
use Log::Any qw($log);
use Text::CSV;
use Excel::Writer::XLSX;
use CGI qw(:standard);

my $request_ref = ProductOpener::Display::init_request();

my $products_collection = get_products_collection({database => "off"});
my @products;

my $products = $products_collection->aggregate(
	[
		{'$match' => { 'improvements_data' => {'$ne' => {}} }},
		{'$project' => {
			'barcode' => 1,
			'product_name' => 1,
			'improvements' => {
				'$objectToArray' => '$improvements_data'
			}
		}},
		{'$unwind' => '$improvements'},
		{'$project' => {
			'barcode' => 1,
			'product_name' => 1,
			'score_name' => '$improvements.k',
			'current_score' => '$improvements.v.current_nutriscore_grade',
			'new_score' => '$improvements.v.new_nutriscore_grade',
			'nutrient' => '$improvements.v.nutrient',
			'current_value' => '$improvements.v.current_value',
			'new_value' => '$improvements.v.new_value'
		}}
	]
);

my $template_data_ref = {products => \@products, has_products => scalar @products > 0};

if (param('download') eq 'csv') {
	export_as_csv(\@products);
} elsif (param('download') eq 'excel') {
	export_as_excel(\@products);
} else {
	my $html;
	process_template('web/pages/product/download_product_improvement_opportunities.tt.html', $template_data_ref, \$html) or $html = '';
	if ($tt->error()) {
		$html .= '<p>' . $tt->error() . '</p>';
	}

	$request_ref->{initjs} .= <<'JS';
let oTable = \$('#tagstable').DataTable({
	language: {
		search: "Search:",
		info: "_TOTAL_ labels",
		infoFiltered: " - out of _MAX_"
    },
	paging: false,
	order: [[ 1, "desc" ]],
});
JS

	$request_ref->{scripts} .= <<SCRIPTS
<script src="https://static.openfoodfacts.org/js/datatables.min.js"></script>
SCRIPTS
	;

$request_ref->{header} .= <<HEADER
<link rel="stylesheet" href="https://static.openfoodfacts.org/js/datatables.min.css">
HEADER
	;

	$request_ref->{title} = "Organization List";
$request_ref->{content_ref} = \$html;
display_page($request_ref);

	$request_ref->{title} = "Products with Opportunities for Improvement";
	$request_ref->{content_ref} = \$html;
	display_page($request_ref);
}

sub export_as_csv {
	my ($products) = @_;
	my $csv = Text::CSV->new({ binary => 1, eol => $/ });

	print header(
		-type => 'text/csv',
		-attachment => 'product_improvements.csv',
	);

	$csv->print(*STDOUT, ['Serial No', 'Barcode', 'Product Name', 'Score Name', 'Current Score', 'New Score', 'Nutrient', 'Current Value', 'New Value']);
	my $count = 1;
	foreach my $product (@$products) {
		$csv->print(*STDOUT, [
			$count++,
			$product->{barcode},
			$product->{product_name},
			$product->{score_name},
			$product->{current_score},
			$product->{new_score},
			$product->{nutrient},
			$product->{current_value},
			$product->{new_value}
		]);
	}
}

sub export_as_excel {
	my ($products) = @_;

	print header(
		-type => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
		-attachment => 'product_improvements.xlsx',
	);

	my $workbook  = Excel::Writer::XLSX->new(\*STDOUT);
	my $worksheet = $workbook->add_worksheet();

	$worksheet->write_row(0, 0, ['Serial No', 'Barcode', 'Product Name', 'Score Name', 'Current Score', 'New Score', 'Nutrient', 'Current Value', 'New Value']);
	my $row = 1;
	my $count = 1;
	foreach my $product (@$products) {
		$worksheet->write_row($row++, 0, [
			$count++,
			$product->{barcode},
			$product->{product_name},
			$product->{score_name},
			$product->{current_score},
			$product->{new_score},
			$product->{nutrient},
			$product->{current_value},
			$product->{new_value}
		]);
	}

	$workbook->close();
}
