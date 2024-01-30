
=head1 TestCover - some utils for test coverage

=head2 Description

This is a small module that handles some specific actions for test coverage.

Keep it small because it might be a bit pervasive.

=cut

package ProductOpener::TestCover;

use ProductOpener::PerlStandards;

=head2 handle_cover

Method to handle specific actions for test coverage.

=cut
sub handle_cover() {
	if ((!!$ENV{PRODUCT_OPENER_COVERAGE}) and (!!$ENV{MOD_PERL})) {
		# explicitely use Devel::Cover::report() for we use prefork
		# see https://github.com/pjcj/Devel--Cover/issues/244#issuecomment-742776545
		Devel::Cover::report() if Devel::Cover->can('report');
	}
	return;
}

1;