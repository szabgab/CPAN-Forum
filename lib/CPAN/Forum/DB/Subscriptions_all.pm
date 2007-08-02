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
    my ($where, @values) = $self->_prep_where(\%args);
    my $sql = "SELECT id, allposts, starters, followups, announcements
              FROM subscriptions_all";
    if ($where) {
        $sql .= " WHERE $where";
    }
    return ($sql, @values);
}

sub _prep_where {
    my ($self, $args) = @_;
    #Carp::cluck (Data::Dumper->Dump([$args], ['args']));

    my @fields = keys %$args;
    my $where = join " AND ", map {"$_=?"} @fields;
    my %args = %$args;
    return ($where, @args{@fields}); 
}

sub _prep_set {
    my ($self, $args) = @_;
    my @fields = keys %$args;

    my $where = join ", ", map {"$_=?"} @fields;
    my %args = %$args;
    return ($where, @args{@fields}); 
    #return ($where, @{ $args->{@fields} }); 
}

sub _prep_insert {
    my ($self, $args) = @_;

    my @fields = keys %$args;
    my $fields = join ", ", @fields;
    my $placeholders = join ", ", (("?") x scalar @fields);
    return ($fields, $placeholders, @{ $args->{@fields} }); 
}

sub complex_update {
    my ($self, @args) = @_;
    $self->_complex_update(@args, 'subscriptions_all');
}


1;
