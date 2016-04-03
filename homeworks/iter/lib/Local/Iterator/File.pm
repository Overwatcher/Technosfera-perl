package Local::Iterator::File;

use strict;
use warnings;

use Moose;

extends 'Local::Iterator';

has fh => (
	is => 'rw',
	isa => 'FileHandle',
	reader => 'get_fh',
	writer => 'set_fh',
	predicate => 'has_fh',
	builder => '_build_fh',
	lazy => 1
);

has filename => (
	is => 'ro',
	isa => 'Str',
	reader => 'get_filename',
	predicate => 'has_filename'
);

sub _build_fh {
	my $self = shift;
	my $fh;
	if ( $self->has_filename ) {
		open ($fh, '<', $self->get_filename) or die "$!";
	}
	return $fh;
}

sub next {
	my $self = shift;
	my $fh = $self->get_fh;
	my $str;
	$str = <$fh>;
	return ($str, 1) if !defined $str;
	chomp $str;
	return ($str, 0);
}


1;
