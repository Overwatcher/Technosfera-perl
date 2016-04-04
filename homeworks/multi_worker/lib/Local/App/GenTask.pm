package Local::App::GenTask;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = 'gentask';


sub r_int {						#r for random
	my $range = 20;
	return -10+int(rand($range));
}
sub r_binop {
	my@binop = ('+', '-', '*', '^', '/');
	my $range = 5;
	return $binop[int(rand($range))];
}
sub r_minus {
	return '-' if rand()> 0.5;
	return '';
}
sub r_opbracket {
	my $rem_opened_ref = shift;
	my $rand = rand();
	if ($rand > 0.5) {
		return '';
	}
	$rand = 1+int(rand(3));
	$$rem_opened_ref += $rand;
	return '(' x $rand;
}
sub r_clbracket {
	my ($end, $rem_opened_ref) = @_;
	my $output = ')' x $$rem_opened_ref;
	return $output if $end;
	my $rand = int(rand($$rem_opened_ref));
	$$rem_opened_ref -= $rand;
	return ')' x $rand;
}
sub gentask {
	my $maxlen = 1 + int(rand(10));
	my $count = 0;
	my $task;
	my $brackets;
	my $rem_opened = 0;
	my $end;
	while (1) {
		$task = $task . r_minus();
		$brackets = r_opbracket(\$rem_opened);
		$task = $task . $brackets;
		if ($brackets ne '') {
			$task = $task . r_int();
			$count++;
			if ($count == $maxlen) {
				$task = $task . r_clbracket(1, \$rem_opened);
				last;
			}
			$task = $task . r_binop();
			next;
		}
		$task = $task . r_int();
		$count++;
		if ($count == $maxlen) {
			$task = $task . r_clbracket(1, \$rem_opened);
			last;
		}
		$task = $task . r_clbracket(0, \$rem_opened);
		$task = $task . r_binop;
	}
	return $task;
}
1;
