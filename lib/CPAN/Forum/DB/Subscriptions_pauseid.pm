package CPAN::Forum::DB::Subscriptions_pauseid;
use strict;
use warnings;
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
	my @fields = keys %args;
	my $where = join " AND ", map {"$_=?"} @fields;
	$where =~ s/\bpauseid\b/subscriptions_pauseid.pauseid/; # nasty workaround?
	my $sql = "SELECT subscriptions_pauseid.pauseid pauseid, uid, 
                      allposts, starters, followups, announcements,
                      authors.pauseid pauseid_name
               FROM subscriptions_pauseid, authors 
               WHERE authors.id=subscriptions_pauseid.pauseid";
	if ($where) {
		$sql .= " AND $where";
	}
	return ( $sql, @args{@fields} );
}

sub complex_update {
	my ( $self, @args ) = @_;
	$self->_complex_update( @args, 'subscriptions_pauseid' );
}


1;
