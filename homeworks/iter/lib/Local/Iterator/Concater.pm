package Local::Iterator::Concater;

use strict;
use warnings;

use Moose;

extends 'Local::Iterator';

has iterators => (
	is => 'ro',
	isa => 'ArrayRef[Object]'
);

sub next {
	my $self = shift;
	my $iterators = $self->iterators;
	my ($val, $end, $count);
	$count = 1;
	for my $iter (@$iterators) {
		($val, $end) = $iter->next();
		next if (!defined $val and $end == 1);
		return ($val, 0);
	}
	return (undef, 1);
}


1;
