use strict;
use warnings;
use AE;
my $cv = AE::cv;
my @array = 1..10;

my $i = 0;

sub async {
    my $cb = pop;

    my $w;$w = AE::timer rand(0.1),0,sub {
        undef $w;

        $cb->();
    };

    return;
}

sub _next {
    my $cur = $i++;
    return if $cur > $#array;
    $cv->begin();
    print "Process $array[$cur]\n";
    async sub {
	print  "Processed $array[$cur]\n";
	_next();
	$cv->end();
    };
};
for (1..10) { _next(); }

$cv->recv;


