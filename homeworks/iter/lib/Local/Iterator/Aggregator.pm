package Local::Iterator::Aggregator;

use strict;
use warnings;

use Moose;

has chunk_length => (
	is => 'rw',
	isa => 'Int',
	writer => 'set_chunk_length',
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
		return (undef, $end) if (!defined $val and $_ == 1 and $end == 1);
		return (\@chunk, $end) if (!defined $val and $end == 1); 
		push (@chunk, $val);
	}
	return (\@chunk, $end);
}

sub all {
	my $self = shift;
	my @chunks;
	my ($chunk, $end);
	$end = 0;
	while (!$end) {
		($chunk, $end) = $self->next();
		push (@chunks, $chunk);
	}
	
	return \@chunks;
}

1;
