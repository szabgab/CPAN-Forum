#!/usr/bin/perl

use strict;
use warnings;

use Test::More "no_plan";


use lib qw(t/lib);
use CPAN::Forum::Test;

setup_database();

use CPAN::Forum::DBI;
CPAN::Forum::DBI->myinit("$ROOT/db/forum.db");

use CGI::Application::Test;
use CPAN::Forum;
my $cat = CGI::Application::Test->new({root => $ROOT, cookie => "cpanforum"});

{
	my $r = $cat->cgiapp('/', '', {});
	like($r, qr{CPAN Forum});
}

{
	my $r = $cat->cgiapp('/register', '', {});
	like($r, qr{Registration Page});
}

{
	my $r = $cat->cgiapp('/', '', {rm => 'register_process', nickname => '', email => ''});
	like($r, qr{Registration Page});
	like($r, qr{Need both nickname and password});
}

{
	my $r = $cat->cgiapp('/', '', {rm => 'register_process', nickname => '', email => 'some@email'});
	like($r, qr{Registration Page});
	like($r, qr{Need both nickname and password});
}

{
	my $r = $cat->cgiapp('/', '', {rm => 'register_process', nickname => 'xyz', email => ''});
	like($r, qr{Registration Page});
	like($r, qr{Need both nickname and password});
}

{
	my $r = $cat->cgiapp('/', '', {rm => 'register_process', nickname => 'xyzqwertyui', email => 'a@com'});
	like($r, qr{Registration Page});
	like($r, qr{Nickname must be lower case alphanumeric between 1-10 characters});
}

# reject bad usernames
foreach my $username ("ab.c", "Abcde", "asd'er", "ab cd") {
	my $r = $cat->cgiapp('/', '', {rm => 'register_process', nickname => $username, email => 'a@com'});
	like($r, qr{Registration Page});
	like($r, qr{Nickname must be lower case alphanumeric between 1-10 characters});
}

# reject bad usernames
foreach my $email ("adb-?", "Abcde", "asd'er", "ab cd") {
	my $r = $cat->cgiapp('/', '', {rm => 'register_process', nickname => "abcde", email => $email});
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
	my $r = $cat->cgiapp('/', '', {rm => 'register_process', nickname => $users[0]{username}, email => $users[0]{email}});
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
	my $r = $cat->cgiapp('/', '', {rm => 'register_process', nickname => $users[0]{username}, email => $users[0]{email}});
	like($r, qr{Registration Page});
	like($r, qr{Nickname or e-mail already in use});
	is($sendmail_count, 0);
	is($password, "");
}


	






