#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
my $tests;
plan tests => $tests;

use lib qw(t/lib);
use CPAN::Forum::Test;

{
    CPAN::Forum::Test::setup_database();
    ok(-e "blib/db/forum.db");
    BEGIN { $tests += 1; }
}

my $w   = CPAN::Forum::Test::get_mech();
my $url = CPAN::Forum::Test::get_url();

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

