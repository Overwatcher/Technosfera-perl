package Local::Iterator::Array;

use strict;
use warnings;


use Moose;

extends 'Local::Iterator';

has array => (
	is =>'ro',
	isa => 'ArrayRef'
);

has _temp => (
	is =>'rw',
	isa =>'ArrayRef'
);

sub BUILD {
	my $self = shift;
	my $temp;
	my $ref = $self->array;
	for (@$ref) {
		push(@$temp, $_);
	}
	$self->_temp($temp);
}

sub next {
	my $self = shift;
	my ($val, $end, $temp);
	$end = 0;
	$temp = $self->_temp;
	return (undef, 1)  unless scalar(@$temp);
	return (shift @$temp, $end);
}

1;
