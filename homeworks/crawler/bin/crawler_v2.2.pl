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


my @status = (
    'No Content-Length header',
    "Reached max count of urls",
    'Standart exit'
    );


my $MAX_PAGES_COUNT = 1000;

my $work_count = 0;

my $cv = AnyEvent::condvar;

my $async; $async = sub  {
    my ($host) = @_;
    my %guards;
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
	warn "PROCESSING Number: $work_count";
	$guards{$work_count} = http_get $fulladdr, sub {
	    my $ournumber = $work_count;
	    $work_count++;
	    my ($body, $headers) =@_;
	    $urls{sumsize} += length $body;
	    $urls{$fulladdr} = length $body;
	    my $refs = find_refs($host, $body);
	    push (@urls, @$refs);
	    warn "PROCESSED Number: $ournumber";
	    p @urls;
	    $async->($host);
	    $cv->end();
	    $work_count--;
	    return;
	};
    }
};

$async->($host);
$cv->recv();





