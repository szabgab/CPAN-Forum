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


sub get_subscriptions {
    my ($self, $field, $gid, $pauseid) = @_;
    if (not grep {$field eq $_} qw(allposts)) {
        Carp::croak("Invalid field '$field'");
    }

    my $sql = "  SELECT DISTINCT username
                   FROM users, subscriptions_all
                   WHERE (users.id=subscriptions_all.uid AND subscriptions_all.$field=1)
               UNION
                 SELECT DISTINCT username
                   FROM users, subscriptions
                   WHERE  (users.id=subscriptions.uid AND subscriptions.$field=1 AND gid=?)
               UNION
                 SELECT DISTINCT username
                   FROM users, subscriptions_pauseid
                   WHERE  
                     (users.id=subscriptions_pauseid.uid 
                           AND subscriptions_pauseid.$field=1 
                           AND subscriptions_pauseid.pauseid=?)
               ORDER BY username";
    return $self->_select_column($sql, $gid, $pauseid);
}

1;
