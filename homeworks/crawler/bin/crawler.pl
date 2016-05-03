use strict;
use warnings;
#use FindBin 'Bin';
#use lib "$FindBin\..\lib";
#use Local::Crawler;
use AnyEvent::HTTP;
use AnyEvent;
use Mojo::DOM;
use Getopt::Long;
use DBI;
use DDP;
$AnyEvent::HTTP::MAX_PER_HOST = 100;
my $host = shift @ARGV;

my %urls = (
    sumsize => 0,
    );

my @status = (
    'No Content-Length header',
    'Reached 10000 urls',
    'Standart exit'
    );


my $MAX_PAGES_COUNT = 1000;


sub wrap_http_get {
    my ($host, $arguris) = @_;
    my $cv = AnyEvent->condvar;
    my $status = -1;
    my %uris;
    for my $uri (@$arguris) {
	$cv->begin();
	my $fulladdr = $host . $uri;
	$fulladdr =~ s{\/$}{};
	http_get $fulladdr, timeout => 7, sub {
	    my ($body, $headers) = @_;

	    if (!defined $headers->{'content-length'}) {
		warn "content-lenght unavailabe";
		p $headers;
		$cv->end();
		return ;
	    }
	    if (defined $urls{$fulladdr}) {
		$cv->end();
		return ;
	    }
	    $urls{$fulladdr} = 0 + $headers->{'content-length'};
	    $urls{sumsize} += $urls{$fulladdr};
	    if ( scalar ( @$arguris ) >= ( $MAX_PAGES_COUNT - scalar ( keys %urls ) ) ) {
		$cv->end();
		return ;
	    }
	    my $dom = Mojo::DOM->new( $body );
	    my $a_elements = $dom->find( 'a[href^="/"]' );
	    my $howmany = scalar @$a_elements;
	    for (@$a_elements) {

		my $href = $_->attr('href');
		my $newaddr = $host . $href;
		$newaddr =~ s{\/$}{};
		if ( defined $urls{$newaddr} ) {next;}
		if ( scalar(keys %urls) >= $MAX_PAGES_COUNT ) {
		    $status = 1;
		    last;
		}
		$uris{$href} = 1;
		my $NEWHREFS = scalar(keys %uris);
		my $OLDHREFS = scalar(keys %urls);
		warn "THERE ARE $NEWHREFS NEW REFS and $OLDHREFS OLD REFS";
		if (scalar(keys %uris) >= $MAX_PAGES_COUNT -scalar(keys %urls) ) {
		    $status = 3;
		    last;
		}
	    }
	    $cv->end();
	    if ($status == 3 or $status == 1) { $cv->send(); }
	};
    }
    $cv->recv();
    #не получается передать ссылку на keys %uris, поэтому делаю это нерациональное копирование.
    my @urisref = keys %uris;
    if ($status == 1) { return 1; }
    if (scalar (@urisref) == 0) { return 2; }
    p @urisref;
    wrap_http_get ($host, \@urisref);
}

sub _sorting {
    my $hash = shift;
    my @sorted = sort { $$hash{$b} <=> $$hash{$a} } keys %$hash;
    return \@sorted;
}

my $status = wrap_http_get( $host, ['/']);
print "\nStatus : $status[$status]\n";
my $sorted = _sorting(\%urls);
my $count = 0;
my @keys = keys %urls;
p @keys;
for (@$sorted) {
    if ($_ eq 'sumsize') {
	print "\nSummary size is $urls{$_} bytes\n";
	next;
    }
    print "\nPage : $_; Size : $urls{$_} bytes\n";
    $count++;
    if ($count == 10) { last; }
    
}
    
