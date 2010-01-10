use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Temp qw(tempdir);

use Test::Most;

plan skip_all => 'Need CPAN_FORUM_TEST_DB and CPAN_FORUM_TEST_USER and CPAN_FORUM_LOGFILE'
	if not $ENV{CPAN_FORUM_TEST_DB}
		or not $ENV{CPAN_FORUM_TEST_USER}
		or not $ENV{CPAN_FORUM_LOGFILE};

my $tests;
plan tests => $tests;

bail_on_fail;

$ENV{CPAN_FORUM_DB}   = $ENV{CPAN_FORUM_TEST_DB};
$ENV{CPAN_FORUM_USER} = $ENV{CPAN_FORUM_TEST_USER};

use t::lib::CPAN::Forum::Test;

use CPAN::Forum::Populate;

my $url = $ENV{CPAN_FORUM_TEST_URL};

#my $root = dirname(dirname(dirname(abs_path($0))));
#diag("Root $root\n");
my $dir = tempdir( CLEANUP => 1 );

t::lib::CPAN::Forum::Test::setup_database();

my $cpan_dir = t::lib::CPAN::Forum::Test::build_fake_cpan();

# TODO test mirror alone? - probably no need
#

{
	my %opt = (
		dir  => $dir,
		cpan => "file://$cpan_dir",

		mirror  => 'mini',
		process => 'all',
		yaml    => 1,
	);

	my $p = CPAN::Forum::Populate->new( \%opt );
	$p->run;
}

my $dbh = t::lib::CPAN::Forum::Test::get_dbh();
{
	my $user_cnt = $dbh->selectrow_array("SELECT COUNT(*) FROM users");
	is( $user_cnt, 1, 'users count' );
	my $group_cnt = $dbh->selectrow_array("SELECT COUNT(*) FROM groups");
	is( $group_cnt, 2, 'two groups' );
	my $groups = $dbh->selectall_arrayref("SELECT name FROM groups ORDER BY name");
	is_deeply( $groups, [ ['ABI'], ['Acme-Bleach'] ] );
	BEGIN { $tests += 3; }
}


