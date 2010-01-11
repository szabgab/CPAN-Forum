package CPAN::Forum::DB::Groups;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';

use List::MoreUtils qw(none);

sub info_by {
	my ( $self, $field, $value ) = @_;
	my @FIELDS = qw(id name);
	Carp::croak("Invalid field '$field'") if none { $field eq $_ } @FIELDS;

	my $sql = "SELECT groups.id AS id, name, groups.pauseid, authors.pauseid AS pauseid_name
               FROM groups, authors
               WHERE groups.$field=? AND authors.id=groups.pauseid";
	return $self->_fetch_single_hashref( $sql, $value );
}

sub list_ids_by {
	my ( $self, $field, $value ) = @_;
	Carp::croak("Invalid field '$field'") if $field ne 'pauseid';
	my $sql = "SELECT id FROM groups WHERE $field=?";
	return $self->_select_column( $sql, $value );
}


sub dump_groups {
	my ($self) = @_;
	my $sql = "SELECT id, name FROM groups";
	return $self->_dump($sql);
}

sub groups_by_gtype {
	my ( $self, $value ) = @_;

	#return {} if not %args; # ?
	my $sql = "SELECT id, name FROM groups WHERE gtype=?";
	return $self->_fetch_hashref( $sql, $value );
}

sub groups_by_name {
	my ( $self, $value ) = @_;

	#return {} if not %args; # ?
	$value = '%' . $value . '%';
	my $sql = "SELECT id, name FROM groups WHERE name LIKE ?";
	return $self->_fetch_hashref( $sql, $value );
}

sub add {
	my ( $self, %args ) = @_;

	Carp::croak("add requires name and gtype fields")
		if not $args{name}
			or not defined $args{gtype}
			or not $args{pauseid}; #version

	my ( $fields, $placeholders, @values ) = $self->_prep_insert( \%args );
	my $sql = "INSERT INTO groups ($fields) VALUES ($placeholders)";
	my $dbh = CPAN::Forum::DBI::db_Main();
	$dbh->do( $sql, undef, @values );

	return $self->info_by( name => $args{name} );
}

sub names_by_name {
	my ( $self, $value ) = @_;
	$value = '%' . $value . '%';
	my $sql = "SELECT name FROM groups WHERE name LIKE ? ORDER BY name";
	return $self->_fetch_arrayref_of_hashes( $sql, $value );
}

sub names_by_pauseidstr {
	my ( $self, $value ) = @_;
	my $sql = "SELECT name FROM groups, authors WHERE authors.pauseid=? AND authors.id=groups.pauseid";
	return $self->_fetch_arrayref_of_hashes( $sql, $value );
}

sub get_data_by_name {
	my ( $self, $name ) = @_;
	my $sql = "SELECT version, pauseid FROM groups WHERE name = ?";
	return $self->_fetch_hashref( $sql, $name );
}

sub update_data_by_name {
	my ( $self, $name, $data ) = @_;
	my $sql = "UPDATE groups SET version=?, pauseid=? WHERE name = ?";

	my $dbh = CPAN::Forum::DBI::db_Main();
	$dbh->do( $sql, undef, $data->{version}, $data->{pauseid}, $name );

}

#        my $author = CPAN::Forum::DB::Authors->get_author_by_pauseid($name);

1;

