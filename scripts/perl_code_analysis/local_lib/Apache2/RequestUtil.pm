package Apache2::RequestUtil;

use Apache2::RequestRec;

sub new     { bless {}, shift}
sub request { Apache2::RequestRec->new }

1;
