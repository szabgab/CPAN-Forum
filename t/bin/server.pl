use strict;
use warnings;

use Cwd            qw(abs_path cwd);
use File::Basename qw(dirname);

my $dir;
my $root;
BEGIN {
	$dir  = dirname(dirname(abs_path($0)));
	$root = dirname($dir);
}
use lib "$dir/lib";
use lib "$root/lib";

BEGIN {
	$ENV{CPANFORUM_ROOT} = $root;
	$ENV{CPAN_FORUM_LOGFILE} ||= "$root/cpan_forum_server.log"
}
use t::lib::CPAN::Forum::Server;

my $server = t::lib::CPAN::Forum::Server->new;
$server->run;
