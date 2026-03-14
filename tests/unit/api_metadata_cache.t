#!/usr/bin/perl -w

use Modern::Perl '2017';
use utf8;

use Test2::V0;
use Storable qw/dclone/;

use ProductOpener::APIAttributeGroups qw/preferences_api attribute_groups_api/;

my $preferences_request_ref = {
    lc => 'en',
    api_version => '3.5',
    api_response => {},
};

preferences_api($preferences_request_ref);
ok(ref($preferences_request_ref->{api_response}{preferences}) eq 'ARRAY', 'preferences returns an array');
is($preferences_request_ref->{http_response_headers}{'Cache-Control'}, 'public, max-age=600');
is($preferences_request_ref->{http_response_headers}{'Vary'}, 'Accept-Language');

my $preferences_first_ref = dclone($preferences_request_ref->{api_response}{preferences});
$preferences_request_ref->{api_response}{preferences}[0]{name} = 'Mutated value';
$preferences_request_ref->{api_response} = {};
preferences_api($preferences_request_ref);
is($preferences_request_ref->{api_response}{preferences}, $preferences_first_ref, 'preferences cache returns stable cloned payload');

my $attribute_groups_request_ref = {
    lc => 'en',
    api_version => '3.5',
    api_response => {},
};

attribute_groups_api($attribute_groups_request_ref);
ok(ref($attribute_groups_request_ref->{api_response}{attribute_groups}) eq 'ARRAY', 'attribute_groups returns an array');
is($attribute_groups_request_ref->{http_response_headers}{'Cache-Control'}, 'public, max-age=600');
is($attribute_groups_request_ref->{http_response_headers}{'Vary'}, 'Accept-Language');

my $attribute_groups_first_ref = dclone($attribute_groups_request_ref->{api_response}{attribute_groups});
$attribute_groups_request_ref->{api_response}{attribute_groups}[0]{id} = 'mutated-id'
    if @{$attribute_groups_request_ref->{api_response}{attribute_groups}};
$attribute_groups_request_ref->{api_response} = {};
attribute_groups_api($attribute_groups_request_ref);
is($attribute_groups_request_ref->{api_response}{attribute_groups}, $attribute_groups_first_ref, 'attribute_groups cache returns stable cloned payload');

done_testing();
