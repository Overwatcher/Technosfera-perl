package Local::Crawler;

use strict;
use warnings;
no warnings 'experimental';
use AnyEvent;
use AnyEvent::HTTP;
use Mojo::DOM;
use Exporter 'import';

our @EXPORT = qw(sorting find_refs) ;

sub sorting {
    my $hash = shift;
    my @sorted = sort { $$hash{$b} <=> $$hash{$a} } keys %$hash;
    return \@sorted;
}

sub find_refs {
    my ($host, $body) = @_;
    my $dom = Mojo::DOM->new( $body );
    my @refs;
    my $a_elements1 = $dom->find( 'a[href^="/"]' );
    my $a_elements2 = $dom->find ( qq( a[href^="http://"] ) );
    my $cuthost = ( $host =~ s{(http://)}{}r );
    
    for (@$a_elements1) {
	if ($_->attr( 'href' )  =~ m{^//(?:www.)?$cuthost(\/.*)} ) {
	    my $url = $1;
	    $url =~ s{/$}{};
	    push (@refs, $url);
	    next;
	}
	if ($_->attr( 'href' ) =~ m{^//}) {next;}
	my $url = $_->attr('href');
	$url =~ s{/$}{};
	push( @refs, $url );
    }
    
    for (@$a_elements2) {
	if ($_->attr( 'href' ) =~ m{http://(?:www.)?$cuthost(\/.*)} ) {
	    my $url = $1;
	    $url =~ s{/$}{};
	    push (@refs, $url);
	    next;
	}
    }

    return \@refs;
    
    
}
sub min {
    my ($x, $y) = @_;
    if ($x <= $y) { return $x; }
    else { return $y; }
}

