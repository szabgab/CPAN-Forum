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

#use CPAN::Forum::DBI;
#CPAN::Forum::DBI->myinit("$ROOT/db/forum.db");

#use CGI::Application::Test;
#use CPAN::Forum;
#my $cat = CGI::Application::Test->new({
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

__END__
# reject bad usernames
foreach my $email ("adb-?", "Abcde", "asd'er", "ab cd") {
    my $r = $cat->cgiapp(path_info => '/', params => {rm => 'register_process', nickname => "abcde", email => $email});
    like($r, qr{Registration Page});
    like($r, qr{Email must be a valid address writen in lower case letters});
}

my $pw;
my $password;
my $sendmail_count;
# register user
{
    no warnings;
    sub CPAN::Forum::sendmail {
        my %mail = @_;
        #use Data::Dumper;
        #print STDERR Dumper \%mail;
        #print STDERR 
        if ($mail{Message} =~ /your password is: (\w+)/) {
            $password = $1;
        }
        $sendmail_count++;
    }
    use warnings;
}
# TODO: check if the call to submail contains the correct values
{
    $sendmail_count = 0;
    $password = '';
    my $r = $cat->cgiapp(path_info => '/', 
            params => {rm => 'register_process', nickname => $users[0]{username}, email => $users[0]{email}});
    like($r, qr{Registration Page});
    like($r, qr{Thank you for registering});
    like($password, qr{\w{5}});

    is($sendmail_count, 2);
    $pw = $password;
}

# try to register the same user again and see it fails
{
    $sendmail_count = 0;
    $password = '';
    my $r = $cat->cgiapp(path_info => '/', 
            params => {rm => 'register_process', nickname => $users[0]{username}, email => $users[0]{email}});
    like($r, qr{Registration Page});
    like($r, qr{Nickname or e-mail already in use});
    is($sendmail_count, 0);
    is($password, "");
}

