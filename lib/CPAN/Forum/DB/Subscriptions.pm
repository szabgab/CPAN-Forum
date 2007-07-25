package CPAN::Forum::DB::Subscriptions;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('subscriptions');
__PACKAGE__->columns(All => qw/id gid uid allposts starters followups announcements/);
__PACKAGE__->has_a(uid => "CPAN::Forum::DB::Users");
__PACKAGE__->has_a(gid => "CPAN::Forum::DB::Groups");


sub find_one {
    my ($self, %args) = @_;
    # check if keys of args is either uid or gid
    my @fields = keys %args;
    my $where = join " AND ", map {"$_=?"} @fields;
    my $sql = "SELECT id, gid, uid, allposts, starters, followups, announcements FROM subscriptions";
    if ($where) {
        $sql .= " WHERE $where";
    }

    $self->_fetch_single_hashref($sql, @args{@fields}); 

}

1;
