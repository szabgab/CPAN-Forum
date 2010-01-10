use strict;
use warnings;

use Test::Most;

plan skip_all => 'Need CPAN_FORUM_TEST_DB and CPAN_FORUM_TEST_USER and CPAN_FORUM_LOGFILE'
	if not $ENV{CPAN_FORUM_TEST_DB}
		or not $ENV{CPAN_FORUM_TEST_USER}
		or not $ENV{CPAN_FORUM_LOGFILE};

plan tests => 5;
bail_on_fail;

use t::lib::CPAN::Forum::Test;

my $w = t::lib::CPAN::Forum::Test::get_mech();

{
	t::lib::CPAN::Forum::Test::setup_database();
}

{
	$w->get_ok( $ENV{CPAN_FORUM_TEST_URL} );
	$w->content_like(qr{CPAN Forum});
	$w->content_unlike(qr/Something went wrong here/);
}


{
	$w->follow_link_ok( { text => 'FAQ' } );
	$w->content_like( qr{Frequently Asked Questions}, 'FAQ link' );
}

