#!/usr/bin/perl -w

use strict;
use Test::More tests => 3;
use Test::WWW::Mechanize;

my $url = $ENV{CPAN_FORUM_URL};

SKIP: {
	skip "Need to have CPAN_FORUM_URL to run these tests. See readme", 3 if not defined $url;

my $mech = Test::WWW::Mechanize->new();

ok(1);
ok(1);
ok(1);

}
