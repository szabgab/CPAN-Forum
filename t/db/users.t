#!/usr/bin/perl
use strict;
use warnings;

use Test::Most;

plan skip_all => 'Need CPAN_FORUM_TEST_DB and CPAN_FORUM_TEST_USER and CPAN_FORUM_LOGFILE'
	if not $ENV{CPAN_FORUM_TEST_DB}
		or not $ENV{CPAN_FORUM_TEST_USER}
		or not $ENV{CPAN_FORUM_LOGFILE};

my $tests;
plan tests => $tests;

bail_on_fail;

use t::lib::CPAN::Forum::Test;

{
	require_ok('CPAN::Forum::DB::Users');
	BEGIN { $tests += 1; }
}

t::lib::CPAN::Forum::Test::setup_database();

my @users = @t::lib::CPAN::Forum::Test::users;

t::lib::CPAN::Forum::Test::init_db();
{
	my $db_users = CPAN::Forum::DB::Users->retrieve_all;
	is( @$db_users, 1, 'one user' );

	#    diag explain $db_users->[0];
	is( $db_users->[0]->{username}, 'testadmin' );

	is( CPAN::Forum::DB::Users->count_all(), 1 );
	BEGIN { $tests += 3; }
}

{

	# add user
	my $user = CPAN::Forum::DB::Users->add_user(
		{   username => $users[0]{username},
			email    => $users[0]{email},
		}
	);
	is( $user->{username}, $users[0]{username} );
	is( $user->{email},    $users[0]{email} );

	#    is(length($user->{password}), 7);

	my $db_users = CPAN::Forum::DB::Users->retrieve_all;
	is( @$db_users,                          2 );
	is( CPAN::Forum::DB::Users->count_all(), 2 );
	BEGIN { $tests += 4; }
}


