package CPAN::Forum::DB::Authors;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('authors');
__PACKAGE__->columns(All => qw/id pauseid/);
__PACKAGE__->has_many(uid => "CPAN::Forum::DB::Groups");
__PACKAGE__->has_many(subscriptions => "CPAN::Forum::DB::Subscriptions_pauseid");

sub get_author_by_pauseid {
    my ($self, $pauseid) = @_;
    Carp::croak("No PAUSEID provided") if not $pauseid;

    my $sql = "SELECT id, pauseid FROM authors WHERE pauseid=?";
    return $self->_fetch_single_hashref($sql, uc $pauseid);
}

1;
