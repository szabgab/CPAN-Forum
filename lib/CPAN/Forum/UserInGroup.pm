package CPAN::Forum::UserInGroup;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('user_in_group');
__PACKAGE__->columns(All => qw/uid gid/);

#__PACKAGE__->has_many(users => "CPAN::Forum::Users");
#__PACKAGE__->has_many(groups => "CPAN::Forum::Usergroups");


1;

