#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
my $tests;
plan tests => $tests;

use lib qw(t/lib);
use CPAN::Forum::Test;

{
    require_ok('CPAN::Forum::Users');
    BEGIN { $tests += 1; }
}

CPAN::Forum::Test::setup_database();
my @users = @CPAN::Forum::Test::users;

CPAN::Forum::Test::init_db();
{
    my @db_users = CPAN::Forum::Users->retrieve_all;
    is(@db_users, 1, 'one user');
    is($db_users[0]->username, 'testadmin');

	is(CPAN::Forum::Users->count_all(), 1);
    BEGIN { $tests += 3; }
}

{
    # add user
	my $user = CPAN::Forum::Users->create({
		username => $users[0]{username},
		email    => $users[0]{email},
    });
    isa_ok($user, 'CPAN::Forum::Users');
    is($user->username, $users[0]{username});
    is($user->email, $users[0]{email});
    is(length($user->password), 7);

    my @db_users = CPAN::Forum::Users->retrieve_all;
    is(@db_users, 2);
	is(CPAN::Forum::Users->count_all(), 2);
    BEGIN { $tests += 6; }
}


