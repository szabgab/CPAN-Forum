package CPAN::Forum::DB::Subscriptions_all;
use strict;
use warnings;

our $VERSION = '0.17';

use Carp;
use base 'CPAN::Forum::DBI';


sub find {
	my ( $self, %args ) = @_;
	my ( $sql,  @args ) = $self->_find(%args);
	return $self->_fetch_arrayref_of_hashes( $sql, @args );
}

sub find_one {
	my ( $self, %args ) = @_;

	my ( $sql, @args ) = $self->_find(%args);

	return $self->_fetch_single_hashref( $sql, @args );
}

sub _find {
	my ( $self, %args ) = @_;

	# check if keys of args is uid
	my ( $where, @values ) = $self->_prep_where( \%args );
	my $sql = "SELECT id, allposts, starters, followups, announcements
              FROM subscriptions_all";
	if ($where) {
		$sql .= " WHERE $where";
	}
	return ( $sql, @values );
}

sub complex_update {
	my ( $self, @args ) = @_;
	$self->_complex_update( @args, 'subscriptions_all' );
}


1;
