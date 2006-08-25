#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
my $tests;
plan tests => $tests;

use lib qw(t/lib);
use CPAN::Forum::Test;
my @users = @CPAN::Forum::Test::users;

{
    CPAN::Forum::Test::setup_database();
    ok(-e "blib/db/forum.db");
    BEGIN { $tests += 1; }
}


my $w   = CPAN::Forum::Test::get_mech();
my $url = CPAN::Forum::Test::get_url();

my %config = read_config();
sub read_config {
    my %c;
    open my $in, '<', "t/CONFIG" or die;
    while (my $line = <$in>) {
        chomp $line;
        my ($k, $v) = split /=/, $line;
        $c{$k} = $v;
    }
    return %c;
}

{
    $w->get_ok($url);
    $w->content_like(qr{CPAN Forum});

    $w->follow_link_ok({ text => 'login' });
    $w->content_like(qr{Login});
    $w->content_like(qr{Nickname});
    $w->submit_form(
        fields => {
            nickname => $config{username},
            password => $config{password},
        },
    );
    $w->content_like(qr{You are logged in as.*$config{username}});
    BEGIN { $tests += 6; }
}

