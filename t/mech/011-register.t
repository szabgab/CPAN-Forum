use strict;
use warnings;

use Test::Most;

plan skip_all => 'Need CPAN_FORUM_DB_FILE and CPAN_FORUM_TEST_URL' 
	if not $ENV{CPAN_FORUM_DB_FILE} or not $ENV{CPAN_FORUM_TEST_URL};

plan tests => 36;

bail_on_fail;

use t::lib::CPAN::Forum::Test;
my @users = @t::lib::CPAN::Forum::Test::users;
my $w = t::lib::CPAN::Forum::Test::get_mech();


{
    t::lib::CPAN::Forum::Test::setup_database();
    ok(-e $ENV{CPAN_FORUM_DB_FILE});
}

{
    $w->get_ok($ENV{CPAN_FORUM_TEST_URL});
    $w->content_like(qr{CPAN Forum});

    $w->follow_link_ok({ text => 'register' });
    $w->content_like(qr{Registration Page}) or diag $w->content;
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
}




my @messages;
sub CPAN::Forum::_test_my_sendmail {
    my %mail = @_;
    my @fields = qw(Message From Subject To);
    my %m;
    @m{@fields} = @mail{@fields};
    push @messages, \%m;
    #use Data::Dumper;
    #print STDERR Dumper \%mail;
    #print STDERR 
}
# register user

# TODO: check if the call to submail contains the correct values
my $pw;
{
    $w->submit_form(
        fields => {
            nickname => $users[0]{username}, 
            email    => $users[0]{email},
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Thank you for registering});
    #explain \@messages;
    
    # TODO: disable these when testing with real web server
    is(scalar(@messages), 2, 'two mails sent');
    ($pw) = $messages[0]{Message} =~ qr/your password is: (\w+)/;
    diag "Password: $pw";
    like($pw, qr{\w{5}}, 'password send');
}

# try to register the same user again and see it fails
{
    @messages = ();
    $w->back;
    $w->submit_form(
        fields => {
            nickname => $users[0]{username}, 
            email    => $users[0]{email},
        },
    );
    $w->content_like(qr{Registration Page});
    $w->content_like(qr{Nickname or e-mail already in use});

    # TODO: disable these when testing with real web server
    is_deeply(\@messages, [], 'no e-mails sent');
}

