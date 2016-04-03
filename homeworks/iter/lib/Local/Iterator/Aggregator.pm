package Local::Iterator::Aggregator;

use strict;
use warnings;

use Moose;

extends 'Local::Iterator';

has chunk_length => (
	is => 'ro',
	isa => 'Int',
	reader => 'get_chunk_length'
);

has iterator => (
	is => 'ro',
	isa => 'Object',
	reader => 'get_iterator'
);


sub next {
	my $self = shift;
	my @chunk;
	my $ch_l = $self->get_chunk_length;
	my $iterator = $self->get_iterator;
	my ($end, $val);
	$end = 0;
	for (1..$ch_l) {
		($val, $end) = $iterator->next();
		last if ($end == 1);
		push (@chunk, $val);
	}
	return (undef, 1) unless (@chunk);
	return (\@chunk, 0);
}


1;
