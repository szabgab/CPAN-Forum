#!/usr/bin/perl -w
use strict;

use Test::More tests => 1;
use lib "blib";

BEGIN {
use_ok( 'CPAN::Forum' );
}

diag( "Testing CPAN::Forum $CPAN::Forum::VERSION" );


