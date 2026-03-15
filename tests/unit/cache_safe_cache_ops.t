use Modern::Perl '2017';
use utf8;

use Test2::V0;

use ProductOpener::Cache qw/safe_cache_get safe_cache_set/;

{

	package Local::FailingMemd;
	sub new {return bless {}, shift;}
	sub get {die "mock cache get failure";}
	sub set {die "mock cache set failure";}
}

{

	package Local::InMemoryMemd;
	sub new {return bless {store => {}}, shift;}

	sub get {
		my ($self, $key) = @_;
		return $self->{store}{$key};
	}

	sub set {
		my ($self, $key, $value) = @_;
		$self->{store}{$key} = $value;
		return 1;
	}
}

subtest 'safe cache helpers do not die on memcached exceptions' => sub {
	local $ProductOpener::Cache::memd = Local::FailingMemd->new();

	is(safe_cache_get('any-key'), undef, 'safe_cache_get returns undef on memcached error');
	is(dies {safe_cache_set('k', {x => 1}, 10);}, undef, 'safe_cache_set does not die on memcached error');
};

subtest 'safe cache helpers pass through on healthy cache' => sub {
	local $ProductOpener::Cache::memd = Local::InMemoryMemd->new();

	is(dies {safe_cache_set('ok-key', {v => 123}, 10);}, undef, 'safe_cache_set works on healthy memcached');
	is(safe_cache_get('ok-key'), {v => 123}, 'safe_cache_get returns stored value');
};

done_testing();
