package CPAN::Forum::DB::Groups;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('groups');
__PACKAGE__->columns(Primary   => qw/id/);
__PACKAGE__->columns(Essential => qw/id name version pauseid/);
__PACKAGE__->columns(Others    => qw/gtype status rating review_count/);

__PACKAGE__->has_many(posts         => "CPAN::Forum::DB::Posts");
__PACKAGE__->has_many(subscriptions => "CPAN::Forum::DB::Subscriptions");
__PACKAGE__->has_a   (pauseid       => "CPAN::Forum::DB::Authors");

__PACKAGE__->set_sql(count_like     => "SELECT count(*) FROM __TABLE__ WHERE %s LIKE '%s'");
__PACKAGE__->set_sql(count          => "SELECT count(*) FROM __TABLE__ WHERE %s = '%s'");

use List::MoreUtils qw(none);

sub info_by {
    my ($self, $field, $value) = @_;
    my @FIELDS = qw(id name);
    Carp::croak("Invalid field '$field'") if none {$field  eq $_} @FIELDS;

    my $sql = "SELECT groups.id id, name, status, groups.pauseid, authors.pauseid pauseid_name
               FROM groups, authors
               WHERE groups.$field=? AND authors.id=groups.pauseid";
    return $self->_fetch_single_hashref($sql, $value);
}
sub list_ids_by {
    my ($self, $field, $value) = @_;
    Carp::croak("Invalid field '$field'") if $field ne 'pauseid';
    my $sql = "SELECT id FROM groups WHERE $field=?";
    return $self->_select_column($sql, $value);
}


sub dump_groups {
    my ($self) = @_;
    my $sql = "SELECT id, name FROM groups";
    return $self->_dump($sql); 
}

sub groups_by_gtype {
    my ($self, $value) = @_;
    #return {} if not %args; # ?
    my $sql = "SELECT id, name FROM groups WHERE gtype=?";
    return $self->_fetch_hashref($sql, $value);
}
sub groups_by_name {
    my ($self, $value) = @_;
    #return {} if not %args; # ?
    $value = '%' . $value . '%';
    my $sql = "SELECT id, name FROM groups WHERE name LIKE ?";
    return $self->_fetch_hashref($sql, $value);
}

sub add {
    my ($self, %args) = @_;

    Carp::croak("add requires name and gtype fields") 
        if not $args{name} or not defined $args{gtype} or not $args{pauseid};  #version

    my ($fields, $placeholders, @values) = $self->_prep_insert(\%args);
    my $sql = "INSERT INTO groups ($fields) VALUES ($placeholders)";
    my $dbh = CPAN::Forum::DBI::db_Main();
    $dbh->do($sql, undef, @values);

    return $self->info_by(name => $args{name});
}

1;

