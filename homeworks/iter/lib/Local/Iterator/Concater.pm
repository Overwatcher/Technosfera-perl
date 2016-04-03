package Local::Iterator::Concater;

use strict;
use warnings;

use Moose;

extends 'Local::Iterator';

has iterators => (
	is => 'ro',
	isa => 'ArrayRef[Object]',
	reader => 'get_iterators'
);

sub next {
	my $self = shift;
	my $iterators = $self->get_iterators;
	my ($val, $end, $count);
	$count = 1;
	for my $iter (@$iterators) {
		($val, $end) = $iter->next();
		if (!defined $val and $end == 1 and $count == scalar(@$iterators)) {
			return (undef, 1);
		}
		if (!defined $val and $end == 1) {
			next;
		}
		return ($val, 0);
	} continue {$count++;}
}


1;
