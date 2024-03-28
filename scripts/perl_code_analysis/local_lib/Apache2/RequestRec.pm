package Apache2::RequestRec;

sub new    {bless {}, shift}

sub method      	{"GET"}
sub headers_out 	{FakeHeaders->new}
sub headers_in  	{FakeHeaders->new}
sub err_headers_out {FakeHeaders->new}
sub hostname        {"FAKE_HOST"}
sub status          {}
sub rflush          {}

package FakeHeaders;

sub new    {bless {}, shift}
sub set    {}


1;
