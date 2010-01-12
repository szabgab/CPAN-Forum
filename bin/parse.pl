#!/usr/bin/perl
use strict;
use warnings;

# this script is only used to prepare the new parser behind the system.
# It will be deleted once it is deployed

use lib "lib";
use CPAN::Forum::Markup;
my $markup = CPAN::Forum::Markup->new();
my $parser = $markup->parser;

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
	



