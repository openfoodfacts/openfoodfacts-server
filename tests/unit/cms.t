use ProductOpener::PerlStandards;
use utf8;

use Encode qw(encode_utf8);
use ProductOpener::CMS qw/load_cms_data wp_get_available_pages wp_get_page_from_slug/;

use Test2::V0;

my @called_get_url = ();
my @called_post = ();

sub do_mock() {
	# faking the requests to the CMS
	my %fake_content = (
		'42' =>
			'{"title": {"rendered": "Contribute to the project"}, "content": {"rendered": "<h1>Contribute</h1>"}, "slug": "contribute"}',
		'45' =>
			'{"title": {"rendered": "Découvrez le projet"}, "content": {"rendered": "<h1>Découvrir</h1>"}, "slug": "découvrir"}',
	);
	my $fake_nodes = '[
        {
            "databaseId": 42,
            "slug": "contribute",
            "title": "contribute to the project",
            "languageCode": "en",
            "translations": [
                {
                    "databaseId": 43,
                    "slug": "contribuer",
                    "title": "Contribuez au projet",
                    "languageCode": "fr"
                },
                {
                    "databaseId": 46,
                    "slug": "contribuire",
                    "title": "Contribuire al progetto",
                    "languageCode": "it"
                }
            ]
        },
        {
            "databaseId": 44,
            "slug": "discover",
            "title": "Discover the project",
            "languageCode": "en",
            "translations": [{
                "databaseId": 45,
                "slug": "découvrir",
                "title": "Découvrez le projet",
                "languageCode": "fr"
            }]
        }
    ]';
	my $mocked_http_tiny = mock 'HTTP::Tiny' => (
		override => [
			'post' => sub {
				my ($obj, $url, $payload) = @_;
				# this will be used to fetch page list
				push @called_post,
					{
					url => $url,
					headers => $payload->{headers},
					content => $payload->{content},
					};
				my $response = {
					success => 1,
					content => encode_utf8('{"data": {"posts": {"nodes": ' . $fake_nodes . '}}}'),
				};
				return $response;
			},
			'get' => sub {
				my ($obj, $url) = @_;
				push @called_get_url, $url;
				my $page_id = "$1" if ($url =~ /.*\/(\d+)$/);
				return {success => 1, content => encode_utf8($fake_content{$page_id} // "[]")};
			},
		],
	);
	return ($mocked_http_tiny,);
}

sub do_unmock(@mocks) {
	foreach my $mock (@mocks) {
		$mock = undef;
	}
	return;
}

{
	my @mocks = do_mock();
	# load content first
	load_cms_data();
	is(scalar @called_post, 1, 'post to load cms data');
	is($called_post[0]->{url}, 'https://off:off@contents.openfoodfacts.org/graphql', 'graphql url');
	is($called_post[0]->{headers}, {'Content-Type' => 'application/json'}, 'graphql call headers');
	like($called_post[0]->{content}, qr/where: \{tag: \\"off\\"\}/, 'graphql filter on tags');

	# list pages
	my @pages_en = wp_get_available_pages("en");
	# no API call
	is(scalar @called_post, 1, 'no post for available pages');
	is(scalar @called_get_url, 0, 'no get for available pages');
	# avoid order change
	@pages_en = sort {$a->{id} <=> $b->{id}} @pages_en;
	is(
		\@pages_en,
		[
			{
				'id' => 42,
				'lc' => 'en',
				'link' => '/content/en/contribute',
				'title' => 'contribute to the project',
			},
			{
				'id' => 44,
				'lc' => 'en',
				'link' => '/content/en/discover',
				'title' => 'Discover the project',
			},
		],
		'pages en'
	);
	my @pages_fr = wp_get_available_pages("fr");
	@pages_fr = sort {$a->{id} <=> $b->{id}} @pages_fr;
	is(
		\@pages_fr,
		[
			{
				'id' => 43,
				'lc' => 'fr',
				'link' => '/content/fr/contribuer',
				'title' => 'Contribuez au projet',
			},
			{
				'id' => 45,
				'lc' => 'fr',
				'link' => '/content/fr/découvrir',
				'title' => 'Découvrez le projet',
			},
		],
		'pages fr'
	);
	# mixes english and italian
	my @pages_it = wp_get_available_pages("it");
	@pages_it = sort {$a->{id} <=> $b->{id}} @pages_it;
	is(
		\@pages_it,
		[
			{
				'id' => 44,
				'lc' => 'en',
				'link' => '/content/en/discover',
				'title' => 'Discover the project',
			},
			{
				'id' => 46,
				'lc' => 'it',
				'link' => '/content/it/contribuire',
				'title' => 'Contribuire al progetto',
			},
		],
		'pages it',
	);

	# test pages
	my $result = wp_get_page_from_slug("en", "contribute");
	is(scalar @called_get_url, 1);
	is($called_get_url[0], 'https://off:off@contents.openfoodfacts.org/wp-json/wp/v2/posts/42');
	is(
		$result,
		{
			'content' => '<h1>Contribute</h1>',
			'link' => '/content/en/contribute',
			'title' => 'Contribute to the project',
		},
		'contribute page'
	);
	$result = wp_get_page_from_slug("fr", "découvrir");
	is(scalar @called_get_url, 2);
	is($called_get_url[1], 'https://off:off@contents.openfoodfacts.org/wp-json/wp/v2/posts/45');
	is(
		$result,
		{
			'content' => '<h1>Découvrir</h1>',
			'link' => '/content/fr/découvrir',
			'title' => 'Découvrez le projet',
		},
		'découvrir page'
	);

	do_unmock(@mocks);
}

done_testing();
