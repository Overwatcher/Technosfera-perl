package Local::Iterator::File;

use strict;
use warnings;

use Moose;

extends 'Local::Iterator';

has fh => (
	is => 'ro',
	isa => 'FileHandle',
	builder => '_build_fh',
	lazy => 1
);

has filename => (
	is => 'ro',
	isa => 'Str',
	predicate => 'has_filename'
);

sub _build_fh {
	my $self = shift;
	my $fh;
	if ( $self->has_filename ) {
		open ($fh, '<', $self->filename) or die "$!";
	}
	return $fh;
}

sub next {
	my $self = shift;
	my $fh = $self->fh;
	my $str;
	$str = <$fh>;
	return ($str, 1) if !defined $str;
	chomp $str;
	return ($str, 0);
}


1;
