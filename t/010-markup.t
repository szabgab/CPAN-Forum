#!/usr/bin/perl
use strict;
use warnings;

use Test::More "no_plan";
use Test::Exception;



use lib "blib/lib";
use CPAN::Forum::Markup;

my $long = "x234567890" x 6 . "qwertyuiop" x 4;
my $long_new = "x234567890" x 6 . "\n" . "+" . "qwertyuiop" x 4;
my $long2 = "x234567890" x 10 . "abcdef" x 20;
my $long2_new = "x234567890" x 6 . "\n" . "+" . "1234567890" x 4 . "\n" . "+" . "abcdef" x 13 . "\n" . "+" . "abcdef" x 7;
is(CPAN::Forum::Markup::split_rows("some text", 60), "some text");
#is(CPAN::Forum::Markup::split_rows($long, 61), $long_new);
#is(CPAN::Forum::Markup::split_rows($long2, 61), $long2_new);

my $markup = CPAN::Forum::Markup->new();

my $TEXT = '<div class="text">';
my $END  = '</div>';
my $CODE = '<div class="code">';

my %cases = (
	'apple'                    => $TEXT . 'apple' . $END,
	'apple<code><</code>'      => $TEXT . 'apple' . $END . $CODE . '&lt;' . $END,
	'apple<code><code></code>' => $TEXT . 'apple' . $END . $CODE . '&lt;code&gt;' . $END,
	'x234567890' x 7           => $TEXT . 'x234567890' x 7   . $END,
	'x234567890' x 100         => $TEXT . 'x234567890' x 100 . $END,
	'Hello world'              => $TEXT . 'Hello world' . $END,
	'<code>program</code>'     => $CODE . 'program' . $END,
	'<code><STD></code>'       => $CODE . '&lt;STD&gt;' . $END,

	'Hello world'              => $TEXT . 'Hello world' . $END,
	' World'                   => $TEXT . ' World' . $END,
	'apple<code>bob</code>'    => $TEXT . 'apple' . $END . $CODE . 'bob' . $END,
	'<code>program</code>'     => $CODE . 'program' . $END,
	'apple<code><</code>'      => $TEXT . 'apple' . $END . $CODE . '&lt;' . $END,
	'<code> $x < $y </code>'   => $CODE . ' $x &lt; $y ' . $END,
	'<code><STD></code>'       => $CODE . '&lt;STD&gt;' . $END,
	'some; strange $%^& text'  => $TEXT . 'some; strange $%^& text' . $END,
	'<b>bold</b> more text'    => $TEXT . '<b>bold</b> more text' . $END,
	'a<b>c</b><code>x</code>d' => $TEXT . 'a<b>c</b>' . $END . $CODE . 'x' . $END . $TEXT . 'd' . $END,
	'a<b>c</b><code>x</code>d<code>y</code>' => $TEXT . 'a<b>c</b>' . $END . $CODE . 'x' . $END . $TEXT . 'd' . $END . $CODE . 'y' . $END,
	'a<i>c</i><code>x</code>d<code>y</code>' => $TEXT . 'a<i>c</i>' . $END . $CODE . 'x' . $END . $TEXT . 'd' . $END . $CODE . 'y' . $END,
	'a<b>c</b>d<i>x</i>f'      => $TEXT . 'a<b>c</b>d<i>x</i>f' . $END,
	'a<B>c</B>d<I>x</I>f'      => $TEXT . 'a<b>c</b>d<i>x</i>f' . $END,
	'&lt;'                     => $TEXT . '&lt;' . $END,
	'<p>text</p>'              => $TEXT . '<p>text</p>' . $END,
	'<P>text</P>'              => $TEXT . '<p>text</p>' . $END,
	'<P>text</p>'              => $TEXT . '<p>text</p>' . $END,
	'<br />'                   => $TEXT . '<br />' . $END,
	'<br />hello'              => $TEXT . '<br />hello' . $END,
	'<br>hello'                => $TEXT . '<br />hello' . $END,
	'<BR>hello'                => $TEXT . '<br />hello' . $END,
	'<code><P></code>'         => $CODE . '&lt;P&gt;' . $END,
	'<a href=http://bla>text</a>'   => $TEXT . '<a href="http://bla">text</a>' . $END,
	'<A href=http://blb>text</a>'   => $TEXT . '<a href="http://blb">text</a>' . $END,
	'<A HREF=http://blc>text</a>'   => $TEXT . '<a href="http://blc">text</a>' . $END,
	'<A HREF="http://bld">text</a>' => $TEXT . '<a href="http://bld">text</a>' . $END,
	'<A HREF=mailto:a@b.c>addr</a>' => $TEXT . '<a href="mailto:a@b.c">addr</a>' . $END,
	'<p>bright <b>new</b> world</p>' => $TEXT . '<p>bright <b>new</b> world</p>' . $END, 


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
	'<p>text'                  => undef,
	'<a href=htt://bla>text</a>' => undef,
	'<a href=javascript>text</a>' => undef,
);


foreach my $c (sort keys %cases) {
	lives_ok {f($c)} 'Expected to live';
	is(f($c), $cases{$c}, $c);
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
	ok(length($out) > length ($code)) or print STDERR $out;
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

CODE
I am using Parse::RecDescent to validate the input on this forum. Right now it can give OK/NOT OK but I'd like to be a bit more specific. E.g.I'd like to give differen error messages 
if there is a not approved HTML tag such as &lt;img&gt; in the text 
or if there is an opening tag withou a closing tag
or just a single &lt; mark somewhere

