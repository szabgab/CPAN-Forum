#!/usr/bin/perl -d:DProf;
use strict;
use warnings;

# perl bin/profile.pl --url threads/1130      big
# perl bin/profile.pl --url threads/2840  small

use Getopt::Long;
my $url;
my $verbose;
GetOptions(
        "urls=s" => \$url, 
        "verbose" => \$verbose,
) or usage();
usage() if not $url;

use lib 'lib', 't/lib';
use CPAN::Forum::Test;
use File::Copy qw(copy);

copy 't/forum.db', 'blib/db/forum.db';


my $mech     = CPAN::Forum::Test::get_mech();
my $base_url = CPAN::Forum::Test::get_url();
CPAN::Forum::Test::init_db();

$mech->get("$base_url/$url");
if ($verbose) {
    print $mech->content;
}

sub usage {
    print <<"END_USAGE";
Usage: $0
        --url   URL    (e.g. therads/1130)
        --verbose
END_USAGE

    exit;
}

