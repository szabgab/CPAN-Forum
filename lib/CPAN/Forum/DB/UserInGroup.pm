package CPAN::Forum::DB::UserInGroup;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('user_in_group');
__PACKAGE__->columns(All => qw/uid gid/);

#__PACKAGE__->has_many(users => "CPAN::Forum::DB::Users");
#__PACKAGE__->has_many(groups => "CPAN::Forum::DB::Usergroups");


1;

