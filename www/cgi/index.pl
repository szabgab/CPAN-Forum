#!/opt/perl584/bin/perl
use warnings;
use strict;

$| = 1;

# the following line is updated during installation
use constant ROOT => "/home/gabor/work/cpan-forum";  

use lib (ROOT . "/lib");

use CPAN::Forum;
use CPAN::Forum::DBI;
CPAN::Forum::DBI->myinit(ROOT . "/db/forum.db");


binmode STDOUT, ":utf8";      
binmode STDIN,  ":utf8";      
binmode STDERR,  ":utf8";      


my $app = CPAN::Forum->new(
	TMPL_PATH => ROOT . "/templates",
	PARAMS => {
		ROOT => ROOT,
	},
);
$app->run();

