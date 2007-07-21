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

sub info_by {
    my ($self, $field, $value) = @_;
    Carp::croak("Invalid field '$field'") if $field ne 'id' and $field ne 'name';

    my $sql = "SELECT groups.id id, name, status, groups.pauseid, authors.pauseid pauseid_name
               FROM groups, authors
               WHERE $field=? AND authors.id=groups.pauseid";
    return $self->_fetch_single_hashref($sql, $value);
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
    my $sql = "INSERT INTO groups (name, version, gtype, pauseid) VALUES (?, ?, ?, ?)";
    my $dbh = CPAN::Forum::DBI::db_Main();
    $dbh->do($sql, undef, @args{qw(name version gtype pauseid)});

    return $self->info_by(name => $args{name});
}


1;

