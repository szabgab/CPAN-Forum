package CPAN::Forum::Groups;
use strict;
use warnings;
use Carp;
use base 'CPAN::Forum::DBI';
__PACKAGE__->table('groups');
__PACKAGE__->columns(All     => qw/id name gtype status/);
#__PACKAGE__->columns(Primary => qw/id name/);
__PACKAGE__->has_many(posts  => "CPAN::Forum::Posts");
__PACKAGE__->has_many(subscriptions => "CPAN::Forum::Subscriptions");

__PACKAGE__->set_sql(count_like   => "SELECT count(*) FROM __TABLE__ WHERE %s LIKE '%s'");
__PACKAGE__->set_sql(count   => "SELECT count(*) FROM __TABLE__ WHERE %s = '%s'");
1;

