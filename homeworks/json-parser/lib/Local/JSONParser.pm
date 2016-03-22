package Local::JSONParser;

use strict;
use warnings;
use utf8;
use Exporter 'import';
our @EXPORT_OK = 'parse_json';
our @EXPORT = 'parse_json';

sub mydelete {
	my ($stref, $pos) = @_;
	my $empty = '';
	$$stref =~ s/.{$pos}/$empty/se;
}
sub myisnumber {
	my $str = shift;
	my $empty = '';
	$str =~ s/,|\s/$empty/sge;
	if ($str =~ /^\-?(?:0|[1-9]\d*)(?:\.\d++)?(?:[Ee][+-]\d+$|$)/) {return 1;}
	else {return 0;}
}
sub myisstr {
	my $str = shift;
#	$str = '"'.$str.'"';
	if ($str =~ /^"((?:[^"\/]|\\["\/bnfrt]|\\u[0-9A-F]{1,4})*?)"$/) {
		return 1;
	}
	else { return 0;}
	
}
sub convert {
	my $str = shift;
	while ($str =~ /(\\u[0-9A-F]{1,4}+)/sg) {
		my $change = $1;
		my $hold = '\\'.$1;
		$change =~ s/u/x\{/sg;
		$change = $change.'}';
		$str =~ s/$hold/$change/esg;
	}
	$str =~ s/\\t/\t/sg;
	$str =~ s/\\n/\n/sg;
	$str =~ s/\\b/\b/sg;
	$str =~ s/\\f/\f/sg;
	$str =~ s/\\r/\r/sg;
	$str =~ s/\\"/"/sg;
	$str =~ s/\\x\{([0-9A-F]{1,4}+)\}/chr(hex $1)/sge;
	return $str;
}
sub parse_json {
	my $_ = shift;
	my $empty = '';
	my @array =();
	my %object =();
	s/^\s*+/$empty/sge;
	if (/^\{/) {
		mydelete(\$_, 1);
		while (/\s*+"((?:[^"\\\/]|\\["\\\/bnfrt]|\\u[0-9A-F]{1,4})*+)"\s*+:\s*+/sg ) {
			my $key = $1;
			mydelete (\$_, pos($_));
			if (/\G(\-?(?:0|[1-9]\d*)(?:\.\d++)?(?:[Ee][+-]\d+(?:\s*,?\s*+)|(?:\s*,?\s*+)))/sg) {
				my $value = $1;
				$value =~ s/,|\s/$empty/sge;
				$object{$key} = 0+$value;
				mydelete (\$_, pos($_));
				next; 
			}
			if (/\G"((?:[^"\\\/]|\\["\\\/bnfrt]|\\u[0-9A-F]{1,4})*?)"(?:\s*,?\s*+)/sg) {
				my $value = $1;
				$value = convert $value;
				$object{$key} = $value;
				mydelete (\$_, pos($_));
				next;
			}
			if (/\G\{|\[/sg) {
				mydelete(\$_, pos($_) -1);
				(my $value, $_) = parse_json($_);
				$object{$key} = $value;
				unless (defined $value) {return die;}
				next;
			} 
			return die 'structure error';
		} continue {
			if (/\G\s*+\},?\s*+/sg) {
				mydelete (\$_, pos($_));
				if (wantarray) {return \%object, $_;}
				else {return \%object;}
			}
		}
		if (/^\s*+\}\s*,?\s*+/sg) {
			mydelete(\$_, pos($_));
			if (wantarray) {return \%object, $_;}
			else {return \%object;}
		}
		return die 'structure error';
	}
	if (/^\[/) {
		mydelete (\$_, 1);
		my $flag = 0;
		#return die if /^\s*$/sg or !defined;
		while (/^\s*+(
			(?:"(?:[^"\\\/]|\\["\\\/bnfrt]|\\u[0-9A-F]{1,4})*+")(\s*,\s*+|\s*+\]\s*,?\s*+)
			|
			(\-?(?:0|[1-9]\d*)(?:\.\d++)?(?:[Ee][+-]\d+(\s*,\s*+|\s*+\]\s*,?\s*+)|(\s*,\s*+|\s*+\]\s*,?\s*+)))
			|
			(\{|\[)
			|
			(\]\s*,?\s*+))
			/sgx) {
			my $value = $1;
			$value =~ s/,?+\s*+$/$empty/seg;
			$flag = 0;
			if ($value =~ /\]\s*,?\s*+$/) {$flag = 1;}
			$value =~ s/\s*+\]$/$empty/sge;
			if ($value =~ /[\{\[]/) {
				mydelete(\$_, pos($_) - 1);
				($value, $_) = parse_json($_);
				#unless (defined $value) {return die;}
				push (@array, $value);
				next;
			}
			if (myisnumber($value)) {
				$value =~ s/,|\s/$empty/sge;
				push (@array, 0+$value);
				mydelete(\$_, pos($_));
				next;
			}
			if ($value eq '' and $flag == 1) {
				if (wantarray) {
					return \@array, $_;
				} else {
					return \@array;
				}
			}
			unless (myisstr($value)) {return die 'structure error';}
			else {
				$value = convert $value;
				$value =~ s/(^")|("$)/$empty/sge;
				push (@array, $value);
				mydelete(\$_, pos($_));
				next;
			}
			return die 'structure error';
		} continue {
			if ($flag) {
				if (wantarray) {
					return \@array, $_;
				} else {
					return \@array;
				}
			}
		}
		return die 'structure error';
	}
	else {return die 'structure error';}
}
1;
