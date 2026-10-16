package ProductOpener::Ingredients::Sections;

use ProductOpener::PerlStandards;
use Exporter qw(import);
use JSON::MaybeXS;

our @EXPORT_OK = qw(split_ingredient_sections);

# Keep source spans separate from the bodies that may be passed to ingredient parsing.
sub split_ingredient_sections ($text, $lc) {
	return unless defined $text && $text =~ /\S/ && $lc =~ /^(?:fr|en)$/;
	# An additives heading may carry a dose reference, "(/kg)" or "(per kg)", but not a list of additives.
	my $additives = qr/
		(?:additifs(?:\s*:\s*additifs)?(?:\s+(?:nutritionnels|technologiques|organoleptiques|zootechniques))?
		|(?:nutritional|technological|sensory|zootechnical)\s+additives|additives)
		[_*]*(?:\h*\([^()]*\bkg\b[^()]*\)[_*]*)?\h*
	/xi;
	# Emphasis marks are read from the start of their run, so that a long run is not rescanned from each of its marks.
	my $emphasis = qr/(?<![_*])[_*]*/;
	my @patterns = (
		['ingredients', qr/$emphasis(?:composition|ingrédients|ingredients)[_*]*\s*:\s*[_*]*/i],
		[
			'analytical',
			qr/$emphasis(?:constituants\s+analytiques|analytical\s+(?:constituents|analysis))\s*:?\s*[_*]*/i
		],
		# After a colon anywhere in a sentence, or alone on its line.
		['additives', qr/(?<![\pL\pN])$emphasis$additives:\h*[_*]*|(?:^|(?<=[\r\n]))\h*[_*]*$additives(?:\R|$)/i],
	);
	if ($lc eq 'fr') {
		push @patterns,
			[
			'recipe',
			qr/(?:^|(?<=[\r\n.]))[ \t]*[_*]*(?:[ée]minc[ée]s?|recette|pât[ée]e|bouch[ée]es?)\b[^:;\r\n]{0,160}:\s*[_*]*/i
			];
	}
	else {
		# The previous recipe may end immediately before "With" in copied label text.
		push @patterns, ['recipe', qr/${emphasis}With\s+[^:;\r\n]{1,120}?\s+Ingredients\s*:\s*[_*]*/i];
	}
	my @markers;
	for my $pattern (@patterns) {
		while ($text =~ /$pattern->[1]/g) {
			push @markers, {type => $pattern->[0], start => $-[0], end => $+[0], heading => $&};
		}
	}
	# An interpolated qr keeps its own flags: the case-insensitivity of the matches below does not reach it.
	my $kibble = $lc eq 'fr' ? qr/croquettes/i : qr/kibbles?/i;
	my $mixture_start = $lc eq 'fr' ? qr/de\s+croquettes\b/i : qr/(?:of\s+)?(?:[\pL-]+\s+){0,2}kibbles?\b/i;
	my $finished_product = $lc eq 'fr' ? qr/produit\s+fini/i : qr/finished\s+product/i;
	while ($text =~ /(?:^|[\r\n]|(?<!\d)\.(?!\d))\s*(\d+(?:[.,]\d+)?\s*%\s+$mixture_start)/ig) {
		my $start = $-[1];
		my $description = substr($text, $start);
		if ($description =~ /$finished_product/i && scalar(() = $description =~ /$kibble/ig) >= 2) {
			push @markers, {type => 'mixture', start => $start, end => $start};
		}
	}
	@markers = sort {$a->{start} <=> $b->{start} || $b->{end} <=> $a->{end}} @markers;
	my @boundaries;
	for my $marker (@markers) {
		next if @boundaries && $marker->{start} < $boundaries[-1]{end};
		push @boundaries, $marker;
	}
	my @sections;
	if (!@boundaries || $boundaries[0]{start} > 0) {
		my $prefix = substr($text, 0, @boundaries ? $boundaries[0]{start} : length($text));
		push @sections, {type => 'ingredients', text => $prefix, _body => $prefix} if $prefix =~ /\S/;
	}
	for my $i (0 .. $#boundaries) {
		my $marker = $boundaries[$i];
		my $end = $i < $#boundaries ? $boundaries[$i + 1]{start} : length($text);
		my $section = {
			type => $marker->{type},
			text => substr($text, $marker->{start}, $end - $marker->{start}),
			_body => substr($text, $marker->{end}, $end - $marker->{end}),
		};
		if ($marker->{type} eq 'recipe') {
			my $name = $marker->{heading};
			$name =~ s/[_*]//g;
			$name =~ s/\s*:\s*$//;
			$name =~ s/^\s+|\s+$//g;
			$section->{name} = $name;
		}
		push @sections, $section;
	}

	my $labels
		= $lc eq 'fr'
		? qr/protéines?(?:\s+brutes?)?|matières\s+grasses(?:\s+brutes?)?|cendres(?:\s+brutes?)?|cellulose(?:\s+brute)?|humidité|calcium|phosphore|sodium|magnésium|potassium|soufre|chlorure|taurine/i
		: qr/(?:crude\s+)?(?:protein|fat|ash|fib(?:re|er))|moisture|calcium|phosphorus|sodium|magnesium|potassium|sulphur|chloride|taurine/i;
	my $entry = qr/(?:$labels)\s*(?::\s*)?\d+(?:[.,]\d+)?\s*(?:%|[mk]?g\s*\/\s*kg)/i;
	my @result;
	my $inferred = 0;
	for my $section (@sections) {
		my $body = $section->{_body};
		my ($start, $end);
		if ($section->{type} =~ /^(?:ingredients|recipe)$/) {
			while ($body =~ /(?<!\pL)$entry(?:[\s,;]+$entry){2,}/g) {
				my ($run, $run_start, $run_end) = ($&, $-[0], $+[0]);
				my $markers
					= ($run =~ /cendres|\bash\b/i ? 1 : 0)
					+ ($run =~ /cellulose|\bfib(?:re|er)\b/i ? 1 : 0)
					+ ($run =~ /humidité|\bmoisture\b/i ? 1 : 0);
				if ($markers >= 2) {
					($start, $end) = ($run_start, $run_end);
					last;
				}
			}
		}
		if (defined $start) {
			my $header_length = length($section->{text}) - length($body);
			my $prefix = {
				%$section,
				text => substr($section->{text}, 0, $header_length + $start),
				_body => substr($body, 0, $start)
			};
			push @result, $prefix if $prefix->{_body} =~ /\S/;
			my $suffix = substr($body, $end);
			my $analytics = substr($body, $start, $end - $start);
			if ($suffix !~ /[^\s.]/) {
				$analytics .= $suffix;
				$suffix = '';
			}
			push @result,
				{
				type => 'analytical',
				text => $analytics,
				_body => $analytics,
				inferred => JSON::MaybeXS::true()
				};
			push @result, {type => 'ingredients', text => $suffix, _body => $suffix} if $suffix =~ /\S/;
			$inferred = 1;
		}
		else {
			push @result, $section;
		}
	}
	return unless @boundaries || $inferred;
	return \@result;
}

1;
