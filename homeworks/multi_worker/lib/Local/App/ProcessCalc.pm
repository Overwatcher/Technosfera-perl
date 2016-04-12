package Local::App::ProcessCalc;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use DDP;
use Fcntl qw(:flock :seek);
use IO::Socket;
use IO::Select;
use POSIX ":sys_wait_h";
use Exporter 'import';
our @EXPORT = qw(multi_calc get_from_server);
our $status_file = "./calc_status.txt";
our %kids;
$SIG{CHLD} = \&mychld;

sub mychld {
	while (my $pid = waitpid(-1, WNOHANG)) {
		last if $pid == -1;
		if ($? >> 8) {
			myint();
		}
		else {
			$kids{$pid} = 0;
		}
	}
}

$SIG{INT} = \&myint;

sub myint {
	for my $pid (keys %kids) {
		unlink ("./results_$pid.txt");
		kill ('TERM', $pid);
	}
	unlink $status_file;
	exit 1;
}

sub _check_resp {
	my ($handle, $expect) = @_;
	my $response;
	while (my @ready = IO::Select->new($handle)->can_read) {
		my $ready = $ready[0];
		if (!defined $ready) {next;}
		unless (read($ready, $response, 4)) {next;}
		$response = unpack ("l", $response);
	}
	return 1 if $response == $expect;
	return 0;
}

sub calc_jobs {
	my ($socket, $jobs, $FH, $pid, $count) = @_;
	for my $job (@$jobs) {
		print $socket pack("l/a*", $job);
		my @ready = IO::Select->new($socket)->can_read;
		my $ready = $ready[0];
		read($ready, my $len, 4);
		$len = unpack ("l", $len);
		read($ready, my $res, $len);
		$res = unpack ("a*", $res);
		print $FH "$res\n";
		$$count++;
		status_update($pid, 1, $$count);
	}
	return 1;
}
sub multi_calc {
	$SIG{CHLD} = \&mychld;
	my ($fork_cnt, $jobs, $calc_port) = @_;
	my ($pRead, $cWrite, $pWrite, $cRead);
	my (@result_pid, $res);
	$res = [];
	my $intpart = int(scalar(@$jobs)/$fork_cnt);
	my $rest = scalar(@$jobs) - $fork_cnt*$intpart;
	my $it = 1;
	pipe ($pRead, $cWrite) or die "Unable to pipe: $!";
	pipe ($cRead, $pWrite) or die "Unable to pipe: $!";
	$cWrite -> autoflush(1);
	$pWrite -> autoflush(1);
	my $pid;
	my $number = 1;
	for $number (1..$fork_cnt) {
		myint() if ($number != 1 and !_check_resp($cRead, $pid));
		$pid = fork();
		if (!defined $pid) {return die "Unable to fork: $!";}
		if ($pid == 0) {last;}
		print $cWrite "$pid $number\n";
		$kids{$pid} = $number;
	}
	if ($pid) {
		myint() if (!_check_resp($cRead, $pid));
		my $number = $fork_cnt;
		while (1) {
			for (keys %kids) {
				if ($kids{$_} == 0) {
					open (my $resFH, "<", "results_$_.txt") or die "$!";
					flock($resFH, LOCK_EX);
					@result_pid = <$resFH>;
					flock($resFH, LOCK_UN);
					for my $result (@result_pid) {
						push (@$res, $result);
					}
					unlink "./results_$_.txt";
					$kids{$_} = -1;
					$number--;
				}
			}
			if ($number == 0) {last;}
		}
		return $res;
	}
	else {
		close $cRead;
		close $cWrite;

		my $str = <$pRead>;
		chomp $str;
		($pid, my $number) = split(' ', $str);
		print $pWrite pack("l", $pid);
		my $status = 0;
		my @ownjobs;
		my $count = 0;

		@ownjobs = @$jobs[( $intpart * ($number - 1) )..($intpart * $number - 1 )];
		if ($number <= $rest) {push (@ownjobs, $jobs -> [$intpart * ($number)]); }

		status_update($pid, $status, $count);

		open (my $cFH, "+>>", "results_$pid.txt") or die "Unable to open file: $!";


		my $socket = IO::Socket::INET -> new (
			PeerAddr => "127.0.0.1",
			PeerPort => "$calc_port",
			Proto => "tcp",
			Type => SOCK_STREAM
		) or die "Can't connect to Calc: $!";

		$socket -> autoflush(1);
		$status = 1;
		status_update($pid, $status, $count);
		flock($cFH, LOCK_EX);
		calc_jobs($socket, \@ownjobs, $cFH, $pid, \$count);
		flock($cFH, LOCK_UN);
		$status = 2;
		status_update($pid, $status, $count);
		close $cFH;
		close $socket;
		exit 0;
	}
	
}

sub get_from_server {
	my ($port, $limit) = @_;
	my ($jobs, $job, $willrecv);

	my $socket = IO::Socket::INET -> new (
		PeerAddr => "127.0.0.1",
		PeerPort => "$port",
		Proto => "tcp",
		Type => SOCK_STREAM
	) or die "Can't connect to GenCalc: $!";
	
	print $socket pack("s", $limit);
	my @ready = IO::Select->new($socket)->can_read;
	my $ready = $ready[0];
	read($ready, $willrecv, 4);
	$willrecv = unpack("l", $willrecv);
	for (1..$willrecv) {
		my @ready = IO::Select->new($socket)->can_read;
		$ready = $ready[0];
		read($ready, my $len, 4);
		$len = unpack("l", $len);
		read($ready, $job, $len);
		$job = unpack("a*", $job);
		push (@$jobs, $job);
	}
	close $socket;
	return $jobs;
}
sub status_update {
	my ($pid, $status, $count) = @_;
	my @status_num = qw(READY PROCESS DONE);
	my $stat = $status_num[$status];
	my $prevpos = 0;
	my $curpos = 0;
	my $sfFH;
	open ($sfFH, "+>>", $status_file) or die "$!";
	flock($sfFH, LOCK_EX);
	seek($sfFH, 0, SEEK_SET);
	my $read_struct = <$sfFH>;
	my $struct; 
	my $found;
	if (defined $read_struct) {
		$found = ($read_struct =~ s/("$pid"\s*:\s*\{"status"\s*:\s*\")(READY|PROCESS|DONE)(\"\s*,\s*"cnt"\s*:\s*)(\d++)/$1$stat$3$count/s); 
		unless ($found) {
			$read_struct =~ s/\}\s*$/, "$pid" : \{"status" : \"$stat\", "cnt" : $count \}\}/s;
		}
	}
	unless (defined $read_struct) {$read_struct = qq(\{"$pid" : \{"status" : "$stat", "cnt" : $count \}\});}
	seek($sfFH, 0, SEEK_SET);
	truncate ($sfFH, 0);
	print $sfFH $read_struct;
	flock ($sfFH, LOCK_UN);
	close $sfFH;
}
1;
