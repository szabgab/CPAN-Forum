#!/usr/bin/perl
use strict;
use warnings;
use CGI qw();


# this script is only used to prepare the new parser behind the system.
# It will be deleted once it is deployed

use Parse::RecDescent;

my $grammar = q {
	entry: chunk(s) eodata  { $item[1] }
	chunk: text | code
	text: m{[\w ]+} { qq(<div class="text">$item[1]</div>); }
	code: opencode codetext closecode {$item[2] }
	opencode:  m{<code>}
	closecode: m{</code>}
	codetext: m{[\w <>\$]+(?=</code>)} { qq(<div class="code">) . CGI::escapeHTML($item[1]) . qq(</div>); }
	eodata:   m{^\Z}
};
	#codetext: m{[ -.0-~\s]+} { qq(<div class="code">$item[1]</div>); }

$Parse::RecDescent::skip = '';
my $parser = new Parse::RecDescent ($grammar) or die "Bad Grammar\n";

my %data = (
	'Hello world'              => q(<div class="text">Hello world</div>),
	' World'                   => q(<div class="text"> World</div>),
	'<code>'                   => undef,
	'Hello<code>'              => undef,
	'<code>program</code>'     => q(<div class="code">program</div>),
	'apple<code><</code>'      => q(<div class="text">apple</div><div class="code">&lt;</div>),
	'<code> $x < $y </code>'   => q(<div class="code"> $x &lt; $y </div>),
	'<code extra><STD></code>' => undef,
	'<code><STD></code>'       => q(<div class="code">&lt;STD&gt;</div>), 
);
use Data::Dumper;
#print Dumper $parser->entry($text);
#$::RD_WARN=3;
#$::RD_TRACE=1;

use Test::More "no_plan";
foreach my $k (keys %data) {
	my $out = $parser->entry($k);
	if (defined $data{$k}) {
		if (defined $out) {
			is(join("",@$out), $data{$k});
		} else {
			is($out, $data{$k});
		}
	} else {
		ok(not defined $out); # expecting undef
	}
}
	


