package Local::App::ProcessCalc;

use strict;
use warnings;
use Fcntl qw(:flock :seek);
use IO::Socket;
use IO::Select;
use POSIX ":sys_wait_h";
use Exporter 'import';
our @EXPORT = qw(multi_calc get_from_server);
our $status_file = "./calc_status.txt";
our %kids;
our $sfFH;
open ($sfFH, "+>", $status_file) or die "$!";
$SIG{CHLD} = \&mychld;

sub mychld {
	while (my $pid = waitpid(-1, WNOHANG)) {
		last if $pid == -1;
		if ($? >> 8) {
			myint();
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
	return exit 1;
}

sub _check_resp {
	my ($handle, $expect) = @_;
	my @ready = IO::Select->new($handle)->can_read;
	my $ready = $ready[0];
	read($ready, my $response, 4);
	$response = unpack ("l", $response);
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
	my ($fork_cnt, $jobs, $calc_port) = @_;
	my ($pRead, $cWrite, $pWrite, $cRead);
	my $intpart = int(scalar(@$jobs)/$fork_cnt);
	my $rest = scalar(@$jobs) - $fork_cnt*$intpart;
	my $it = 1;
	pipe ($pRead, $cWrite) or die "Unable to pipe: $!";
	pipe ($cRead, $pWrite) or die "Unable to pipe: $!";
	$cWrite -> autoflush(1);
	$pWrite -> autoflush(1);
	my $pid;
	for (1..$fork_cnt) {
		myint() if (_check_resp($cRead, $pid) and $_ != 1);
		$pid = fork();
		if (!defined $pid) {return die "Unable to fork: $!";}
		if ($pid == 0) {last;}
		print $cWrite "$pid\n";
		$kids{$pid} = 1;
		for (1..$intpart) {
			print $cWrite shift @$jobs;
		}
		print $cWrite shift @$jobs if $it <= $rest;
		$it++;
	}
	if ($pid) {
		myint() unless _check_resp($cRead, $pid);
		close $pRead;
		close $pWrite;
		my @ret;
		my @handlers;
		my $result;
		for (keys %kids) {
			my $kidfh;
			open($kidfh, "+>>", "./result_$_.txt");
			push(@handlers, $kidfh);
		}
		while (my @ready = IO::Select->new(@handlers)->can_read ) {
			for my $ready (@ready) {
				while (my $res = <$ready>) {
					chomp $res;
					push (@ret, $res);
				}
				
			}
		}
		close $sfFH;
		return \@ret;
	}
	else {
		close $cRead;
		close $cWrite;

		$pid = <$pRead>;
		chomp $pid;
		$pid =0+$pid;

		my $status = 0;
		my @ownjobs;
		my $count = 0;

		status_update($pid, $status, $count);

		open (my $cFH, "+>>", "./results_$pid.txt") or die "Unable to open file: $!";

		$intpart++ if $it <= $rest;
		for (1..$intpart) {
			my $job = <$pRead>;
			chomp $job;
			push (@ownjobs, $job);
		}
		print $pWrite pack("l", $pid);

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
		$job = $job . "\n";
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
#	open (my $FH, "+>", $status_file) or die "Unable to open $status_file : $!";
	flock($sfFH, LOCK_EX);
	print $sfFH, qq(\{$pid => \{status => $stat, cnt => $count \}\});
	flock ($sfFH, LOCK_UN);
#	close $FH;
}
1;
