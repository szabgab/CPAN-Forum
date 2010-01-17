package CPAN::Forum::DB::Junk;
use strict;
use warnings;
use 5.008;

our $VERSION = '0.16';

use Carp;
#use Digest::SHA qw(sha1_base64);
#use List::MoreUtils qw(none);

use base 'CPAN::Forum::DBI';

sub add_junk {
	my ($self, $code, $args) = @_;

	my $dbh = CPAN::Forum::DBI::db_Main();
#use YAML::Tiny qw(
	$dbh->do("INSERT INTO junk (field, value) VALUES(?, ?)", undef, $code, );
}


1;

