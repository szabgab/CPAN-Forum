package CPAN::Forum::Usergroups;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('usergroups');
__PACKAGE__->columns(All => qw/id name/);

__PACKAGE__->set_sql(ugs => "SELECT __ESSENTIAL__ FROM __TABLE__, user_in_group
                             WHERE 
                               user_in_group.uid = ? AND
                               user_in_group.gid=usergroups.id
                            ");

1;

