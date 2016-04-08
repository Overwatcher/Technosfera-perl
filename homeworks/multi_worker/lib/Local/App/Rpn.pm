package Local::App::Rpn;
use 5.010;
use strict;
use warnings;
use diagnostics;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Local::App::Tokenize 'tokenize';
use Exporter 'import';
our @EXPORT_OK = 'rpn';
BEGIN{
	if ($] < 5.018) {
		package experimental;
		use warnings::register;
	}
}
no warnings 'experimental';
sub rpn {
	my %priority = ( 
		'U-' =>  4, 'U+' => 4,
		'^' => 4, 
		'*' => 2, '/' => 2, 
		'+' => 1, '-' => 1, 
		'(' => 0, ')' => 0);
	my $str = shift;
	my $char;	
	my @tokened = tokenize($str);
	my $before = '';
	my $number;
	my @RPN;
	my @stack;
	my $flag = 0;
	my $unary = 0;
	for $char (@tokened) {
		$flag = 0;
		if ($char =~ /^\s*$/) {
			if ($before eq ')' || $before eq '' ) {
				$flag = 1;
			} 
			next;
		}		#skip if tabs/spaces etc.
		given ($char) {
			when (/^\-?\d+$|^\-?\d*\.\d+$|^\-?\d+e\d+$|^\-?\d+e[\+\-]\d+$|^\-?\d*\.\d+e\d+$|^\-?\d*\.\d+e[\+\-]\d+$/) {
				$number = 0+$char;
				push (@RPN, $number);
				next;
			}
			when (/\(/) {
				push (@stack, $char);
				next;
			}
			when (/[\-\+]/) {
				if ($char =~ /-/ && $before =~ /^\s*$/) { #$before is empty <=> 2 operators stood together
					$char = 'U-';
					$unary = 1;
				}
				if ($char eq '+' && $before =~/^\s*$/) {
					$char = 'U+';
					$unary = 1;
				}
				if ($unary == 0) {
					while (@stack && $priority{$char} <= $priority{$stack[$#stack]}) {
						push(@RPN, $stack[$#stack]);
						pop(@stack);
					} 
					
				} 
				else {
					
					while (@stack && $priority{$char} < $priority{$stack[$#stack]}) {
						push(@RPN, $stack[$#stack]);
						pop(@stack);
					} 
				
				}
				$unary = 0;
				push (@stack, $char);
				next;
			}
			when (/[\*\/]/) {
				while ( @stack && ($priority{$char} <= $priority{$stack[$#stack]}) ) {
						push(@RPN, $stack[$#stack]);
						pop(@stack);
					} 
					
				push (@stack, $char);
				next;
			}
			when ('^') {
				while (@stack && $priority{$char} < $priority{$stack[$#stack]}) {
						push(@RPN, $stack[$#stack]);
						pop(@stack);
					} 
					
				
				push (@stack, $char);
				next;
			}
			when ('(') {
				push (@stack, '(');
				next;
			}
			when (')') {
				while (@stack && $stack[$#stack] ne '(') {
					if ($#stack == 0) {print "Error: check ()"; return "Err";}
					push(@RPN, $stack[$#stack]);
					pop(@stack);
				}
				pop(@stack);
				next;
			}
			default {return "Err";}
		}
	} continue {$before = $char unless $flag;}
	while (@stack) {
		push(@RPN, $stack[$#stack]);
		pop(@stack);
	}
	return \@RPN;
1;
}
1;
