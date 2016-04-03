package Local::Iterator::File;

use strict;
use warnings;

use Moose;

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
	elsif ($self->has_fh) {return $fh;}
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

sub all {
	my $self = shift;
	my $fh = $self->get_fh;
	my $str;
	my @ret;
	while ($str = <$fh>) {
		chomp $str;
		push (@ret, $str);
	}
	return \@ret;
}
1;
