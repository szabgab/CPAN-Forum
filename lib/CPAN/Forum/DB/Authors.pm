package CPAN::Forum::DB::Authors;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';

sub get_author_by_pauseid {
    my ($self, $pauseid) = @_;
    Carp::croak("No PAUSEID provided") if not $pauseid;

    my $sql = "SELECT id, pauseid FROM authors WHERE pauseid=?";
    return $self->_fetch_single_hashref($sql, uc $pauseid);
}

sub add {
    my ($self, $pauseid) = @_;
    my $sql = "INSERT INTO authors (pauseid) VALUES (?)";
    my $dbh = CPAN::Forum::DBI::db_Main();
    $dbh->do($sql, undef, $pauseid);

    return $self->get_author_by_pauseid($pauseid);
}

1;
