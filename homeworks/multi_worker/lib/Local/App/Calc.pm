package Local::App::Calc;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use IO::Socket;
use IO::Select;
use Local::App::Evaluate 'evaluate' ;
use Exporter 'import';
use POSIX ":sys_wait_h";

our @EXPORT_OK = 'start_server';

$SIG{CHLD} = \&mychld;
$SIG{INT} = \&myint;
our %kids;
sub mychld {
	while (my $pid = waitpid(-1, WNOHANG)) {
		last if $pid == -1;
		if ($? >> 8) {exit 1;}
	}
}

sub myint {
	for my $pid (keys %kids) {
		kill ('TERM', $pid);
	}
	exit 0;
}

sub start_server {
	my $port = shift;
	my $server = IO::Socket::INET->new (
		LocalPort => $port,
		Type => SOCK_STREAM,
		ReuseAddr => 1,
		Listen => 5
	);
	my $client;
	my $child;
	while ($client = $server->accept()) {
		$child = fork();
		if ($child) {
			$kids{$child} = 1;
			next;
		}
		if (defined $child) {last;}
		exit 1;

	}
	if (!$child) {
		while (my @ready = IO::Select->new($client)->can_read) {
			my $ready = $ready[0];
			exit 0 unless (read($ready,my $len, 4)); 
			$len = unpack ("l", $len);
			read($ready, my $task, $len);
			$task = unpack ("a*", $task);
			my $res = evaluate($task);
			print $ready pack("l/a", $res);
		}
		close $client;
		exit 0;
	}
}
1;

