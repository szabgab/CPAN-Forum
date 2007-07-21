package CPAN::Forum::Handler;
use strict;
use warnings;

use Apache2::Const -compile => qw(OK);
use Apache2::RequestRec ();

my $seen;

sub handler {
    my $r = shift;
    $r->content_type('text/html');

    my $root = "$ENV{DOCUMENT_ROOT}/..";
    local @INC = ("$root/lib", "/home/gabor/perl5lib/lib", "/home/gabor/perl5lib/lib/i486-linux-gnu-thread-multi", @INC);
    require CPAN::Forum;
#use Data::Dumper;
#warn Dumper \%ENV;

    my $app = CPAN::Forum->new(
	    TMPL_PATH => "$ENV{CPANFORUM_ROOT}/templates",
	    PARAMS => {
		    ROOT       => $ENV{CPANFORUM_ROOT},
            DB_CONNECT => "dbi:SQLite:$ENV{CPANFORUM_ROOT}/db/forum.db",
            REQUEST    => ($ENV{SCRIPT_NAME} || '') . ($ENV{PATH_INFO} || ''),
	    },
    );
    $app->run();
    return Apache2::Const::OK;
}

1;
