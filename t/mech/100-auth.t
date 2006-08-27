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


my $w_admin = CPAN::Forum::Test::get_mech();
my $w_user  = CPAN::Forum::Test::get_mech();
my $w_guest = CPAN::Forum::Test::get_mech();
my $url     = CPAN::Forum::Test::get_url();

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
    unlink glob "/tmp/cgisess_*";
    my @session_files = glob "/tmp/cgisess_*";
    is (@session_files, 0);
    BEGIN { $tests += 1; }
}

{
    $w_admin->get_ok($url);
    $w_admin->content_like(qr{CPAN Forum});
    is($w_admin->cookie_jar->as_string, '');


    $w_admin->follow_link_ok({ text => 'login' });
    $w_admin->content_like(qr{Login});
    $w_admin->content_like(qr{Nickname});
    my @session_files = glob "/tmp/cgisess_*";
    is(@session_files, 1);
    my $cookie = '';
    my $cookie_jar = $w_admin->cookie_jar->as_string;
    if ($cookie_jar =~ /cpanforum=(\w+)/) {
        $cookie = $1;
    }
    is($session_files[0], "/tmp/cgisess_$cookie");

    $w_admin->submit_form(
        fields => {
            nickname => $config{username},
            password => $config{password},
        },
    );
    $w_admin->content_like(qr{You are logged in as.*$config{username}});
    is($w_admin->cookie_jar->as_string, $cookie_jar);
    #diag $w_admin->cookie_jar->as_string;
    BEGIN { $tests += 10; }
}
{
    my @session_files = glob "/tmp/cgisess_*";
    is (@session_files, 1);
    BEGIN { $tests += 1; }
}

{
    my $user = CPAN::Forum::Test::register_user(0);
    $w_user->get_ok($url);
    $w_user->content_like(qr{CPAN Forum});
    $w_user->follow_link_ok({ text => 'login' });
    $w_user->content_like(qr{Login});

    $w_user->submit_form(
        fields => {
            nickname => $user->username,
            password => $user->password,
        },
    );
    $w_user->content_like(qr{You are logged in as.*$users[0]{username}});

    BEGIN { $tests += 5; }

}

{
    my ($user) 
        = CPAN::Forum::Users->search({ username => $users[0]{username} });
    $w_guest->get_ok($url);
    $w_guest->content_like(qr{CPAN Forum});
    $w_guest->get_ok("$url/dist/Acme-Bleach");
    $w_guest->follow_link_ok({ text => 'new post' });
    # check if this is the login form

    # next call causes the warning when running with -w
    $w_guest->submit_form(
        fields => {
            nickname => $user->username,
            password => $user->password,
        },
    );
    
    # this seem to be ok when done with real browser
    #diag $w_guest->content;
    $w_guest->content_like(qr{Distribution: Acme-Bleach});
    $w_guest->follow_link_ok({ text => 'logout' });

    BEGIN { $tests += 6; }
}
{
    $w_user->get_ok($url);
    $w_user->content_like(qr{CPAN Forum});
    $w_user->get_ok("$url/dist/Acme-Bleach");
    $w_user->content_like(qr{Acme-Bleach});
    $w_user->follow_link_ok({ text => 'new post' });
    $w_user->content_like(qr{Distribution: Acme-Bleach});

    BEGIN { $tests += 6; }
}

{
    $w_user->follow_link_ok({ text => 'home' });
    $w_user->follow_link_ok({ text => 'mypan' });

    BEGIN { $tests += 2; }
}

