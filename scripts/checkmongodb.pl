#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use Modern::Perl '2017';
use utf8;

use ProductOpener::Data qw/:all/;

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
my $server_endpoint = "https://hooks.slack.com/services/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";


sub send_msg($) {

	my $msg = shift;

# set custom HTTP request header fields
	my $req = HTTP::Request->new(POST => $server_endpoint);
	$req->header('content-type' => 'application/json');

	# add POST data to HTTP request body
	my $post_data = '{"channel": "#infrastructure", "username": "checkmongodb", "text": "' . $msg . '", "icon_emoji": ":hamster:" }';
	$req->content_type("text/plain; charset='utf8'");
	$req->content(Encode::encode_utf8($post_data));

	my $resp = $ua->request($req);
	if ($resp->is_success) {
		my $message = $resp->decoded_content;
		print "Received reply: $message\n";
	}
	else {
		print "HTTP POST error code: " .  $resp->code . "\n";
		print "HTTP POST error message: " . $resp->message . "\n";
	}

	return;
}

my $count;

eval {
	$count = execute_query(sub {
					return get_products_tags_collection()->count_documents({});
				});
};

print STDERR "count: $count\n";

if ($@) {
	my $hostname = `hostname`;
	my $msg = "Host: $hostname - Mongodb down: $@\n";
	send_msg($msg);
	print STDERR $msg;
	$msg = "trying to restart mongod service: service mongod restart : " . `service mongod restart`;
	send_msg($msg);
	print STDERR $msg;

}

exit(0);


