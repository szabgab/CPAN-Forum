#!/usr/bin/perl
use strict;
use warnings;

use Test::More "no_plan";
use Test::Exception;

use lib "blib/lib";
use CPAN::Forum;

my %cases = (
	'apple'                    => qr(\s*<div class="text">apple</div>\s*),
	'apple<code><</code>'      => qr(\s*<div class="text">apple</div>\s*<div class="code">&lt;</div>\s*),
	'apple<code><code></code>' => qr(\s*<div class="text">apple</div>\s*<div class="code">&lt;code&gt;</div>\s*),
	'1234567890' x 7           => qr(),
);

my %fails = (
	'apple<B>'             => qr(^ERR no_less_sign$),
	'apple< sd'            => qr(^ERR no_less_sign$),
	'apple<'               => qr(^ERR no_less_sign$),
	'apple<code>sd'        => qr(^ERR open_code_without_closing$),
	'1234567890' x 7 . "x" => qr(^ERR line_too_long$),
);


foreach my $c (sort keys %cases) {
	lives_ok {f($c)} 'Expected to live';
#	like (f($c), $cases{$c});
}

foreach my $c (sort keys %fails) {
	throws_ok {f($c)} $fails{$c}, "OK";
}


sub f {
	CPAN::Forum::_posting_process(@_);
}


