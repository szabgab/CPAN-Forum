#!/usr/bin/perl
use strict;
use warnings;

use Cwd qw(abs_path cwd);
use File::Basename qw(dirname);

my $dir;


BEGIN {
	$dir = dirname( dirname( abs_path($0) ) );

}
use lib "$dir/lib";

use CPAN::Forum::CPANRatings;
CPAN::Forum::CPANRatings->new->run;

