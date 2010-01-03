use strict;
use warnings;

use Test::More;
my $tests;
plan tests => $tests;

use t::lib::CPAN::Forum::Test;

my $dir;
{
    $dir = t::lib::CPAN::Forum::Test::setup_database();
    ok(-e "$dir/db/forum.db");
    BEGIN { $tests += 1; }
}

my $w   = t::lib::CPAN::Forum::Test::get_mech();
my $url = t::lib::CPAN::Forum::Test::get_url();

{
    $w->get_ok($url);
    $w->content_like(qr{CPAN Forum});
    BEGIN { $tests += 2; }
}


{
    #$w->follow_link_ok({ text => 'new post' });
    #like($r, qr{Location: http://test-host/login});

    BEGIN { $tests += 0; }

#TODO: {
#   local $TODO = "do real redirection here";
#   unlike($r, qr{<HTML>}i);
#   }   
}

#{
#   my $r = $cat->cgiapp(path_info => '/login');
#   like($r, qr{Login});
#}

