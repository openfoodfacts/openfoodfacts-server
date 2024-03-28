package Apache2::Const;
use Exporter::Lite;

sub import {
	my ($exporter, @imports) = @_;

    my($caller, $file, $line) = caller;

	my $dash_compile;
	$dash_compile = shift @imports if $imports[0] && $imports[0] eq '-compile';

    no strict 'refs';

    foreach my $sym (@imports) {
        # shortcut for the common case of no type character

        *{$caller .'::' . $sym} = sub {1} unless $dash_compile;
		*{'Apache2::Const::'.$sym} = sub {1};
    }
}

1;
