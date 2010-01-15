#!/usr/bin/perl
use strict;
use warnings;

use Test::Most;
use Test::Script;

use File::Find::Rule   ();
use File::Temp         ();
use File::Spec         ();

my $tmp = File::Temp::tempdir( CLEANUP => 1 );
my $out = File::Spec->catfile( $tmp, 'out.txt' );
my $err = File::Spec->catfile( $tmp, 'err.txt' );


my @files = File::Find::Rule->relative->file->name('*.pm')->in('lib');

plan( tests => 4 * @files + 1 );

foreach my $file (@files) {
	my $module = $file;
	$module =~ s/[\/\\]/::/g;
	$module =~ s/\.pm$//;

	if ( $module eq 'CPAN::Forum::Handler' ) {
		foreach ( 1 .. 4 ) {
			Test::More->builder->skip("Not testing the mod_perl2 handler");
		}
		next;
	}

	system qq($^X -e "require $module; print 'ok';" > $out 2>$err);
	my $err_data = slurp($err);
	is( $err_data, '', "STDERR of $file" );

	my $out_data = slurp($out);
	is( $out_data, 'ok', "STDOUT of $file" );

	require_ok($module);
	ok( $module->VERSION, "$module: Found \$VERSION" );
}

script_compiles_ok('bin/cpan_forum_daemon.pl');

# Bail out if any of the tests failed
BAIL_OUT("Aborting test suite") if scalar grep { not $_->{ok} } Test::More->builder->details;

######################################################################
# Support Functions

sub slurp {
	my $file = shift;
	open my $fh, '<', $file or die $!;
	local $/ = undef;
	my $buffer = <$fh>;
	close $fh;
	return $buffer;
}

