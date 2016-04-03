package Local::Iterator::Concater;

use strict;
use warnings;

use Moose;

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
sub all {
	my $self = shift;
	my @all;
	my $iterators = $self->get_iterators;
	my ($val, $end);
	my $count = 1;
	for my $iter (@$iterators) {
		($val, $end) = $iter->next();
		if (!defined $val and $end == 1 and $count == scalar(@$iterators)) {
			return \@all;
		}
		if (!defined $val and $end == 1) {
			next;
		}
		push (@all, $val);
		redo;
	} continue {$count++;}
	return \@all;
}

1;
