#!/usr/bin/perl
use warnings;
use strict;

$| = 1;

use FindBin qw($Bin);
my $ROOT;
BEGIN {$ROOT = "$Bin/../..";}
use lib ("$ROOT/lib");

use CPAN::Forum;

binmode STDOUT, ":utf8";      
binmode STDIN,  ":utf8";      
binmode STDERR,  ":utf8";      


my $app = CPAN::Forum->new(
	TMPL_PATH => "$ROOT/templates",
	PARAMS => {
		ROOT => $ROOT,
        DB_CONNECT => "dbi:SQLite:$ROOT/db/forum.db"
	},
);
$app->run();

