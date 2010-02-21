package CPAN::Forum::Handler;
use strict;
use warnings;

our $VERSION = '0.19';

use Apache2::Const-compile => qw(OK);
use Apache2::RequestRec ();

use File::Basename qw(dirname);
my $root;

BEGIN {
	$root = dirname( dirname( dirname( dirname(__FILE__) ) ) );
}
use lib "$root/lib";

use CPAN::Forum;

sub handler {
	my $r = shift;

	#    $r->content_type('text/html');
	my $app = CPAN::Forum->new(
		TMPL_PATH => "$root/templates",
		PARAMS    => {
			ROOT => $root,
		},
	);
	$app->run();
	return Apache2::Const::OK;
}

1;

