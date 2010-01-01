#!/usr/bin/perl
use warnings;
use strict;

# In case the CPAN::Forum files are relative to where the script is
use File::Basename qw(dirname);
BEGIN {
	my $dir = dirname(dirname(dirname($0))) . '/lib';
	unshift @INC, $dir;
}

# Enable for DBI debugging
#BEGIN { $ENV{DBI_TRACE}='1=/tmp/dbitrace.log'; }
#chmod 0666, '/tmp/dbitrace.log';

use CPAN::Forum;

my $app = CPAN::Forum->new(
	TMPL_PATH => "$ENV{CPANFORUM_ROOT}/templates",
	PARAMS => {
		ROOT       => $ENV{CPANFORUM_ROOT},
        DB_CONNECT => "dbi:SQLite:$ENV{CPANFORUM_ROOT}/db/forum.db",
        #REQUEST    => $ENV{PATH_INFO},
	},
);
$app->run();

