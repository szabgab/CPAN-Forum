package CPAN::Forum::Handler;
use strict;
use warnings;

use Apache2::Const -compile => qw(OK);
use Apache2::RequestRec ();

use File::Basename qw(dirname);
my $root;
BEGIN {
	$root = dirname(dirname(dirname(dirname(__FILE__))));
}
use lib "$ENV{CPANFORUM_ROOT}/lib";
use CPAN::Forum;


my $app = CPAN::Forum->new(
	TMPL_PATH => "$ENV{CPANFORUM_ROOT}/templates",
	PARAMS => {
		ROOT       => $ENV{CPANFORUM_ROOT},
		DB_CONNECT => "dbi:SQLite:$ENV{CPANFORUM_ROOT}/db/forum.db",
		#REQUEST    => ($ENV{SCRIPT_NAME} || '') . ($ENV{PATH_INFO} || ''),
	},
);

sub handler {
    my $r = shift;
#    $r->content_type('text/html');

    $app->run();
    return Apache2::Const::OK;
}

1;

