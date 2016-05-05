package Local::App::Calc;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use IO::Socket;
use IO::Select;
use DDP;
use Local::App::Evaluate 'evaluate' ;
use Exporter 'import';
use POSIX ":sys_wait_h";

our @EXPORT_OK = 'start_server';

$SIG{CHLD} = \&mychld;
$SIG{INT} = \&myint;
our %kids;
our $chld;
sub mychld {
	while (my $pid = waitpid(-1, WNOHANG)) {
		last if $pid == -1;
		if ($? >> 8) {exit 1;}
		$kids{$pid} = -1;
		$chld = 1;
	}
}

sub myint {
	for my $pid (keys %kids) {
		kill ('TERM', $pid);
	}
	exit 0;
}

sub start_server {
	$SIG{CHLD} = \&mychld;
	my $port = shift;
	my $server = IO::Socket::INET->new (
		LocalPort => $port,
		Type => SOCK_STREAM,
		ReuseAddr => 1,
		Listen => 10)
	or die "Can't create server on port $port : $@ $/";
	my $client;
	my $child = 1;
	while (1) {
		while ($client = $server->accept()) {
			$child = fork();
			if ($child) {
				print STDERR "$client - $child\n";
				$kids{$child} = 1;
				next;
			}
			if (defined $child) {last;}
			die "Couldn't fork";

		}
		if ($child == 0) {last;}
		if ($chld) {p %kids; $chld = 0; next;}
		exit 0;
	}
	if (!$child) {
		while (1) {
			my $len;
			my $actlen;
			if (4 >  sysread( $client, $len, 4 ) ) {close $client; exit 0;}
			$len = unpack ("l", $len);
			$actlen = sysread($client, my $task, $len);
			if ($actlen != $len)  { close $client; exit 0; }
			$task = unpack ("a*", $task);
			if ($task eq "END") {
				close $client;
				exit 0;
			}
			my $res = evaluate($task);
			$res = pack ("l/a", $res);
			$len = length $res;
			syswrite($client, $res, $len);
		}
		close $client;
		exit 0;
	}
}
1;
