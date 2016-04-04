package Local::App::GenCalc;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Fcntl qw(:flock :seek);
use Local::App::GenTask 'gentask';
use POSIX ":sys_wait_h";
use Encode;
use IO::Socket;
use IO::Select;
use Time::HiRes 'ualarm';
use Exporter 'import';
our @EXPORT= qw(start_server get);
#our @EXPORT;

our $file_path = './calcs.txt';
open (my $FH, "+>>:encoding(UTF-8)", $file_path) or die "$!";

our %kids;

$SIG{ALRM} = \&myalarm;

$SIG{INT} = \&myint;

$SIG{CHLD} = \&mychld;

sub myalarm {
	flock ($FH, LOCK_EX);
	seek($FH, 0, SEEK_END);

	if (-s $file_path > 1024*10) {exit 1;}
	print $FH gentask();
	print $FH "\n";
	flock ($FH, LOCK_UN);
	ualarm(100000);
}



sub myint {
	for my $pid (keys %kids) {
		kill ('TERM', $pid);
	}
	close $FH;
	unlink $file_path;
	return exit 1;
}

sub mychld {
	while (my $pid = waitpid(-1, WNOHANG)) {
		last if $pid == -1;
		if ($? >> 8) {close $FH; unlink $file_path; exit 1;}
	}
}
sub start_server {
	my $port = shift;
	my $server = IO::Socket::INET->new(
		LocalPort => $port,
		Type => SOCK_STREAM,
		ReuseAddr => 1,
		Listen => 10)
	or die "Can't create server on port $port : $@ $/";
	open (my $FH, '+>', $file_path) or die "$!";
	my $pid = fork();
	if (!defined $pid) {die "Unable to fork at GenCalc";}
	if (!$pid) {ualarm(100000); while (1) {}}
	$kids{$pid} = 1;
	while (my $client = $server -> accept()) {
		$client->autoflush(1);
		my @ready = IO::Select->new($client)->can_read;
		$client = $ready[0];
		my $amount;
		if (2 != read($client, $amount, 2) ) {close $client; next;}
		$amount = unpack ("s", $amount);
		my $get = get($amount);
		print $client pack("l", scalar(@$get));
		for my $out (@$get) {
			print $client pack("l/a*", $out);
		}
		close $client;
	}
}

sub get {
	my $limit = shift;
	my $length = 0;
	my @out;
	my $ret =[];
	my @test;
	while (1) {
		flock($FH, LOCK_EX);
		seek($FH, 0, SEEK_SET);
		@out = <$FH>;
		if (scalar(@out) == $limit) {
			for (@out) {
				$length += length(Encode::encode_utf8($_));
			}
		}
		else {flock($FH, LOCK_UN); redo;}
		seek($FH, 0, SEEK_SET);
		truncate ($FH, $length);
		flock ($FH, LOCK_UN);
		last;
	}
	return \@out;
}
1;
