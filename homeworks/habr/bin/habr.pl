#!/usr/bin/env perl


use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Local::Habr;
use DDP;
execution(shift @ARGV);



