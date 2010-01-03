#!/usr/bin/perl
use warnings;
use strict;

# In case the CPAN::Forum files are relative to where the script is
use File::Basename qw(dirname);
my $root;
BEGIN {
	$root = dirname(dirname(dirname($0)));
}
use lib "$root/lib";

# Enable for DBI debugging
#BEGIN { $ENV{DBI_TRACE}='1=/tmp/dbitrace.log'; }
#chmod 0666, '/tmp/dbitrace.log';

use CPAN::Forum;

my $app = CPAN::Forum->new(
	TMPL_PATH => "$root/templates",
	PARAMS => {
		ROOT       => $root,
        DB_CONNECT => "dbi:SQLite:$ENV{CPAN_FORUM_DB_FILE}",
        #REQUEST    => $ENV{PATH_INFO},
	},
);
$app->run();

