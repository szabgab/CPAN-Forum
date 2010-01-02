#!/usr/bin/perl

use strict;
use warnings;

use File::Basename qw(dirname);
use Getopt::Long   qw(GetOptions);
BEGIN {
	unshift @INC, dirname(dirname($0)) . '/lib';
}
use CPAN::Forum::Populate;

usage() if not @ARGV;
my %opt;
GetOptions(\%opt, 
	'help',
	'mirror=s',
) or usage();
usage() if $opt{help};


my $p = CPAN::Forum::Populate->new(\%opt);
$p->run;


sub usage {
	print <<"END_USAGE";
Usage: $0
      --mirror [cpan|mini|path/to/file]   # full cpan mirror, or Mini::CPAN or
                                          # list of packages to mirror
      --help         this help

END_USAGE
	exit 0;
}
