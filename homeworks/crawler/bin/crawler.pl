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
    "Reached max count of urls",
    'Standart exit'
    );


my $MAX_PAGES_COUNT = 500;


sub wrap_http_get {
    my ($host, $arguris) = @_;
    my $cv = AnyEvent->condvar;
    my $status = -1;
    my %uris;
    my $urlcount = scalar (@$arguris);
    my $ournumber = 0;
    my %guards;
    for my $arguri (@$arguris) {
	$cv->begin();
	my $number = $ournumber + 1;
	$ournumber ++;
	my $fulladdr = $host . $arguri;
	$fulladdr =~ s{\/$}{};
        $guards{$number} = http_get $fulladdr, timeout => 7, sub {
	    my ($body, $headers) = @_;
	    p $number;
	    if (!defined $headers->{'content-length'}) {
		warn "content-length unavailabe";
		p $headers;
		$urlcount--;
		print "\n$urlcount\n";
		delete $guards{$number};
		$cv->end();
		return ;
	    }
	    if (defined $urls{$fulladdr}) {
		$urlcount--;
		print "\n$urlcount\n";
		delete $guards{$number};
		$cv->end();
		return ;
	    }
	    $urls{$fulladdr} = 0 + $headers->{'content-length'};
	    $urls{sumsize} += $urls{$fulladdr};
	    print "\nTOTAL COUNT : " . scalar (keys %urls) . "\n";
	    if ( scalar (keys %urls) >= $MAX_PAGES_COUNT ) {
	        for (keys %guards) { delete $guards{$_}; $cv->end();}
		$status = 1;
		return ;
	    }
	    my $hrefs = find_refs( $host, $body);
	    my $it = 0;
	    
	    for my $href (@$hrefs) {
		print "\nPROCESS : $number ( $it )\n";
		my $newaddr = $host . $href;
		$newaddr =~ s{\/$}{};
		if ( defined $urls{$newaddr} ) {next;}
		$uris{$href} = 1;
	    } continue {$it++;}
	    $urlcount--;
	    print "\n$urlcount\n";
	    delete $guards{$number};
	    $cv->end();
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

sub find_refs {
    my ($host, $body) = @_;
    my $dom = Mojo::DOM->new( $body );
    my @refs;
    my $a_elements1 = $dom->find( 'a[href^="/"]' );
    my $a_elements2 = $dom->find ( qq( a[href^="http://"] ) );
    my $cuthost = ( $host =~ s{(http://)}{}r );
    
    for (@$a_elements1) {
	if ($_->attr( 'href' )  =~ m{^//(?:www.)?$cuthost(\/.*)} ) {
	    push (@refs, $1);
	    next;
	}
	if ($_->attr( 'href' ) =~ m{^//}) {next;}
	push( @refs, $_->attr ('href') );
    }
    
    for (@$a_elements2) {
	if ($_->attr( 'href' ) =~ m{http://(?:www.)?$cuthost(\/.*)} ) {
	    push (@refs, $1);
	    next;
	}
    }

    return \@refs;
    
    
}

my $status = wrap_http_get( $host, ['/']);
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

print "\nStatus : $status[$status]\n";
    
