use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Local::Crawler;
use AnyEvent::HTTP;
use AnyEvent;
use Mojo::DOM;
use Getopt::Long;
use DBI;
use DDP;
$AnyEvent::HTTP::MAX_PER_HOST = 100;
my $MPH = $AnyEvent::HTTP::MAX_PER_HOST;
my $host = shift @ARGV;
my %urls = (
    sumsize => 0,
    );

my @urls= ('/');





my $MAX_PAGES_COUNT = 201;

my $work_count = 0;

my $cv = AnyEvent::condvar;


my $async; $async = sub  {
    my ($host) = @_;
    while ($work_count <= $MPH) {
	my $url = shift @urls;
	if (!defined $url) {
	    last;
	}
	my $fulladdr = $host . $url;
	if ( exists $urls{$fulladdr} ) {
	    next;
	}
	$urls{$fulladdr} = undef;
	$cv->begin();
	$work_count++;
	warn "PROCESSING Number: $work_count";
	http_get $fulladdr, sub {
	    my $ournumber = $work_count;
	    my ($body, $headers) = @_;
	    $urls{$fulladdr} = length $body;
	    if (!defined $urls{$fulladdr}) {
		delete $urls{$fulladdr};
		$cv->end();
		return ;
	    }
	    $urls{sumsize} += $urls{$fulladdr};
	    my $refs = find_refs($host, $body);
	    push (@urls, @$refs);
	    warn "PROCESSED Number: $ournumber";
	    $work_count--;
	    p %urls;
	    if ( (my $size = keys %urls) >= $MAX_PAGES_COUNT) {
		$cv->end();
		return ;
	    }
	    $async->($host);
	    $cv->end();
	    

	    return;
	};
    }
};

$cv->begin;
$async->($host);
$cv->end;
$cv->recv();

my $sorted = sorting(\%urls);
my @keys = keys %urls;
p @keys;
my $count = 0;
for (@$sorted) {
    if ($_ eq 'sumsize') {
	print "\nSummary size is $urls{$_} bytes\n";
	next;
    }
    print "\nPage : $_; Size : $urls{$_} bytes\n";
    $count++;
    if ($count == 10) { last; }
}
    






