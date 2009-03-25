use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../lib";
BEGIN {
	$ENV{CPANFORUM_ROOT} = "$FindBin::Bin/../../";
	$ENV{CPAN_FORUM_LOGFILE} = "$FindBin::Bin/../../cpan_forum_server.log"
}
use t::lib::CPAN::Forum::Server;

my $server = t::lib::CPAN::Forum::Server->new;
$server->run;
