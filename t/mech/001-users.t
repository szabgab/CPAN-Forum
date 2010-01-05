use strict;
use warnings;

use Test::More;
plan skip_all => 'Need CPAN_FORUM_DB_FILE and CPAN_FORUM_TEST_URL' 
	if not $ENV{CPAN_FORUM_DB_FILE} or not $ENV{CPAN_FORUM_TEST_URL};

plan tests => 6;

use t::lib::CPAN::Forum::Test;

my $w = t::lib::CPAN::Forum::Test::get_mech();

{
    t::lib::CPAN::Forum::Test::setup_database();
    ok(-e $ENV{CPAN_FORUM_DB_FILE});
}

{
    $w->get_ok($ENV{CPAN_FORUM_TEST_URL});
    $w->content_like(qr{CPAN Forum});
    $w->content_unlike(qr/Something went wrong here/);
} 


{
    $w->follow_link_ok({ text => 'FAQ' });
    $w->content_like(qr{Frequently Asked Questions}, 'FAQ link');
}

