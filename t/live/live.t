#!/usr/bin/perl
use strict;
use warnings;

use File::Copy qw(copy);
my $do;
BEGIN {
    $do = copy 't/forum.db', 'blib/db/forum.db'; # TODO: later change to generate from t/test.dump
}

use Test::More;
my $tests;
plan skip_all => "t/forum.db is missing" if not $do;
plan tests => $tests;

use lib qw(t/lib);
use CPAN::Forum::Test;


my $w       = CPAN::Forum::Test::get_mech();
my $url     = CPAN::Forum::Test::get_url();
CPAN::Forum::Test::init_db();

$ENV{NO_CPAN_FORUM_MAIL} = 1;

{
    ok(1);
    BEGIN { $tests += 1; }
}

use CPAN::Forum::DB::Posts;
{
    my $cnt = 0;
    my $limit = 10;
    my $it = CPAN::Forum::DB::Posts->retrieve_latest($limit);
    while (my $p = $it->next) {
        last if ++$cnt > $limit;
    }
    is($cnt, $limit);

    BEGIN { $tests += 1; }
}

{
    my $cnt = 0;
    my $limit = 10;
    my ($group) = CPAN::Forum::DB::Groups->search({ name => 'CPAN-Forum' });
    my $it = CPAN::Forum::DB::Posts->search(gid => $group->id, 
                        {order_by => 'date DESC'});
    while (my $p = $it->next) {
        last if ++$cnt >= $limit;
    }
    is($cnt, $limit);

    BEGIN { $tests += 1; }
}
    

{
    # dists, rss feeds
    $w->get_ok($url);
    $w->get_ok("$url/rss/all");
    $w->content_like(qr{<item>});

    $w->get_ok("$url/rss/threads");
    $w->content_like(qr{<item>});

    #TODO: also test Content type

    $w->get_ok("$url/dist/CPAN-Forum");
    $w->content_like(qr{No forum for libnet}); # this is a title of a real post

    $w->get_ok("$url/rss/dist/CPAN-Forum");
    $w->content_like(qr{<item>});
    $w->content_like(qr{No forum for libnet});

    $w->get_ok("$url/rss/author/SZABGAB");
    $w->content_like(qr{<item>});

    #$w->get_ok("$url/rss/author/no_such_author");
    #diag $w->content;
    #$w->content_like(qr{<item>});

    $w->get_ok("$url/rss/no_such_feed/xyz");
    #$w->content_like(qr{No such RSS feed.});
    $w->content_like(qr{No posts yet});

    BEGIN { $tests += 14; }
}

{
    $w->get_ok("$url/about/");
    $w->content_like(qr{Tools used});

    $w->get_ok("$url/faq/");
    $w->content_like(qr{Frequently Asked Questions});

    $w->get_ok("$url/stats/");
    $w->content_like(qr{\QTop 50 modules (number of posts)});

    BEGIN { $tests += 6; }
}


my @bad_urls;
BEGIN { @bad_urls = qw(rss dist dist/xxx dits/xxx/yyy users users/xxxyy); }
foreach my $u (@bad_urls) {
    $w->get_ok("$url/$u");
    $w->get_ok("$url/$u/");

    BEGIN { $tests += 2*@bad_urls }
}

