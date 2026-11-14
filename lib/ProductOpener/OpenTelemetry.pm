# This file is part of Product Opener.
#
# Product Opener
# Copyright (C) 2011-2026 Association Open Food Facts
# Contact: contact@openfoodfacts.org
# Address: 21 rue des Iles, 94100 Saint-Maur des Fossés, France
#
# Product Opener is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

ProductOpener::OpenTelemetry - manages OpenTelemetry integration for Product Opener

=head1 SYNOPSIS

C<ProductOpener::OpenTelemetry> contains functions to manage OpenTelemetry integration for Product Opener.

    use ProductOpener::OpenTelemetry qw/:all/;

	[..]

=head1 DESCRIPTION

[..]

=cut

package ProductOpener::OpenTelemetry;

use ProductOpener::PerlStandards;
use Exporter qw< import >;

BEGIN {
	use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);
	@EXPORT_OK = qw(

		&get_otel
		&install_lwp_instrumentation
		&parent_context

	);    # symbols to export on request
	%EXPORT_TAGS = (all => [@EXPORT_OK]);
}

use vars @EXPORT_OK;

use Punk::OpenTelemetry ();
use Log::Any qw($log);
use ProductOpener::Constants qw(OTEL_SPAN_PNOTES_KEY);

my $instance = undef;

sub get_otel {
	if ($instance) {
		return $instance;
	}

	$instance = ProductOpener::OpenTelemetry->new();
	return $instance;
}

# The current request's span as the parent context shape start() takes
# ({ trace_id, span_id, sampled }), or undef when there is none: outside a
# web request, or when the SDK is disabled. eval keeps a missing or broken
# Apache request object from breaking outbound HTTP requests.
sub parent_context {
	my $span;
	my $ok = eval {
		require Apache2::RequestUtil;
		my $r = Apache2::RequestUtil->request();
		if (defined $r and $r->can('pnotes')) {
			# the getter form; $r->pnotes->{KEY} reads undef in mod_perl
			$span = $r->pnotes(OTEL_SPAN_PNOTES_KEY);
		}
		defined $span;
	};
	return unless $ok;
	return eval {$span->child_of};
}

my $lwp_instrumented = 0;

# Instrument LWP::UserAgent so every outbound HTTP request:
#  - starts a CLIENT span whose parent is the current request's span
#  - injects the traceparent (and b3) headers so the far side joins the trace
#  - records the response status on the span when it completes
#
# This is the Punk equivalent of the old `OpenTelemetry::Integration
# 'LWP::UserAgent'`. Everything (get/post/head/put/delete, request, mirror,
# and the LWP::UserAgent::Plugin UA) flows through one choke point,
# LWP::UserAgent::request, so wrapping it alone covers every outbound call.
#
# The wrapper is deliberately idempotent and transparent: when the SDK is
# disabled (get_otel has no tracer) requests pass through untouched, and the
# original method is always the one that performs the network I/O.
sub install_lwp_instrumentation {
	return if $lwp_instrumented;
	$lwp_instrumented = 1;

	require LWP::UserAgent;
	no warnings 'redefine';
	my $orig = \&LWP::UserAgent::request;
	*LWP::UserAgent::request = sub {
		my ($self, $request, @rest) = @_;
		my $o = get_otel();

		my $span;
		if ($o->{tracer}) {
			my $parent = parent_context();
			$span = $o->{tracer}->start(
				$request->method . ' ' . $request->uri,
				kind => 3,
				parent => $parent
			);
		}

		if ($span) {
			$span->attr('http.method' => $request->method);
			$span->attr('http.url' => $request->uri);
			my $uri = $request->uri;
			if (UNIVERSAL::can($uri, 'host') and my $host = $uri->host) {
				$span->attr('http.host' => $host);
			}
			my $headers = Punk::OpenTelemetry::Propagate::inject($span->trace_id, $span->span_id, $span->sampled);
			$request->header($_, $headers->{$_}) for keys %$headers;
		}

		my $response;
		my $ok = eval {$response = $orig->($self, $request, @rest); 1};
		my $err = $@;

		if ($span) {
			if ($ok and defined $response) {
				$span->attr('http.status_code' => $response->code);
				# A 4xx is a failure of the call this process made (see
				# Punk::OpenTelemetry::Instrument). Success stays UNSET: a
				# wrapper has no opinion on whether the operation succeeded.
				if (!$response->is_success) {
					$span->status(2, $response->message);
				}
			}
			else {
				$span->status(2, $err // 'no response');
				$span->event('exception', {'exception.message' => $err // 'no response'});
			}
			$o->{tracer}->enqueue($span);
		}

		die $err if !$ok;
		return $response;
	};
	return;
}

sub new($class) {
	my $self = {};
	bless $self, $class;

	my $cfg = Punk::OpenTelemetry::Config::from_env();
	$self->{config} = $cfg;

	if (Punk::OpenTelemetry::Config::disabled($cfg)) {
		$self->{disabled} = 1;
		$log->info(Punk::OpenTelemetry::Config::diagnostic($cfg));
		return $self;
	}

	my $resource = Punk::OpenTelemetry::Resource::detect(
		(defined $cfg->{service_name} ? (service_name => $cfg->{service_name}) : ()),
		%{$cfg->{resource_attributes} || {}},
	);

	my ($sampler, $ratio) = _sampler($cfg);
	my $tracer = $self->{tracer} = Punk::OpenTelemetry::Tracer->new(
		resource => $resource,
		scope_name => 'OpenFoodFacts::OpenTelemetry',
		scope_version => $Punk::OpenTelemetry::VERSION,
		schema_url => Punk::OpenTelemetry::Instrument::schema_url(),
		scope_schema_url => Punk::OpenTelemetry::Instrument::schema_url(),
		sampler => $sampler,
		ratio => $ratio,
	);

	$self->{exporter} = Punk::OpenTelemetry::Exporter->new(
		(defined $cfg->{endpoint} ? (endpoint => $cfg->{endpoint}) : ()),
		(defined $cfg->{endpoints} ? (endpoints => $cfg->{endpoints}) : ()),
		(defined $cfg->{protocol} ? (protocol => $cfg->{protocol}) : ()),
		(defined $cfg->{headers} ? (headers => $cfg->{headers}) : ()),
		(defined $cfg->{compression} ? (compression => $cfg->{compression}) : ()),
		(defined $cfg->{timeout} ? (timeout => $cfg->{timeout} / 1000) : ()),
		(defined $cfg->{ua} ? (ua => $cfg->{ua}) : ()),
	);

	$self->{meter} = Punk::OpenTelemetry::Meter->new(
		resource => $resource,
		scope_name => 'OpenFoodFacts::OpenTelemetry',
		temporality => $cfg->{temporality_preference} || 'cumulative',
	) if _want($cfg, 'metrics');

	$self->{logs} = Punk::OpenTelemetry::Logs->new(
		resource => $resource,
		scope_name => 'OpenFoodFacts::OpenTelemetry',
	) if _want($cfg, 'logs');

	return $self;
}

sub flush {
	my ($st) = @_;
	return unless $st->{exporter};

	# ONE EVAL PER SIGNAL, not one around all three.
	#
	# A single eval means the first signal that throws takes the other two
	# with it - and the drain that never ran leaves its records queued, so
	# they are not even lost loudly. That is how metrics failing to encode
	# silently stopped logs from being exported at all: two signals gone to
	# one broken encoder, with nothing in the output to say so.
	my @futures;
	eval {
		if (my $t = $st->{tracer}) {my $p = $t->drain; my $f = _send($st, traces => $p); push @futures, $f if $f}
		1;
	}
		or do {$st->{exporter}{stats}{failures}++};
	eval {
		if (my $m = $st->{meter}) {my $p = $m->collect; my $f = _send($st, metrics => $p); push @futures, $f if $f}
		1;
	}
		or do {$st->{exporter}{stats}{failures}++};
	eval {
		if (my $l = $st->{logs}) {my $p = $l->drain; my $f = _send($st, logs => $p); push @futures, $f if $f}
		1;
	}
		or do {$st->{exporter}{stats}{failures}++};

	# AWAIT THE EXPORTS. The request has only been started by the time the
	# ua's future exists; nothing pumps the export to its reply. That is the
	# right shape for a long-lived event loop that will run the future, and
	# the wrong one for mod_perl - which has no loop driving it, so a flush
	# nobody awaits is a request nobody sends. In a child-exit handler the
	# process dies a moment later and the queued telemetry dies with it.
	# Awaiting is the honest read of "flush": block until the attempt settles
	# (bounded by the exporter timeout), then report what came back.
	for my $f (@futures) {
		eval {$f->get} or do {$st->{exporter}{stats}{failures}++};
	}
	return;
}

# The request-thread counterpart of the plugin's after-dispatch tick. Product
# Opener has no persistent background loop (and mod_perl prefork workers see
# few requests each), so the request that just enqueued its spans is the only
# tick there will ever be: flush whatever is queued. Flush blocks on its
# exports, so the block is bounded by whatever OTEL_BSP_EXPORT_TIMEOUT and
# OTEL_EXPORTER_OTLP_TIMEOUT are configured to.
sub tick {
	my ($st) = @_;
	my $t = $st->{tracer} or return;

	# Batch flushing exists to amortize the transport cost across many spans,
	# which requires a background loop to ever emit them; without one, a batch
	# that misses its tick stays queued until a worker happens to get a second
	# request more than schedule_delay later. End-of-request export is the
	# whole transport here.
	return if $t->queued < 1;
	$st->flush();
	return;
}

sub _send {
	my ($st, $signal, $payload, $attempt) = @_;
	$attempt //= 0;
	my $exp = $st->{exporter};
	my $stats = $exp->{stats};

	Punk::OpenTelemetry::Instrument::suppress_begin();
	my ($bytes, $f);
	my $ok = eval {
		$bytes = $exp->encode($signal => $payload);
		$f = $exp->_attempt($signal, $bytes);
		1;
	};
	my $err = $@;
	Punk::OpenTelemetry::Instrument::suppress_end();
	die $err if !$ok;
	return unless $f;

	$f->on_ready(
		sub {
			my ($fut) = @_;
			my $res = eval {$fut->get};
			my ($verdict, $after)
				= $res
				? $exp->_classify($res->status, $res->headers, $res->content)
				: $exp->_classify(undef);

			if ($verdict eq 'ok') {$stats->{exported}++}
			elsif ($verdict eq 'partial') {$stats->{exported}++; $stats->{partial}++}
			elsif ($verdict eq 'permanent') {
				$stats->{rejected}++;
				$stats->{dropped}++;
			}
			elsif ($attempt >= ($exp->{max_retries} // 5)) {
				$stats->{failures}++;
				$stats->{dropped}++;
			}
			else {
				$stats->{retries}++;
				my $wait = $exp->backoff($attempt + 1, $after);
				$exp->_sleep($wait, sub {_send($st, $signal, $payload, $attempt + 1)});
			}
			return;
		}
	);
	return $f;
}

sub _sampler {
	my ($cfg) = @_;
	my $name = $cfg->{sampler} // 'parentbased_always_on';
	my $arg = $cfg->{sampler_arg};
	my $ratio = defined $arg && $arg =~ /^[0-9.]+$/ ? $arg + 0 : 1.0;

	return ('always_off', $ratio)
		if $name eq 'always_off' || $name eq 'parentbased_always_off';
	return ('always_on', $ratio)
		if $name eq 'always_on';
	return ('parent_ratio', $ratio);
}

sub _want {
	my ($cfg, $what) = @_;
	return 1 unless exists $cfg->{$what};
	return $cfg->{$what} ? 1 : 0;
}

1;
