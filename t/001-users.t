#!/usr/bin/perl -w

use strict;

use Test::More tests => 4;
use File::Copy qw(copy);

use lib ("blib", "t/lib");

chdir "blib";
copy "../t/CONFIG", ".";

system "$^X bin/setup.pl";
ok(-e "db/forum.db");
system "$^X bin/populate.pl ../t/02packages.details.txt";

ok(-e "db/modules.txt");
chdir "..";
use constant ROOT => "blib";  

use CPAN::Forum::DBI;
CPAN::Forum::DBI->myinit(ROOT . "/db/forum.db");

use CGI::Application::Test;
use CPAN::Forum;
my $cat = CGI::Application::Test->new({root => ROOT, cookie => "cpanforum"});



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

