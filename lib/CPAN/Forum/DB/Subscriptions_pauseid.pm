package CPAN::Forum::DB::Subscriptions_pauseid;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('subscriptions_pauseid');
__PACKAGE__->columns(All => qw/id pauseid uid allposts starters followups announcements/);
__PACKAGE__->has_a(uid     => "CPAN::Forum::DB::Users");
__PACKAGE__->has_a(pauseid => "CPAN::Forum::DB::Authors");

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
    my $sql = "SELECT subscriptions_pauseid.id pasuseid, uid, allposts, starters, followups, announcements,
        authors.pauseid pauseid_name FROM subscriptions_pauseid, authors WHERE authors.id=subscriptions_pauseid.pauseid";
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
