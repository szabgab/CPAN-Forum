#!/usr/bin/perl
use strict;
use warnings;

use Test::More "no_plan";
use Test::Exception;

use lib "blib/lib";
use CPAN::Forum::Markup;

my $markup = CPAN::Forum::Markup->new();

my %cases = (
	'apple'                    => q(<div class="text">apple</div>),
	'apple<code><</code>'      => q(<div class="text">apple</div><div class="code">&lt;</div>),
	'apple<code><code></code>' => q(<div class="text">apple</div><div class="code">&lt;code&gt;</div>),
	'1234567890' x 7           => q(<div class="text">) . '1234567890' x 7   . q(</div>),
	'1234567890' x 100         => q(<div class="text">) . '1234567890' x 100 . q(</div>),
	'Hello world'              => q(<div class="text">Hello world</div>),
	'<code>program</code>'     => q(<div class="code">program</div>),
	'<code><STD></code>'       => q(<div class="code">&lt;STD&gt;</div>),

	'Hello world'              => q(<div class="text">Hello world</div>),
	' World'                   => q(<div class="text"> World</div>),
	'apple<code>bob</code>'    => q(<div class="text">apple</div><div class="code">bob</div>),
	'<code>program</code>'     => q(<div class="code">program</div>),
	'apple<code><</code>'      => q(<div class="text">apple</div><div class="code">&lt;</div>),
	'<code> $x < $y </code>'   => q(<div class="code"> $x &lt; $y </div>),
	'<code><STD></code>'       => q(<div class="code">&lt;STD&gt;</div>), 
	'some; strange $%^& text'  => q(<div class="text">some; strange $%^& text</div>),
	'<b>bold</b> more text'    => q(<div class="text"><b>bold</b> more text</div>),
	'a<b>c</b><code>x</code>d' => q(<div class="text">a<b>c</b></div><div class="code">x</div><div class="text">d</div>),
	'a<b>c</b><code>x</code>d<code>y</code>' => q(<div class="text">a<b>c</b></div><div class="code">x</div><div class="text">d</div><div class="code">y</div>),
	'a<i>c</i><code>x</code>d<code>y</code>' => q(<div class="text">a<i>c</i></div><div class="code">x</div><div class="text">d</div><div class="code">y</div>),
	'a<b>c</b>d<i>x</i>f'      => q(<div class="text">a<b>c</b>d<i>x</i>f</div>),


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
	'<code>'                   => undef,
	'Hello<code>'              => undef,
	'<code extra><STD></code>' => undef,
	'a<b>c</i>'                => undef,
	'a<b>c'                    => undef,
	'a<i>c'                    => undef,
	'apple<'                   => undef,
);


foreach my $c (sort keys %cases) {
	lives_ok {f($c)} 'Expected to live';
	is(f($c), $cases{$c});
}

foreach my $c (sort keys %fails) {
	my $ret = eval {f($c)};
	ok(not(defined $ret), "OK");
	#throws_ok {f($c)} $fails{$c}, "OK";
}


my $data = join "", <DATA>;
foreach my $code (split /CODE/, $data) {
	#print STDERR $code;
	my $out = $markup->posting_process($code);
	ok(defined($out), "BIG CODE");
	ok(length($out) > length ($code));
}


sub f {
	$markup->posting_process(@_);
}

__DATA__
<code>
#!/usr/bin/perl

open my $fh, ">>", "filename";
while (<$fh>) {
   print $x . 'sss';
	xxl
}

</code>
CODE
some
<code>
#!/usr/bin/perl

while (<qqrq>) {
  more todo
}

1;
</code>

