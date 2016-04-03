package Local::Iterator;

use strict;
use warnings;

use Moose;

#sub next {

#...;

#}

sub all {
	my $self = shift;
	my @all;
	my ($val, $end);
	$end = 0;
	while (!$end) {
		($val, $end) = $self->next();
		if ($end != 1) {push(@all, $val);}
	}
	return \@all;
}
1;
