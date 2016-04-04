package Local::App::Evaluate;

use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Local::App::Rpn 'rpn';
use Exporter 'import';
use feature 'switch';
our @EXPORT_OK = 'evaluate';
BEGIN{
	if ($] < 5.018) {
		package experimental;
		use warnings::register;
	}
}
no warnings 'experimental';
sub evaluate {
	my $task = shift;
	my $rpnref = rpn($task);
	my @rpn = @$rpnref;
	my $el;
	my @stack;
	for $el (@rpn) {
		given ($el) {
			when ('U-') {
				if ($stack[$#stack] =~ /\-?\d+|\-?\d*.\d+/) {$stack[$#stack] = 0 - $stack[$#stack];}
				else {return 'Err';} 
				next;
			}
			when ('U+') { next;}
			when ('^') {
				if ($stack[$#stack] =~ /\-?\d+|\-?\d*.\d+/ && $#stack >= 1 && $stack[$#stack-1] =~ /\-?\d+|\-?\d*.\d+/) {
					splice (@stack, $#stack-1, 2, $stack[$#stack-1]**$stack[$#stack]);
				} else {return 'Err';}
				next;
			}
			when ('*') {
				if ($stack[$#stack] =~ /\-?\d+|\d*.\d+/ && $#stack >= 1 && $stack[$#stack-1] =~ /\-?\d+|\d*.\d+/) {
					splice (@stack, $#stack-1, 2, $stack[$#stack-1]*$stack[$#stack]);
				} else {return 'Err';}
				next;
			}
			when ('/') {
				if ($stack[$#stack] =~ /\-?\d+|\-?\d*.\d+/ && $#stack >= 1 && $stack[$#stack-1] =~ /\-?\d+|\-?\d*.\d+/) {
					if ($stack[$#stack] == 0) {return 'NaN';} 
					splice (@stack, $#stack-1, 2, $stack[$#stack-1]/$stack[$#stack]);
				} else {return 'Err';}
				next;
			}
			when ('+') {
				if ($stack[$#stack] =~ /\-?\d+|\-?\d*.\d+/ && $#stack >= 1 && $stack[$#stack-1] =~ /\-?\d+|\-?\d*.\d+/) {
					splice (@stack, $#stack-1, 2, $stack[$#stack-1]+$stack[$#stack]);
				} else {return 'Err';}
				next;
			}
			when ('-') {
				if ($stack[$#stack] =~ /\-?\d+|\d*.\d+/ && $#stack >= 1 && $stack[$#stack-1] =~ /\-?\d+|\-?\d*.\d+/) {
					splice (@stack, $#stack-1, 2, $stack[$#stack-1]-$stack[$#stack]);
				} else {return 'Err';}
				next;
			}
			when (/\-?\d+|\-?\d*.\d+/) {push(@stack, $el);}
			default {return 'Err';}
		}
	}
	if ($stack[$#stack]=~ /\-?\d+|\-?\d*.\d+/) {return $stack[$#stack];}
	return 'Err';
}
1;
