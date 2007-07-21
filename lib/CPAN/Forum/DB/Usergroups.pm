package CPAN::Forum::DB::Usergroups;
use strict;
use warnings;
use base 'CPAN::Forum::DBI';
#__PACKAGE__->table('usergroups');
#__PACKAGE__->columns(All => qw/id name/);

sub is_admin {
    my ($self, $id) = @_;

    my $sql = "SELECT id FROM usergroups, user_in_group
               WHERE 
               usergroups.name='admin' AND
               user_in_group.uid = ? AND
               user_in_group.gid=usergroups.id
               ";
    $self->_fetch_single_value($sql, $id);
}

1;

