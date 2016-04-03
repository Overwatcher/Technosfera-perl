package Local::Iterator::Array;

use strict;
use warnings;

use Moose;

extends 'Local::Iterator';

has array => (
	is =>'ro',
	isa => 'ArrayRef',
	reader => 'get_array'
);

has temp => (
	is =>'rw',
	isa =>'ArrayRef',
	reader => 'get_temp',
	writer => 'set_temp',
	predicate => 'has_temp',
	clearer => 'clear_temp'
);

sub BUILD {
	my $self = shift;
	my @temp;
	my $ref = $self->get_array;
	for (@$ref) {
		push (@temp, $_);
	}
	$self->set_temp(\@temp);
}

sub next {
	my $self = shift;
	my ($val, $end, $temp);
	$end = 0;
	$temp = $self->get_temp;
	$val = shift @$temp;
	if (!defined $val and scalar(@$temp) == 0) {
		$end = 1; 
		$self->set_temp([undef]);
	}
	return ($val, $end);
}

1;
