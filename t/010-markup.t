#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 11;
use Test::Exception;

use lib "blib/lib";
use CPAN::Forum;

my %cases = (
	'apple'                    => qr(\s*<div class="text">apple</div>\s*),
	'apple<code><</code>'      => qr(\s*<div class="text">apple</div>\s*<div class="code">&lt;</div>\s*),
	'apple<code><code></code>' => qr(\s*<div class="text">apple</div>\s*<div class="code">&lt;code&gt;</div>\s*),
);

my %fails = (
	'apple<B>'             => "ERR no_less_sign",
	'apple< sd'            => "ERR no_less_sign",
	'apple<'               => "ERR no_less_sign",
	'apple<code>sd'        => "ERR open_code_without_closing",
	'1234567890' x 7 . "x" => "ERR line_too_long",
);


foreach my $c (sort keys %cases) {
	lives_ok {f($c)} 'Expected to live';
	like (f($c), $cases{$c});
}

foreach my $c (sort keys %fails) {
	throws_ok {f($c)} qr/^$fails{$c}$/, $fails{$c};
}


sub f {
	CPAN::Forum::_posting_process(@_);
}


