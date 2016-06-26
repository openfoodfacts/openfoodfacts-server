package Blogs::PointRepartition;
use strict;
use warnings FATAL => 'all';
use Math::Random qw(:all);
use Math::Trig;
use Math::Trig ':pi';

# The algorithm below is strongly inspired from the one available here:
# http://stackoverflow.com/questions/5408276/sampling-uniformly-distributed-random-points-inside-a-spherical-volume
# This is here a repartition on a disk instead on a sphere (1 angle required and 2 coordinates)
# Conversion in Perl using the Math:Random:Uniform:
#   http://search.cpan.org/~grommel/Math-Random-0.70/Random.pm

sub new
{
    # Usage : new PointRepartition(int nb_particles)
    my $class = shift;
    my $self = {
        nb_particles => shift
    };

    bless $self, $class;

    return $self;
}

sub new_positions_disc_coordinates {
    my ( $self ) = @_;
    my $number_of_particles = $self->{nb_particles};
    my @radius = Math::Random::random_uniform ($number_of_particles, 0, 1);
    my @theta = Math::Random::random_uniform ($number_of_particles, -1, 1);
    my @x = ();
    my @y = ();
    my $nb_items = @radius;
    for (my $i = 0; $i < $nb_items; $i++)
    {
        push (@x, $radius[$i] * sin($theta[$i] * Math::Trig::pi));
        push (@y, $radius[$i] * cos($theta[$i] * Math::Trig::pi));
    }

    my @ret = ();
    $ret[0] = \@x;
    $ret[1] = \@y;

    return @ret;
}
1;