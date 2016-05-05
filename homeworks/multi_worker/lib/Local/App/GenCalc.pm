package Local::App::GenCalc;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Fcntl qw(:flock :seek);
use POSIX ":sys_wait_h";
use Encode;
use IO::Socket;
use IO::Select;
use Time::HiRes 'ualarm';
use Exporter 'import';
our @EXPORT= qw(start_server get);
#our @EXPORT;

our $file_path = './calcs.txt';


our $alarmed;


$SIG{ALRM} = \&myalarm;

$SIG{INT} = \&myint;


sub myalarm {
    new_one();
    if (-s $file_path > 1024*1024) { unlink $file_path; exit 0;}
    $alarmed = 1;
    ualarm(100000);
}



sub myint {
    unlink $file_path;
    return exit 0;
}


sub new_one {
    # Функция вызывается по таймеру каждые 100
    my $new_row = join $/, int(rand(5)).' + '.int(rand(5)), 
    int(rand(2)).' + '.int(rand(5)).' * '.int(int(rand(10))), 
    '('.int(rand(10)).' + '.int(rand(8)).') * '.int(rand(7)), 
    int(rand(5)).' + '.int(rand(6)).' * '.int(rand(8)).' ^ '.int(rand(12)), 
    int(rand(20)).' + '.int(rand(40)).' * '.int(rand(45)).' ^ '.int(rand(12)), 
    (int(rand(12))/(int(rand(17))+1)).' * ('.(int(rand(14))/(int(rand(30))+1)).' - '.int(rand(10)).') / '.rand(10).'.0 ^ 0.'.int(rand(6)),  
    int(rand(8)).' + 0.'.int(rand(10)), 
    int(rand(10)).' + .5',
    int(rand(10)).' + .5e0',
    int(rand(10)).' + .5e1',
    int(rand(10)).' + .5e+1', 
    int(rand(10)).' + .5e-1', 
    int(rand(10)).' + .5e+1 * 2';
    open (my $FH, "+>>:encoding(UTF-8)", $file_path) or die "$!";
    flock ($FH, LOCK_EX);
    seek($FH, 0, SEEK_SET);
    print $FH $new_row;
    flock ($FH, LOCK_UN);
    close $FH;
    return;
}

sub start_server {
    my $port = shift;
    my $server = IO::Socket::INET->new(
	LocalPort => $port,
	Type => SOCK_STREAM,
	ReuseAddr => 1,
	Listen => 10)
	or die "Can't create server on port $port : $@ $/";
    ualarm(100000);
    while (1) {
	while (my $client = $server -> accept()) {
	    $client->autoflush(1);
	    my $amount;
	    if (2 != sysread($client, $amount, 2) ) {close $client; next;}
	    $amount = unpack ("s", $amount);
	    my $get = get($amount);
	    print $client pack("l", scalar(@$get));
	    for my $out (@$get) {
		$out = pack ("l/a*", $out);
		my $len = length $out;
		my $actlen = syswrite( $client, $out, $len );
		if ($actlen != $len) { last; }
	    }
	    close $client;
	}
	if ($alarmed) {$alarmed = 0; next;}
    }
}

sub get {
    my $limit = shift;
    my $count;
    my $length = 0;
    my @out;
    my @test;
    open (my $FH, "<:encoding(UTF-8)", $file_path) or die "$!";
    flock ($FH, LOCK_EX);
    for (1..$limit) {
	my $job  = <$FH>;
	if (!defined $job) {last;}
	chomp $job;
	push (@out, $job);
    }
    my @tocopy = <$FH>;
    open (my $tempFH, ">", "./temp.txt") or die "$!";
    for my $str (@tocopy) {print $tempFH $str;}
    unlink $file_path;
    rename "temp.txt", "calcs.txt";
    flock ($FH, LOCK_UN);
    close $FH;
    close $tempFH;
    return \@out;
}

END {
    unlink $file_path;
};
1;
