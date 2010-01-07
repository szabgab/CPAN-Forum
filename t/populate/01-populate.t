use strict;
use warnings;

use Cwd            qw(abs_path);
use File::Basename qw(dirname);
use File::Temp     qw(tempdir);

use Test::Most;

plan skip_all => 'Need CPAN_FORUM_TEST_DB and CPAN_FORUM_TEST_USER and CPAN_FORUM_LOGFILE CPAN_FORUM_TEST_DIR' 
	if not $ENV{CPAN_FORUM_TEST_DB} or not $ENV{CPAN_FORUM_TEST_USER} or not $ENV{CPAN_FORUM_LOGFILE} or not $ENV{CPAN_FORUM_TEST_DIR};

# CPAN_FORUM_TEST_DIR is that we are going to use as a place to create our cpan mirror
# and build the html file

my $tests;
plan tests => $tests;

bail_on_fail;

use t::lib::CPAN::Forum::Test;

use CPAN::Forum::Populate;

my $url = $ENV{CPAN_FORUM_TEST_URL};

#my $root = dirname(dirname(dirname(abs_path($0))));
#diag("Root $root\n");


mkdir $ENV{CPAN_FORUM_TEST_DIR};


my $dir = t::lib::CPAN::Forum::Test::build_fake_cpan();
  
{
	my %opt = (
		dir    => $ENV{CPAN_FORUM_TEST_DIR},
		cpan   => "file://$dir",
		mirror => 'mini',
	);

	my $p = CPAN::Forum::Populate->new(\%opt);
	$p->run;
}

ok(1);
BEGIN { $tests += 1; }
