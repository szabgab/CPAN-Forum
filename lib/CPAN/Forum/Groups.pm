package CPAN::Forum::Groups;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('groups');
__PACKAGE__->columns(All => qw/id name gtype status/);
__PACKAGE__->has_many(posts => "CPAN::Forum::Posts");
__PACKAGE__->has_many(subscriptions => "CPAN::Forum::Subscriptions");

1;

