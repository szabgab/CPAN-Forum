#!/usr/bin/perl
use strict;
use warnings;

use Test::More "no_plan";
use Test::Exception;

use lib "blib/lib";
use CPAN::Forum::Markup;

my $markup = CPAN::Forum::Markup->new();

my %cases = (
	'apple'                    => qr(\s*<div class="text">apple</div>\s*),
	'apple<code><</code>'      => qr(\s*<div class="text">apple</div>\s*<div class="code">&lt;</div>\s*),
	'apple<code><code></code>' => qr(\s*<div class="text">apple</div>\s*<div class="code">&lt;code&gt;</div>\s*),
	'1234567890' x 7           => qr(1234567890),
	'1234567890' x 100         => qr(1234567890),
	"Hello world"              => qr(<div class="text">Hello world</div>),
	"<code>program</code>"     => qr(<div class="code">program</div>),
	"<code><STD></code>"       => qr(<div class="code">&lt;STD&gt;</div>),
);

my %fails = (
	'apple<B>'             => qr(^ERR no_less_sign$),
	'apple<b>'             => qr(^ERR no_less_sign$),
	'apple< sd'            => qr(^ERR no_less_sign$),
	'apple<'               => qr(^ERR no_less_sign$),
	'apple<x'              => qr(^ERR no_less_sign$),
	'<code >xyz</code>'    => qr(^ERR no_less_sign$),
#	'1234567890' x 7 . "x" => qr(^ERR line_too_long$),
	'apple<code>sd'        => qr(^ERR open_code_without_closing$),
	"<code>"               => qr(^ERR open_code_without_closing$),
	"Hello<code>"          => qr(^ERR open_code_without_closing$),
);

my %data = (
#	"<code extra><STD></code>" => 
);


foreach my $c (sort keys %cases) {
	lives_ok {f($c)} 'Expected to live';
	like (f($c), $cases{$c});
}

foreach my $c (sort keys %fails) {
	throws_ok {f($c)} $fails{$c}, "OK";
}


sub f {
	$markup->posting_process(@_);
}


