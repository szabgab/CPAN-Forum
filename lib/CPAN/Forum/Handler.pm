package CPAN::Forum::Handler;
use strict;
use warnings;

our $VERSION = '0.16';

use Apache2::Const-compile => qw(OK);
use Apache2::RequestRec ();

use File::Basename qw(dirname);
my $root;

BEGIN {
	$root = dirname( dirname( dirname( dirname(__FILE__) ) ) );
}
use lib "$root/lib";

use CPAN::Forum;


my $app = CPAN::Forum->new(
	TMPL_PATH => "$root/templates",
	PARAMS    => {
		ROOT => $root,

		#		DB_CONNECT => "dbi:SQLite:$ENV{CPAN_FORUM_DB_FILE}",
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

