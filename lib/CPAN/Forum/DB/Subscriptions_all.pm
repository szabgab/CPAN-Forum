package CPAN::Forum::DB::Subscriptions_all;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('subscriptions_all');
__PACKAGE__->columns(All => qw/id uid allposts starters followups announcements/);
__PACKAGE__->has_a(uid => "CPAN::Forum::DB::Users");



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

    # check if keys of args is uid 
    my @fields = keys %args;
    my $where = join " AND ", map {"$_=?"} @fields;
    my $sql = "SELECT id, allposts, starters, followups, announcements
              FROM subscriptions_all";
    if ($where) {
        $sql .= " WHERE $where";
    }
    return ($sql, @args{@fields}); 
}


1;
