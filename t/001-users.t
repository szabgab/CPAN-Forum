#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More "no_plan";

use lib qw(t/lib);
use CPAN::Forum::Test;

setup_database();
ok(-e "blib/db/forum.db");

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
	my $r = $cat->cgiapp('/new_post', '', {});
	like($r, qr{Location: http://test-host/login});

#TODO: {
#	local $TODO = "do real redirection here";
#	unlike($r, qr{<HTML>}i);
#	}	
}

#{
#	my $r = $cat->cgiapp('/login', '', {});
#	like($r, qr{Login});
#}

