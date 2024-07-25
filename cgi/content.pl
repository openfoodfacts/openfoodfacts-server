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








# sub format_page {
#     my ($content, $request_ref) = @_;

#     my $text_lc = $request_ref->{lc};

#     $request_ref->{styles} .= '';
#     $request_ref->{header} .= '';

#     $request_ref->{title} = "";

#     # https://s0.wp.com/wp-content/plugins/gutenberg-core/v18.8.0/build/block-library/style.css?m=1721328021i&ver=18.8.0
#     my $html = "";
#     $html = '<link rel="stylesheet" href="'.$static_subdomain.'/css/wp.css"></style>';
#     $html .= <<"TITLE";
#     <div class="wp-block-group has-global-padding is-layout-constrained wp-block-group-is-layout-constrained">
# 		<div style="height:var(--wp--preset--spacing--50)" aria-hidden="true" class="wp-block-spacer"></div>
# 		<h1 class="has-text-align-center wp-block-post-title">$content->{title}->{rendered}</h1>
# 		<div style="margin-top:0;margin-bottom:0;height:var(--wp--preset--spacing--30)" aria-hidden="true" class="wp-block-spacer"></div>	
# 	</div>
# TITLE
    
#     $html .= "<h1 class=\"entry-title\"></h1>";
#     $html .= "<div class=\"entry-content wp-block-post-content has-global-padding is-layout-constrained wp-block-post-content-is-layout-constrained\">$content->{content}->{rendered}</div>";

#     ${$request_ref->{content_ref}} =  $html;
    $request_ref->{canon_url} = "/bop";
}

# Passing values to the template
my $template_data_ref = {};

my $request_ref = ProductOpener::Display::init_request();
# my $content = format_page(wp_get_page_by_id('14'), $request_ref);


display_page($request_ref);

exit 0;