#!/usr/bin/perl
use strict;
use warnings;
use CGI qw();


# this script is only used to prepare the new parser behind the system.
# It will be deleted once it is deployed

use Parse::RecDescent;

my $grammar = q {
	entry      : chunk(s) eodata                  { $item[1] }
	chunk      : text | code                      { $item[1] }
	text       : m{[\t\n -;=?-~]+}                { qq(<div class="text">$item[1]</div>); }
	code       : code_open code_text code_close   {$item[2] }
	code_open  : m{<code>}
	code_text  : m{[\t\n -~]+(?=</code>)}         { qq(<div class="code">) . CGI::escapeHTML($item[1]) . qq(</div>); }
	code_close : m{</code>}
	eodata     : m{^\Z}
};

$Parse::RecDescent::skip = '';
my $parser = new Parse::RecDescent ($grammar) or die "Bad Grammar\n";

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
#	'<b>bold</b> more text'    => q(<div class="text"><b>bold</b> more text</div>),

	'<code>'                   => undef,
	'Hello<code>'              => undef,
	'<code extra><STD></code>' => undef,
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



