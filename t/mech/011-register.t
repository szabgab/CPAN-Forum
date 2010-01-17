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

my $url   = $ENV{CPAN_FORUM_TEST_URL};
my @users = @t::lib::CPAN::Forum::Test::users;
my $w1    = t::lib::CPAN::Forum::Test::get_mech();
my $w25   = t::lib::CPAN::Forum::Test::get_mech();


{
	t::lib::CPAN::Forum::Test::setup_database();
}
{
	$w1->get_ok($url);
	$w1->content_like(qr{CPAN Forum});

	$w1->follow_link_ok( { text => 'register' } );
	$w1->content_like(qr{Registration Page}) or diag $w1->content;
	BEGIN { $tests += 4; }
}

{
	diag('Make sure cannot register with e-mail only, username only, too long a username');
	$w1->submit_form(
		fields => {
			nickname => '',
			email    => 'some@email',
		},
	);
	$w1->content_like(qr{Registration Page});
	$w1->content_like(qr{Need both nickname and password});

	$w1->submit_form(
		fields => {
			nickname => '',
			email    => '',
		},
	);
	$w1->content_like(qr{Registration Page});
	$w1->content_like(qr{Need both nickname and password});

	$w1->submit_form(
		fields => {
			nickname => 'xyz',
			email    => '',
		},
	);
	$w1->content_like(qr{Registration Page});
	$w1->content_like(qr{Need both nickname and password});

	my $too_long_name = 'xyzqwertyuiqwertyuiopqwert';
	diag( length $too_long_name );
	$w1->submit_form(
		fields => {
			nickname => $too_long_name,
			email    => 'a@com',
		},
	);
	$w1->content_like(qr{Registration Page});
	$w1->content_like(qr{Nickname must be lower case alphanumeric between 1-25 characters});
	BEGIN { $tests += 8; }
}

my @bad_usernames;

BEGIN {
	@bad_usernames = ( "ab.c", "Abcde", "asd'er", "ab cd" );
}
{
	diag('reject various bad usernames');
	foreach my $username (@bad_usernames) {
		$w1->submit_form(
			fields => {
				nickname => $username,
				email    => 'a@com',
			},
		);
		$w1->content_like(qr{Registration Page});
		$w1->content_like(qr{Nickname must be lower case alphanumeric between 1-25 characters});
	}
	BEGIN { $tests += @bad_usernames * 2; }
}

my @bad_emails;

BEGIN {
	@bad_emails = ( "adb-?", "Abcde", "asd'er", "ab cd" );
}
{
	diag('reject various bad email address');
	foreach my $email (@bad_emails) {
		$w1->submit_form(
			fields => {
				nickname => "abcde",
				email    => $email,
			},
		);
		$w1->content_like(qr{Registration Page});
		$w1->content_like(qr{Email must be a valid address writen in lower case letters});
	}
	BEGIN { $tests += @bad_emails * 2; }
}


diag('register user');

# TODO: check if the second mail is sent to the administrator and if it does not contain the password?
{
	@CPAN::Forum::messages = ();
	$w1->submit_form(
		fields => {
			nickname => $users[0]{username},
			email    => $users[0]{email},
		},
	);
	$w1->content_like(qr{Registration Page});
	$w1->content_like(qr{Thank you for registering});

	#explain \@CPAN::Forum::messages;

	# TODO: disable these when testing with real web server
	is( scalar(@CPAN::Forum::messages), 2, 'two mails sent' );
	my ($pw) = $CPAN::Forum::messages[0]{Message} =~ qr/your password is: (\w+)/;
	diag "Password: $pw";
	like( $pw, qr{\w{5}}, 'password send' );
	my $dbh = t::lib::CPAN::Forum::Test::get_dbh();
	my ( $uid, $sha1_in_db ) =
		$dbh->selectrow_array( "SELECT id, sha1 FROM users WHERE username=?", undef, $users[0]{username} );
	is( $uid, 2, 'uid is 2' );
	isnt( $sha1_in_db, $pw, 'the sent password is not the same as the one in the database as the latter is hashed' );

	BEGIN { $tests += 6; }
}

# TODO: Make sure the passwords can be long enough (up to 20 characters?)

# diag('TODO try to register the same username or the same e-mail twice')
# TODO check for case in username and email and make sure they wont collide!


diag('try to register the same user again and see it fails');
{
	@CPAN::Forum::messages = ();
	$w1->back;
	$w1->submit_form(
		fields => {
			nickname => $users[0]{username},
			email    => $users[0]{email},
		},
	);
	$w1->content_like(qr{Registration Page});
	$w1->content_like(qr{Nickname or e-mail already in use});

	# TODO: disable these when testing with real web server
	is_deeply( \@CPAN::Forum::messages, [], 'no e-mails sent' );
	BEGIN { $tests += 3; }
}


diag('register with 25 long username');
{
	$w25->get_ok("$url/register/");
	@CPAN::Forum::messages = ();
	diag "$users[2]{username} $users[2]{email}";
	$w25->submit_form(
		fields => {
			nickname => $users[2]{username},
			email    => $users[2]{email},
		},
	);

	#diag $w25->content;
	$w25->content_like(qr{Registration Page});
	$w25->content_like(qr{Thank you for registering});

	#explain \@CPAN::Forum::messages;

	# TODO: disable these when testing with real web server
	is( scalar(@CPAN::Forum::messages), 2, 'two mails sent' );
	my ($pw) = $CPAN::Forum::messages[0]{Message} =~ qr/your password is: (\w+)/;
	diag "Password: $pw";
	like( $pw, qr{\w{5}}, 'password send' );
	my $dbh = t::lib::CPAN::Forum::Test::get_dbh();
	my ( $uid, $sha1_in_db ) =
		$dbh->selectrow_array( "SELECT id, sha1 FROM users WHERE username=?", undef, $users[2]{username} );
	TODO: {
		local $TODO =
			'Maybe we should first check for duplicates and only after that insert to avoid increasing the sequence';
		is( $uid, 3, 'uid is 3' );
	}
	isnt( $sha1_in_db, $pw, 'the sent password is not the same as the one in the database as the latter is hashed' );

	BEGIN { $tests += 7; }
}
# TODO try to login with the given password with the same browser,
# and then with another browser



# TODO check when submitting same code twice
# submitting incorrect code
# submitting e-mail and not nickname
{
	diag('Reset password with the lost password form');
	@CPAN::Forum::messages = ();
	my $w2    = t::lib::CPAN::Forum::Test::get_mech();
	$w2->get_ok($url);
	$w2->follow_link_ok( { text => 'login' } );
	$w2->follow_link_ok( { text => 'reset your password here' } );
	#diag $w2->content;
	$w2->content_like(qr{Please fill in your username or email:});
	$w2->submit_form(
		form_name => 'reset_password_request',
		fields => {
			username => $users[0]{username},
		},
	);
	$w2->content_like(qr{Email sent with code});
	is( scalar(@CPAN::Forum::messages), 1, 'one message sent' );
	is ($CPAN::Forum::messages[0]{To}, $users[0]{email}, 'sent to the correct e-mail address');
	my $rm = 'reset_password_form';
	my ($code) = $CPAN::Forum::messages[0]{Message} =~ qr{http://\S+/$rm\?code=(\S+)}x;
	ok($code, 'has code') or explain \@CPAN::Forum::messages;
	diag "Code: $code";

	my $new_password = 'abcdef';
	$w2->get_ok("$url/$rm");
	$w2->submit_form(
		form_name => 'reset_password',
		fields => {
			code      => $code,
			password  => $new_password,
			password2 => $new_password,
		},
	);
	$w2->content_like(qr{Password was reset});

	
	my $w3    = t::lib::CPAN::Forum::Test::get_mech();
	$w3->get_ok($url);
	$w3->content_unlike(qr{You are logged in});
	$w3->get_ok("$url/login");
	$w3->submit_form(
		fields => {
			nickname => $users[0]{username},
			password => $new_password,
		},
	);
	$w3->content_like(qr{You are logged in as.*$users[0]{username}});
	BEGIN { $tests += 7; }
}


