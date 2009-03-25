#!/usr/bin/perl
use strict;
use warnings;

use Test::Most;
my $tests;
plan tests => $tests;

bail_on_fail;

use lib qw(t/lib);
use CPAN::Forum::Test;

{
    require_ok('CPAN::Forum::DB::Users');
    BEGIN { $tests += 1; }
}

CPAN::Forum::Test::setup_database();
exit;
my @users = @CPAN::Forum::Test::users;

CPAN::Forum::Test::init_db();
{
    my @db_users = CPAN::Forum::DB::Users->retrieve_all;
    is(@db_users, 1, 'one user');
    is($db_users[0]->username, 'testadmin');

	is(CPAN::Forum::DB::Users->count_all(), 1);
    BEGIN { $tests += 3; }
}

{
    # add user
	my $user = CPAN::Forum::DB::Users->create({
		username => $users[0]{username},
		email    => $users[0]{email},
    });
    isa_ok($user, 'CPAN::Forum::DB::Users');
    is($user->username, $users[0]{username});
    is($user->email, $users[0]{email});
    is(length($user->password), 7);

    my @db_users = CPAN::Forum::DB::Users->retrieve_all;
    is(@db_users, 2);
	is(CPAN::Forum::DB::Users->count_all(), 2);
    BEGIN { $tests += 6; }
}


