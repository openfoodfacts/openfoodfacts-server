
use strict;
use warnings;

use ProductOpener::Paths qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;
use ProductOpener::CMS qw/:all/;

use ProductOpener::Lang qw/$lc  %Lang lang/;

use CGI qw/:cgi :form escapeHTML charset/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Log::Any qw($log);
use Encode;

# Passing values to the template
my $template_data_ref = {};

my $request_ref = ProductOpener::Display::init_request();
# my $content = format_page(wp_get_page_by_id('14'), $request_ref);

display_page($request_ref);

exit 0;
