package Local::App::Tokenize;
use 5.010;
use strict;
use warnings;
use diagnostics;
use Exporter 'import';
our @EXPORT_OK  = 'tokenize';
BEGIN{
	if ($] < 5.018) {
		package experimental;
		use warnings::register;
	}
}
no warnings 'experimental';



sub tokenize {
	my @tokenedres;
	my $str = shift;
	my $it = 0;
	my $itres = 0;
	my $flag = 1;
	$str =~ s/\s*//g;
	my @tokened1 = split m{([\/\(\)\^\+\-\*])}, $str; # could be '' in case of operators standing together
	$str =~ s/\s*//g;
	while ($it <= $#tokened1) {
		if ($tokened1[$it] =~ /e$/) {
			$flag = 0;
			if (($tokened1[$it+1] =~ /\+|\-/) && ($tokened1[$it+2] =~ /\d+/)) {
				$tokenedres[$itres] = join('', $tokened1[$it], $tokened1[$it+1], $tokened1[$it+2]);
				$it += 3;
				$itres++;
				$flag = 1;
				next;
			}
			if ($tokened1[$it+1] =~/\d+/) {
				$tokenedres[$itres] = join('', $tokened1[$it], $tokened1[$it+1]);
				$it += 2;
				$itres++;
				$flag = 1;
				next;
			}
			return undef if !$flag;
		}
	$tokenedres[$itres] = $tokened1[$it];
	$it++;
	$itres++;
	}
	return @tokenedres if wantarray;
	1;
}
1;
