package CPAN::Forum::DB::Configure;
use strict;
use warnings;

our $VERSION = '0.16';

use Carp;
use base 'CPAN::Forum::DBI';

my %default = (
	flood_control_time_limit => 10,
);


sub param {
	my ( $self, $field ) = @_;

	my $value = $self->get_value($field);
	return $value if defined $value;
	return $default{$field} if defined $default{$field};
	return;
}

sub set_field_value {
	my ( $self, $field, $value ) = @_;
	return if not defined $field;

	$value = '' if not defined $value;

	my $dbh = CPAN::Forum::DBI::db_Main();
	my $hr = $self->_fetch_single_hashref( "SELECT field, value FROM configure WHERE field=?", $field );
	if ($hr) {
		$dbh->do( "UPDATE configure SET value=? WHERE field=?", undef, $value, $field );
	} else {
		$dbh->do( "INSERT INTO configure (field, value) VALUES(?, ?)", undef, $field, $value );
	}
	return;
}

sub get_value {
	my ( $self, $field ) = @_;
	return if not $field;

	my $sql = "SELECT value FROM configure WHERE field=?";
	return $self->_fetch_single_value( $sql, $field );
}

sub get_all_pairs {
	my ($self) = @_;

	my $dbh = CPAN::Forum::DBI::db_Main();
	my $sth = $dbh->prepare("SELECT field, value FROM configure");
	$sth->execute;
	my %data;
	while ( my ( $field, $value ) = $sth->fetchrow_array ) {
		$data{$field} = $value;
	}
	return \%data;
}


1;

