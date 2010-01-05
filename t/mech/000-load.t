use warnings;
use strict;

use Test::More;
plan skip_all => 'Need CPAN_FORUM_DB_FILE and CPAN_FORUM_TEST_URL' 
	if not $ENV{CPAN_FORUM_DB_FILE} or not $ENV{CPAN_FORUM_TEST_URL};

use t::lib::CPAN::Forum::Test;

my $w = t::lib::CPAN::Forum::Test::get_mech();

plan tests => 2;

use CPAN::Forum;
ok(1, 'module can be loaded'); #TODO move this to some other test

diag( "Testing CPAN::Forum $CPAN::Forum::VERSION" );

unlink $ENV{CPAN_FORUM_DB_FILE};
$w->get($ENV{CPAN_FORUM_TEST_URL});
$w->content_like(qr/Something went wrong here. The webmaster will be informed and will try to take action./, 
   'no database file reported as something');




