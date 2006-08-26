#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use Text::CSV_XS;

use lib "lib";

use CPAN::Forum::DBI;
use CPAN::Forum::Posts;

my %opts;
GetOptions(\%opts, 'help', 'dir=s', 'csv=s') or usage();
usage() if $opts{help};
usage() if not $opts{dir} or not $opts{csv};


my $dbfile       = "$opts{dir}/forum.db";
CPAN::Forum::DBI->myinit("dbi:SQLite:$dbfile");

my $csv          = Text::CSV_XS->new();

;
open my $out, '>', $opts{csv} or die $!;
foreach my $entry (CPAN::Forum::Posts->search_stat_posts) {
    if ($csv->combine($entry->{gname}, $entry->{cnt})) {
        print {$out} $csv->string(), "\n";
    } else {
        warn "Invalid row";
    }
}




sub usage {

    print <<"END_USAGE";

Usage: $0
        --help             this help
        --dir  DIR         directory of forum.db file
        --csv  FILENAME    path to the output csv file
END_USAGE
    exit;
}




