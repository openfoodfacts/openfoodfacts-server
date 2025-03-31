use ProductOpener::PerlStandards;

use Test2::V0;

use ProductOpener::Cursor;

my $cursor = ProductOpener::Cursor->new([1, 2]);

is($cursor->next(), 1);
is($cursor->next(), 2);
is($cursor->next(), undef);

is($cursor->all, [1, 2]);

done_testing();
