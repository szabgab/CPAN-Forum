use strict;
use warnings;

use Test::More;
eval {
	require Test::Pod::Coverage;
	import Test::Pod::Coverage;
};
plan skip_all => "Test::Pod::Coverage 1.00 required for testing POD coverage" if $@;
plan tests => 6;
pod_coverage_ok('CPAN::Forum::Markup');
TODO: {
	local $TODO = "Write more documentation";
	pod_coverage_ok('CPAN::Forum');
	pod_coverage_ok('CPAN::Forum::DB::Posts');
	pod_coverage_ok('CPAN::Forum::DB::Groups');
	pod_coverage_ok('CPAN::Forum::DB::Users');
	pod_coverage_ok('CPAN::Forum::DB::Configure');
}

