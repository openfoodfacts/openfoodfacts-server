use Imager;
use Imager::zxing;
my $decoder = Imager::zxing::Decoder->new();
$decoder->set_formats("DataMatrix|QRCode|MicroQRCode|DataBar|DataBarExpanded");

my $imager = Imager->new();
my $file = "tests/unit/inputs/images/37_gs1_datamatrix.jpg";
$imager->read(file => $file)
	or die "Cannot read $file: ", $imager->errstr;
my @results = $decoder->decode($imager);
# extract results
foreach my $result (@results) {
	if (not($result->is_valid())) {
		next;
	}

	my $code = $result->text();
	my $type = $result->format();
	print STDERR "scan_code code found: $code\n";
}