package CPAN::Forum::DB::Subscriptions;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('subscriptions');
__PACKAGE__->columns(All => qw/id gid uid allposts starters followups announcements/);
__PACKAGE__->has_a(uid => "CPAN::Forum::DB::Users");
__PACKAGE__->has_a(gid => "CPAN::Forum::DB::Groups");


sub find {
    my ($self, %args) = @_;
    my ($sql, @args) = $self->_find(%args);
    return $self->_fetch_arrayref_of_hashes($sql, @args);
}

sub find_one {
    my ($self, %args) = @_;

    my ($sql, @args) = $self->_find(%args);

    return $self->_fetch_single_hashref($sql, @args); 
}

sub _find {
    my ($self, %args) = @_;

    # check if keys of args is either uid or gid
    my @fields = keys %args;
    my $where = join " AND ", map {"$_=?"} @fields;
    my $sql = "SELECT subscriptions.id, gid, uid, allposts, starters, followups, announcements,
        groups.name group_name FROM subscriptions, groups WHERE groups.id=subscriptions.gid";
    if ($where) {
        $sql .= " AND $where";
    }
    return ($sql, @args{@fields}); 
}

sub complex_update {
    my ($self, @args) = @_;
    $self->_complex_update(@args, 'subscriptions');
}


1;
