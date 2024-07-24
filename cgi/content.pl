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
use LWP::Simple;

my $wordpress_url = 'https://public-api.wordpress.com/wp/v2/sites/offcontent.wordpress.com';


sub wp_get_page {
    my ($page_id) = @_;
    my $url = "$wordpress_url/pages/$page_id";
    my $response = get($url);
    my $json = decode_json($response);
    return $json;
}

# Passing values to the template
my $template_data_ref = {};

my $request_ref = ProductOpener::Display::init_request();
my $content = wp_get_page('6');


my $text_lc = $request_ref->{lc};

$request_ref->{styles} .= '';
$request_ref->{header} .= '';

$request_ref->{title} = "$content->{title}->{rendered}";


# https://s0.wp.com/wp-content/plugins/gutenberg-core/v18.8.0/build/block-library/style.css?m=1721328021i&ver=18.8.0
my $html = "";
$html = '<link rel="stylesheet" href="'.$static_subdomain.'/css/wp.css"></style>';

$html .= "<div class=\"entry-content wp-block-post-content has-global-padding is-layout-constrained wp-block-post-content-is-layout-constrained\">$content->{content}->{rendered}</div>";

${$request_ref->{content_ref}} =  $html;
$request_ref->{canon_url} = "/bop";


display_page($request_ref);

exit 0;