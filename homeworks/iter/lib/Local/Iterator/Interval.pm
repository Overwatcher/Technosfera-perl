package Local::Iterator::Interval;

use strict;
use warnings;
#use Clone;
use Local::Interval;

use DateTime;
use DateTime::Duration;

use Moose;

has from => (
	is => 'rw',
	isa => 'Object',
	writer => '_set_from',
	required => 1
);
has to => (
	is => 'ro',
	isa => 'Object',
	required => 1
);
has step => (
	is => 'ro',
	isa => 'Object',
	required => 1
);
has length =>(
	is => 'ro',
	isa => 'Object',
	lazy => 1,
	builder => '_build_length'
);

sub BUILD {
	my $self = shift;
	my $from = $self->from->clone;
	$self->_set_from($from);
}

sub _build_length {
	my $self = shift;
	return $self->step;
	
}

sub next {
	my $self = shift;
	my $from = $self->from;
	my $fromtemp1 = $from->clone;
	my $fromtemp = $from->clone;
	my $step = $self->step;
	my $length = $self->length;
	my $next = $fromtemp1->add($length);
	my $to = $self->to;
	my $cmp = DateTime->compare( $next, $to );
	my $end = 0;
	$end = 1 if ($cmp == 1 or $cmp == 0);
	my $ret = Local::Interval->new(from => $fromtemp, to => $next);
	$self->_set_from($from->add($step));
	return ($ret, $end);
}
1;
