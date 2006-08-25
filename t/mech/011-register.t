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

{
    $w->get_ok($url);
    $w->content_like(qr{CPAN Forum});

    $w->follow_link_ok({ text => 'register' });
    $w->content_like(qr{Registration Page});

    BEGIN { $tests += 4; }
}

{
    $w->submit_form(
        fields => {
            nickname => '', 
            email    => 'some@email',
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Need both nickname and password});

    $w->submit_form(
        fields => {
            nickname => '', 
            email    => '',
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Need both nickname and password});

    $w->submit_form(
        fields => {
            nickname => 'xyz', 
            email    => '',
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Need both nickname and password});

    $w->submit_form(
        fields => {
            nickname => 'xyzqwertyuiqwertyuiopqwert', 
            email => 'a@com',
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Nickname must be lower case alphanumeric between 1-25 characters});
    BEGIN { $tests += 8; }
}

# reject bad usernames
foreach my $username ("ab.c", "Abcde", "asd'er", "ab cd") {
    $w->submit_form(
        fields => {
            nickname => $username, 
            email => 'a@com',
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Nickname must be lower case alphanumeric between 1-25 characters});
    BEGIN { $tests += 2*4; }
}

# reject bad email address 
foreach my $email ("adb-?", "Abcde", "asd'er", "ab cd") {
    $w->submit_form(
        fields => {
            nickname => "abcde", 
            email    => $email,
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Email must be a valid address writen in lower case letters});
    BEGIN { $tests += 2*4; }
}




my $pw;
my $password;
my $sendmail_count;
# register user
sub CPAN::Forum::_test_my_sendmail {
    my %mail = @_;
    #use Data::Dumper;
    #print STDERR Dumper \%mail;
    #print STDERR 
    if ($mail{Message} =~ /your password is: (\w+)/) {
        $password = $1;
    }
    $sendmail_count++;
}

# TODO: check if the call to submail contains the correct values
{
    $sendmail_count = 0;
    $password = '';
    $w->submit_form(
        fields => {
            nickname => $users[0]{username}, 
            email    => $users[0]{email},
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Thank you for registering});
    like($password, qr{\w{5}});

    is($sendmail_count, 2);
    $pw = $password;

    BEGIN { $tests += 4; }
}

# try to register the same user again and see it fails
{
    $sendmail_count = 0;
    $password = '';
    $w->back;
    $w->submit_form(
        fields => {
            nickname => $users[0]{username}, 
            email    => $users[0]{email},
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Nickname or e-mail already in use});
    is($sendmail_count, 0);
    is($password, "");

    BEGIN { $tests += 4; }
}

