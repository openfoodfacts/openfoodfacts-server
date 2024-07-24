use ProductOpener::Config qw/:all/;
use ProductOpener::Paths qw/:all/;
use ProductOpener::Store qw/:all/;
use ProductOpener::Index qw/:all/;
use ProductOpener::Display qw/:all/;

use ProductOpener::Lang qw/$lc  %Lang lang/;

use CGI qw/:cgi :form escapeHTML charset/;
use URI::Escape::XS;
use Storable qw/dclone/;
use Log::Any qw($log);
use Encode;
use JSON;

my $wordpress_url = 'https://public-api.wordpress.com/wp/v2/sites/offcontent.wordpress.com';


sub wp_get_page {
    my ($page_id) = @_;
    my $url = "$wordpress_url/pages/$page_id";
    my $response = get($url);
    my $json = decode_json($response);
    return $url;
}

# Passing values to the template
my $template_data_ref = {};

my $request_ref = ProductOpener::Display::init_request();


my $text_lc = $request_ref->{lc};
my $html = "";
$request_ref->{styles} .= '';
$request_ref->{header} .= '';
$request_ref->{title} = 'Test';

my $content = wp_get_page('6');

${$request_ref->{content_ref}} = "<pre>$content</pre>" ;
$request_ref->{canon_url} = "/bop";


display_page($request_ref);

exit 0;