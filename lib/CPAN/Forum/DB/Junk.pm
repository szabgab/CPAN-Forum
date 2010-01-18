package CPAN::Forum::DB::Junk;
use strict;
use warnings;
use 5.008;

our $VERSION = '0.18';

use Carp;
#use Digest::SHA qw(sha1_base64);
#use List::MoreUtils qw(none);
use YAML::Tiny ();

use base 'CPAN::Forum::DBI';

sub add_junk {
	my ($self, $code, $data) = @_;

	my $dbh = CPAN::Forum::DBI::db_Main();
	$dbh->do("INSERT INTO junk (field, value) VALUES(?, ?)", undef, $code, YAML::Tiny::Dump($data));

	return;
}

sub get_junk {
	my ($self, $code) = @_;

	my $dbh = CPAN::Forum::DBI::db_Main();
	my $data = $dbh->selectrow_array("SELECT value FROM junk WHERE field=?", undef, $code);
	return YAML::Tiny::Load($data);
}

sub delete_junk {
	my ($self, $code) = @_;

	my $dbh = CPAN::Forum::DBI::db_Main();
	$dbh->do("DELETE FROM junk WHERE field=?", undef, $code);

	return;
}


1;

