#!/usr/bin/perl
use strict;
use warnings;

# this script is only used to prepare the new parser behind the system.
# It will be deleted once it is deployed

use lib "lib";
use CPAN::Forum::Markup;
my $markup = CPAN::Forum::Markup->new();
my $parser = $markup->parser;

my $code = q(
#!/usr/bin/perl

open my $fh, ">>", "filename";
while (<$fh>) {
   print $x . 'sss';
	xxl
}

);
$code = "<code>$code</code>";



my %data = (
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

	'<code>'                   => undef,
	'Hello<code>'              => undef,
	'<code extra><STD></code>' => undef,
	'a<b>c</i>'                => undef,
	'a<b>c'                    => undef,
	'a<i>c'                    => undef,
	'apple<'                   => undef,
);
use Data::Dumper;


#%data = (
#	'apple<code>bob</code>'    => q(<div class="text">apple</div><div class="code">bob</div>),
	#'apple<code><</code>'      => q(<div class="text">apple</div><div class="code">&lt;</div>),
#);
#$::RD_WARN=3;
#$::RD_TRACE=1;


use Test::More "no_plan";
foreach my $k (keys %data) {
	my $out = $parser->entry($k);
	if (defined $data{$k}) {
		if (defined $out) {
			is(join("",@$out), $data{$k}, $k);
		} else {
			is($out, $data{$k}, $k);
		}
	} else {
		if (not defined $out) {
			ok(1, $k);
		} else {
			is((join "", @$out), $data{$k}, $k); # expecting undef
		}
	}
}
	
my $out = $parser->entry($code);
ok(defined($out), "BIG CODE");
##ok(length(join "", @$out) > length ($code));



