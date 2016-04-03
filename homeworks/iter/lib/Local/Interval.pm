package Local::Interval;

use strict;
use warnings;

use Moose;

has from => (
	is => 'ro',
	isa => 'Object'
);

has to => (
	is => 'ro',
	isa => 'Object'
);

1;

