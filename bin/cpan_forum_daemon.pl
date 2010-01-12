#!/usr/bin/perl

use strict;
use warnings;

use File::Basename qw(dirname);
use Getopt::Long qw(GetOptions);
use Cwd qw(abs_path);

BEGIN {
	unshift @INC, dirname( dirname( abs_path($0) ) ) . '/lib';
}
use CPAN::Forum::Daemon;

usage() if not @ARGV;

my %opt;
GetOptions(
	\%opt,
	'idle=s',
	'help',
) or usage();
usage() if $opt{help};


my $p = CPAN::Forum::Daemon->new( \%opt );
$p->run;


sub usage {
	print <<"END_USAGE";
Usage: $0
      --idle SECS    how many sec to wait before running again

      --help         this help

END_USAGE
	exit 0;
}
